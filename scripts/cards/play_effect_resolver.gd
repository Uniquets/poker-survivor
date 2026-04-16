extends RefCounted
class_name PlayEffectResolver
## 出牌效果解析器：把一次打出的「牌组 + 组类型 + 全局状态」转成战斗侧可执行的 **`PlayPlan`**（命令列表）。
##
## **数据流（与 `docs/设计与架构.md` 一致）**：`AutoAttackSystem` 在收到 `CardRuntime.group_played` 后构造 **`PlayContext`**，
## 再调用本类的 **`resolve(ctx)`**；返回的 `PlayPlan` 交给 **`CombatEffectRunner.execute`**，不在此脚本内做索敌或节点操作。
##
## **管线顺序**：① 尝试关键张 **2 / 8 / 10**（同点数且组型与张数一致）→ ② 否则 **`EffectResolver`** 数值结算并回落为弹道
## → ③ 按 **`augment_snapshot`** 叠全局弹道枚数/激光道数 → ④ 粗算 **`estimated_enemy_damage`** 供调试/UI 提示（非权威服务器结算）。
##
## **边界**：不写组牌合法性判定（由 `GroupDetector` / `CardRuntime` 保证）；不直接改 UI。

## 预加载 `PlayPlan` 脚本：避免解析顺序下 `class_name PlayPlan` 尚未注册导致类型/实例化失败
const _PlayPlanScript = preload("res://scripts/cards/play_plan.gd")
## 预加载命令工厂脚本：用于 `create_*` 静态方法生成 `PlayEffectCommand`
const _CmdScript = preload("res://scripts/cards/play_effect_command.gd")

## 旧版纯数值解析器实例：回落管线中叠花色/组牌乘区后，再映射为 `PROJECTILE_VOLLEY` 等命令
var _legacy_resolver: EffectResolver = null


## 构造：仅创建 **`EffectResolver`**，供 `_build_legacy_projectile_plan` 复用；无场景节点副作用
func _init() -> void:
	_legacy_resolver = EffectResolver.new()


## 单次解析入口（**非**对象构造）：根据 **`ctx`** 生成完整 **`PlayPlan`**。
## **参数**：`ctx` — `PlayContext`，含 `cards`、`group_type`（枚举）、`global_suit_counts`、`augment_snapshot` 等。
## **返回**：`PlayPlan`（`Variant` 因 GDScript 对跨脚本类注解宽松）；内含 `commands`、`debug_tags`、`estimated_enemy_damage`。
## **副作用**：只写入新 `PlayPlan` 与命令对象，不修改 `ctx` 内数组引用以外的战斗场景状态。
func resolve(ctx) -> Variant:
	# ① 同点数 2/8/10 且组型张数匹配 → 走关键张专用命令（不经过 EffectResolver）
	var plan = _try_build_rank_keyframe_plan(ctx)
	# ② 非关键张或条件不满足 → 用 EffectResolver 算伤害/命中再转成通用弹道计划
	if plan == null:
		plan = _build_legacy_projectile_plan(ctx)
	# ③ 全局强化：在已有命令上线性增加枚数/激光道数（见 `_apply_global_augment_volley`）
	_apply_global_augment_volley(plan, ctx)
	# ④ 按命令种类粗算对敌伤害提示（治疗、纯表现类命令不计入）
	_recalc_damage_hint(plan)
	return plan


## 尝试构建「关键张 2 / 8 / 10」管线计划；不满足任一前置条件则返回 **`null`** 交由回落处理。
## **参数**：`ctx` — 当前步 `PlayContext`。
## **返回**：新 `PlayPlan` 或 `null`（`null` 表示走 `_build_legacy_projectile_plan`）。
## **前置条件**：牌非空；**所有牌 `CardResource.rank` 相同** 且为 2/8/10；**`ctx.group_type` 与张数** 与 `GroupDetector` 语义一致（如单张对 SINGLE）。
func _try_build_rank_keyframe_plan(ctx):
	var cards: Array = ctx.cards
	if cards.is_empty():
		return null
	var ur := _uniform_card_rank(cards)
	# 点数 → 填充函数；键为 `GameRules.Rank` 与 `CardResource.rank` 一致
	var _func_map := {
		GameRules.Rank.TWO: _fill_rank_two_commands,
		GameRules.Rank.EIGHT: _fill_rank_eight_commands,
		GameRules.Rank.TEN: _fill_rank_ten_commands,
	}
	if not _func_map.has(ur):
		return null
	# 防止「同点数但组型与张数不合法」仍进关键张（例如顺子含 2 但组型不是 PAIR）
	if not _group_size_matches_type(cards, ctx.group_type):
		return null

	var plan = _PlayPlanScript.new()
	_func_map[ur].call(plan, ctx)
	plan.debug_tags.append_array(["rank_keyframe", "rank_%d" % ur, str(ctx.group_type)])
	return plan


