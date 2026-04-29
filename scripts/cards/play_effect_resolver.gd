extends RefCounted
class_name PlayEffectResolver
## 出牌效果解析器：把一次打出的「牌组 + 组类型 + 全局状态」转成战斗侧可执行的 **`PlayPlan`**（命令列表）。
##
## **数据流（与 `docs/详细设计.md` 第 9 节一致）**：`AutoAttackSystem` 在收到 `CardRuntime.group_played` 后构造 **`PlayContext`**，
## 再调用本类的 **`resolve(ctx)`**；返回的 `PlayPlan` 交给 **`CombatEffectRunner.execute`**，不在此脚本内做索敌或节点操作。
##
## **管线顺序（与牌型表解耦）**：**`EffectResolver`** 数值结算并回落为 **`PROJECTILE_VOLLEY`**（通用弹道）
## → **`PlayerCombatStats`** 伤害/范围/枚数/暴击，并乘 **`ctx.player_attack_damage_coefficient`**
## → **`augment_snapshot`** 叠全局弹道枚数/激光道数 → 粗算 **`estimated_enemy_damage`**（非权威服务器结算）。
## **同点数弹道/爆炸/治疗** 均由 **`GameConfig.PLAY_SHAPE_CATALOG`** + **`PlayShapeEffectAssembler`** 在 **`use_shape_table_effect_pipeline`** 为真时承担；本解析器**不再**含按牌面点数的专属分支。
##
## **边界**：不写组牌合法性判定（由 `GroupDetector` / `CardRuntime` 保证）；不直接改 UI。

## 预加载 `PlayPlan` 脚本：避免解析顺序下 `class_name PlayPlan` 尚未注册导致类型/实例化失败
const _PlayPlanScript = preload("res://scripts/cards/play_plan.gd")
## 预加载命令工厂脚本：用于 `create_*` 静态方法生成 `PlayEffectCommand`
const _CmdScript = preload("res://scripts/cards/play_effect_command.gd")
## **`PlayPlan`** 后处理（静态方法，无 **`class_name`**）
const _EffectPlanPostProcessScript: GDScript = preload("res://scripts/cards/effect_plan_post_process.gd")
const _PlayShapeMatcherScript: GDScript = preload("res://scripts/cards/play_shape_matcher.gd")
const _ParallelSpecScript: GDScript = preload("res://scripts/cards/shape_parallel_volley_effect_spec.gd")
## 策划表访问（见 `enemy.gd` 说明）


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
	var plan = _build_legacy_projectile_plan(ctx)
	_EffectPlanPostProcessScript.apply_all(plan, ctx)
	return plan


## 解析 **`PROJECTILE_VOLLEY` / `WAYPOINT_VOLLEY`** 发射音：统一读取 `PlayShapeCatalog` 外层默认。
func _resolve_projectile_volley_fire_sfx(bind_slots: bool, _use_primary_scene: bool) -> AudioStream:
	## 中文：未绑定表现槽 — 与历史一致不播发射音
	if not bind_slots:
		return null
	var cat: PlayShapeCatalog = GameConfig.PLAY_SHAPE_CATALOG as PlayShapeCatalog
	if cat == null:
		return null
	return cat.default_fire_sfx


## 从牌型目录中取并行默认规格（首个 `FALLBACK + ShapeParallelVolleyEffectSpec`）
func _resolve_default_parallel_spec() -> Resource:
	var cat: PlayShapeCatalog = GameConfig.PLAY_SHAPE_CATALOG
	if cat == null:
		return null
	var default_entry = cat.shape_dic.get(_PlayShapeMatcherScript.KEY_DEFAULT)
	if default_entry == null:
		return null
	var spec: Resource = default_entry.get("effect_spec") as Resource
	if spec != null and spec.get_script() == _ParallelSpecScript:
		return spec
	return null


## **回落管线**：调用 **`EffectResolver.resolve_effects`** 得到 **`EffectResult`**，再转为 **`PlayPlan`**（治疗比例命令 + 多发弹道）。
## **参数**：`ctx` — `PlayContext`。**返回**：新 `PlayPlan`。**说明**：枚数/扇角/穿透取并行默认规格与 **`result.hit_count`** 的较大值；`hit_count`、`damage` 已由花色/组牌乘区处理。
func _build_legacy_projectile_plan(ctx):
	var plan = _PlayPlanScript.new()
	var result: EffectResolver.EffectResult = _legacy_resolver.resolve_effects(
		ctx.cards,
		ctx.group_type,
		ctx.global_suit_counts
	)
	var cat: PlayShapeCatalog = GameConfig.PLAY_SHAPE_CATALOG as PlayShapeCatalog
	var dspec: Resource = _resolve_default_parallel_spec()
	var hits_cfg: int = int(dspec.get("volley_count")) if dspec != null else 2
	var spread_cfg: float = float(dspec.get("spread_deg")) if dspec != null else 6.0
	var pierce_cfg: int = int(dspec.get("extra_hit_budget_per_shot")) if dspec != null else 1
	var lock_r_cfg: float = float(dspec.get("lock_query_radius")) if dspec != null else 1000.0
	var line_spacing_cfg: float = float(dspec.get("line_spacing")) if dspec != null else 14.0
	var fire_cfg: AudioStream = dspec.get("fire_sfx") as AudioStream if dspec != null else null
	var hit_first_cfg: AudioStream = dspec.get("hit_sfx_first") as AudioStream if dspec != null else null
	var hit_pierce_cfg: AudioStream = dspec.get("hit_sfx_pierce") as AudioStream if dspec != null else null
	var hit_reroute_cfg: AudioStream = dspec.get("hit_sfx_reroute") as AudioStream if dspec != null else null
	var hits: int = maxi(hits_cfg, result.hit_count)
	var dmg: int = maxi(0, result.damage)
	plan.debug_tags.append_array(["legacy_effect_resolver"])
	if result.heal_amount > 0:
		var ratio: float = clampf(float(result.heal_amount) / float(max(ctx.player_max_health, 1)), 0.0, 1.0)
		plan.commands.append(_CmdScript.create_heal_percent(ratio))
	var volley: Variant = _CmdScript.create_projectile_volley(
		hits,
		dmg,
		spread_cfg,
		pierce_cfg,
		lock_r_cfg,
		line_spacing_cfg,
		true,
		true,
		true,
		fire_cfg if fire_cfg != null else _resolve_projectile_volley_fire_sfx(true, true),
		hit_first_cfg,
		hit_pierce_cfg,
		hit_reroute_cfg,
		cat.default_projectile_scene if cat != null else null
	)
	if result.knockback > 0.0 and volley != null:
		volley.hit_knockback_speed = result.knockback
	plan.commands.append(volley)
	return plan


## 后处理已迁至 **`EffectPlanPostProcess`**（由 **`resolve`** 与牌型表管线统一调用）