## 若 **`cards`** 中每张均为同一 **`CardResource.rank`**，返回该点数（1=A … 13=K）；否则返回 **-1**。
## **用途**：区分关键张 2 与 A（避免用 `get_rank_value` 把 A 与点数值混淆）。**参数**：`cards` — 本步打出的牌数组。**返回**：合法 rank 或 -1。
func _uniform_card_rank(cards: Array) -> int:
	var r0: int = -1
	for c in cards:
		if not c is CardResource:
			return -1
		var cr: CardResource = c
		if r0 < 0:
			r0 = cr.rank
		elif cr.rank != r0:
			return -1
	return r0


## 判断当前 **`cards.size()`** 是否与 **`group_type`** 所代表的组牌张数一致（与 `GroupDetector` / `PlayContext` 约定对齐）。
## **参数**：`cards` — 本步牌组；`group_type` — 已由上游转为 **`GameRules.GroupType`**。**返回**：一致为 `true`，否则 `false`（顺子/连对等非 SINGLE…FOUR 时返回 false，关键张管线不介入）。
func _group_size_matches_type(cards: Array, group_type: GameRules.GroupType) -> bool:
	var n: int = cards.size()
	match group_type:
		GameRules.GroupType.SINGLE:
			return n == 1
		GameRules.GroupType.PAIR:
			return n == 2
		GameRules.GroupType.THREE_OF_A_KIND:
			return n == 3
		GameRules.GroupType.FOUR_OF_A_KIND:
			return n == 4
		_:
			return false


## **点数 2 关键张**：按本步张数 **`n`** 追加一条命令——`n=1～3` 为多发 **`PROJECTILE_VOLLEY`**，`n=4` 为 **`LASER_DUAL_BURST`**。
## **参数**：`plan` — 正在构建的 `PlayPlan`；`ctx` — 提供 `cards` 与后续扩展字段。**副作用**：`append` 到 `plan.commands`；数值取自 **`CombatTuning`**。
func _fill_rank_two_commands(plan, ctx) -> void:
	var n: int = ctx.cards.size()
	match n:
		1:
			# n=1 —— 单张 2，多发弹道
			plan.commands.append(
				_CmdScript.create_projectile_volley(
					CombatTuning.RANK_TWO_VOLLEY_COUNT_SINGLE, # 单张弹道发数
					CombatTuning.RANK_TWO_VOLLEY_DAMAGE_PER_HIT, # 单发伤害
					CombatTuning.RANK_TWO_VOLLEY_SPREAD_DEG * CombatTuning.RANK_TWO_VOLLEY_SPREAD_MUL_SINGLE # 散布角度
				)
			)
		2:
			# n=2 —— 对子 2，多发弹道参数取 Pair 档
			plan.commands.append(
				_CmdScript.create_projectile_volley(
					CombatTuning.RANK_TWO_VOLLEY_COUNT_PAIR, # 两张弹道发数
					CombatTuning.RANK_TWO_VOLLEY_DAMAGE_PER_HIT, # 单发伤害
					CombatTuning.RANK_TWO_VOLLEY_SPREAD_DEG * CombatTuning.RANK_TWO_VOLLEY_SPREAD_MUL_PAIR # 散布角度
				)
			)
		3:
			# n=3 —— 三条 2，多发弹道参数取 Triple 档
			plan.commands.append(
				_CmdScript.create_projectile_volley(
					CombatTuning.RANK_TWO_VOLLEY_COUNT_TRIPLE, # 三张弹道发数
					CombatTuning.RANK_TWO_VOLLEY_DAMAGE_PER_HIT, # 单发伤害
					CombatTuning.RANK_TWO_VOLLEY_SPREAD_DEG * CombatTuning.RANK_TWO_VOLLEY_SPREAD_MUL_TRIPLE # 散布角度
				)
			)
		4:
			# n=4 —— 四条 2，生成激光命令
			plan.commands.append(
				_CmdScript.create_laser_dual_burst(
					CombatTuning.RANK_TWO_LASER_TICK_DAMAGE, # 激光每跳伤害
					CombatTuning.RANK_TWO_LASER_DURATION_SECONDS # 激光持续时间（秒）
				)
			)
		_:
			pass


## **点数 8 关键张**：合成一条 **`EIGHT_EXPLOSIVE_VOLLEY`**（每牌一枚载荷弹道，命中后爆炸；四条带灼地参数）。
## **参数**：`plan`、`ctx` 同上。**说明**：`base_d` 取牌面 damage 和且不低于 **`RANK_EIGHT_EXPLOSION_MIN_DAMAGE`**；`n=2` 放大半径，`n=3/4` 叠伤害倍率，`n=4` 写入灼地半径/时长/DPS。
func _fill_rank_eight_commands(plan, ctx) -> void:
	var n: int = ctx.cards.size()
	var base_d: int = _sum_card_damage(ctx.cards)
	base_d = maxi(base_d, CombatTuning.RANK_EIGHT_EXPLOSION_MIN_DAMAGE)
	var base_r: float = CombatTuning.RANK_EIGHT_EXPLOSION_BASE_RADIUS
	var rmul: float = 1.0
	var dmul: float = 1.0
	match n:
		1:
			pass
		2:
			rmul = CombatTuning.RANK_EIGHT_PAIR_RADIUS_MUL
		3:
			dmul = CombatTuning.RANK_EIGHT_TRIPLE_DAMAGE_MUL
		4:
			dmul = CombatTuning.RANK_EIGHT_TRIPLE_DAMAGE_MUL
		_:
			pass
	var exp_dmg: int = int(round(float(base_d) * dmul))
	var exp_r: float = base_r * rmul
	var spread: float = (
		CombatTuning.RANK_EIGHT_PAYLOAD_SPREAD_BASE_DEG
		* (1.0 + CombatTuning.RANK_EIGHT_PAYLOAD_SPREAD_EXTRA_PER_CARD * float(n - 1))
	)
	var burn_r: float = 0.0
	var burn_sec: float = 0.0
	var burn_dps: int = 0
	if n == 4:
		burn_r = base_r * rmul * CombatTuning.RANK_EIGHT_BURN_RADIUS_SCALE
		burn_sec = CombatTuning.RANK_EIGHT_BURN_GROUND_SECONDS
		burn_dps = CombatTuning.RANK_EIGHT_BURN_GROUND_DPS
	plan.commands.append(
		_CmdScript.create_eight_explosive_volley(n, exp_dmg, exp_r, spread, burn_r, burn_sec, burn_dps)
	)


## **点数 10 关键张**：只追加逻辑相命令（**治疗百分比**、**无敌秒数**），不产生弹道；由 **`CombatEffectRunner`** 在逻辑相执行。
## **参数**：`plan`、`ctx` 同上。**副作用**：按 `n=1～4` 向 `plan.commands` 追加 `create_heal_percent` / `create_invulnerable`。
func _fill_rank_ten_commands(plan, ctx) -> void:
	var n: int = ctx.cards.size()
	match n:
		1:
			plan.commands.append(_CmdScript.create_heal_percent(CombatTuning.RANK_TEN_HEAL_PERCENT_SINGLE))
		2:
			plan.commands.append(_CmdScript.create_heal_percent(CombatTuning.RANK_TEN_HEAL_PERCENT_PAIR))
		3:
			plan.commands.append(_CmdScript.create_heal_percent(CombatTuning.RANK_TEN_HEAL_PERCENT_TRIPLE))
			plan.commands.append(_CmdScript.create_invulnerable(CombatTuning.RANK_TEN_INVULNERABLE_SECONDS_TRIPLE))
		4:
			plan.commands.append(_CmdScript.create_heal_percent(CombatTuning.RANK_TEN_HEAL_PERCENT_FOUR))
			plan.commands.append(_CmdScript.create_invulnerable(CombatTuning.RANK_TEN_INVULNERABLE_SECONDS_FOUR))
		_:
			pass


## 对 **`cards`** 中各 **`CardResource.damage`** 求和；用于点数 8 爆炸基数等非关键张无关逻辑。
## **参数**：`cards` — `CardResource` 数组。**返回**：总和（非牌或类型不符则跳过该元素）。
func _sum_card_damage(cards: Array) -> int:
	var t: int = 0
	for c in cards:
		if c is CardResource:
			t += c.damage
	return t


## **回落管线**：调用 **`EffectResolver.resolve_effects`** 得到 **`EffectResult`**，再转为 **`PlayPlan`**（治疗比例命令 + 多发弹道）。
## **参数**：`ctx` — `PlayContext`。**返回**：仅含回落标签与命令的新 `PlayPlan`。**说明**：弹道扇角用 **`CombatTuning.LEGACY_EFFECT_PROJECTILE_SPREAD_DEG`**；`hit_count`、`damage` 已由花色/组牌乘区处理。
func _build_legacy_projectile_plan(ctx):
	var plan = _PlayPlanScript.new()
	var result: EffectResolver.EffectResult = _legacy_resolver.resolve_effects(
		ctx.cards,
		ctx.group_type,
		ctx.global_suit_counts
	)
	var hits: int = maxi(1, result.hit_count)
	var dmg: int = maxi(0, result.damage)
	plan.debug_tags.append_array(["legacy_effect_resolver"])
	if result.heal_amount > 0:
		var ratio: float = clampf(float(result.heal_amount) / float(max(ctx.player_max_health, 1)), 0.0, 1.0)
		plan.commands.append(_CmdScript.create_heal_percent(ratio))
	plan.commands.append(_CmdScript.create_projectile_volley(hits, dmg, CombatTuning.LEGACY_EFFECT_PROJECTILE_SPREAD_DEG))
	return plan


## 将 **`ctx.augment_snapshot.volley_count_bonus`** 线性叠加到已生成命令的 **`count`**（弹道枚数、8 点爆炸连发枚数、激光道数）；**治疗等命令不修改**。
## **参数**：`plan` — 已有命令列表的 `PlayPlan`；`ctx` — 提供强化快照，可为 null。**副作用**：原地修改符合条件的 `PlayEffectCommand` 的 `count` 字段。
func _apply_global_augment_volley(plan, ctx) -> void:
	if plan == null:
		return
	var bonus: int = 0
	if ctx != null and ctx.augment_snapshot != null:
		bonus = int(ctx.augment_snapshot.volley_count_bonus)
	if bonus <= 0:
		return
	for cmd in plan.commands:
		if cmd == null or cmd.get_script() != _CmdScript:
			continue
		var c = cmd
		if c.kind == _CmdScript.CmdKind.PROJECTILE_VOLLEY:
			c.count = maxi(CombatTuning.RANK_TWO_GLOBAL_AUGMENT_MIN_PROJECTILE_VOLLEY_COUNT, c.count + bonus)
		elif c.kind == _CmdScript.CmdKind.EIGHT_EXPLOSIVE_VOLLEY:
			c.count = maxi(CombatTuning.RANK_EIGHT_GLOBAL_AUGMENT_MIN_EXPLOSIVE_VOLLEY_COUNT, c.count + bonus)
		elif c.kind == _CmdScript.CmdKind.LASER_DUAL_BURST:
			c.count = maxi(CombatTuning.RANK_TWO_GLOBAL_AUGMENT_MIN_LASER_DUAL_BURST_BEAMS, c.count + bonus)


## 遍历 **`plan.commands`**，按命令种类粗算对敌伤害，写入 **`plan.estimated_enemy_damage`**（**不含治疗**；与真实帧伤可能略有偏差，仅作提示）。
## **参数**：`plan` — 命令已填满且可能已叠加强化后的 `PlayPlan`。**说明**：激光用 `CombatTuning` 中假定 tick 间隔估算跳数；8 点灼地仅在时长与 `radius_mul` 超阈值时计入。
func _recalc_damage_hint(plan) -> void:
	var total: int = 0
	for cmd in plan.commands:
		if cmd == null or cmd.get_script() != _CmdScript:
			continue
		var c = cmd
		match c.kind:
			_CmdScript.CmdKind.PROJECTILE_VOLLEY:
				total += c.damage * maxi(1, c.count)
			_CmdScript.CmdKind.EXPLOSION_ONE_SHOT:
				total += int(float(c.damage) * c.damage_mul)
			_CmdScript.CmdKind.EIGHT_EXPLOSIVE_VOLLEY:
				total += c.damage * maxi(1, c.count)
				if (
					c.burn_duration > CombatTuning.RANK_EIGHT_DAMAGE_HINT_BURN_DURATION_THRESHOLD_SEC
					and c.radius_mul > CombatTuning.RANK_EIGHT_DAMAGE_HINT_RADIUS_MUL_FOR_BURN
				):
					total += int(c.burn_dps * c.burn_duration)
			_CmdScript.CmdKind.LASER_DUAL_BURST:
				var tick_sec: float = CombatTuning.RANK_TWO_DAMAGE_HINT_LASER_TICK_INTERVAL_SEC
				var ticks: int = maxi(
					1,
					int(floor(c.laser_duration / tick_sec + CombatTuning.RANK_TWO_DAMAGE_HINT_LASER_TICK_FLOOR_EPSILON))
				)
				var beams: int = maxi(CombatTuning.RANK_TWO_GLOBAL_AUGMENT_MIN_LASER_DUAL_BURST_BEAMS, c.count)
				total += c.damage * ticks * beams
			_CmdScript.CmdKind.BURNING_GROUND:
				total += int(c.burn_dps * c.burn_duration)
			_:
				pass
	plan.estimated_enemy_damage = total
