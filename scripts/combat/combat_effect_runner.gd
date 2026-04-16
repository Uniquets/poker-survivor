extends RefCounted
class_name CombatEffectRunner
## 消费 PlayPlan：先执行 logical 命令，再执行 presentational 命令（与设计与架构 §7 一致）

const _CmdScript = preload("res://scripts/cards/play_effect_command.gd")
## 默认弹道预制体（表现相）；与爆炸/激光等一致由本类持有资源路径
const _DefaultProjectileScene: PackedScene = preload("res://scenes/combat/Projectile.tscn")
## 点数 8 专用弹道脚本（非 Projectile.tscn）
const _EightPayloadScript = preload("res://scripts/combat/eight_explosive_projectile.gd")
## 弹道几何 `static` 方法与常量：经 `preload` 调用以满足 LSP「勿在 Autoload 实例上调静态方法」；与 Autoload `ProjectileToolSingleton` 为同一脚本
const _ProjectileToolScript = preload("res://scripts/core/projectile_tool_singleton.gd")
## `CombatTuning` 经 `preload` 引用，避免 LSP 对部分新增 `const` 不报成员
const _CombatTuningScript = preload("res://scripts/core/combat_tuning.gd")
## 与 `CombatPlayer` / `EnemyManager` 为同一 `.gd`；标为 `Variant` 避免 LSP 将 `preload` 误标为节点基类而查不到脚本级 `static` 成员
const _CombatPlayerScript: Variant = preload("res://scripts/combat/player.gd")
const _EnemyManagerScript: Variant = preload("res://scripts/combat/enemy_manager.gd")
## 与 `class_name Projectile` 同脚本；用于校验 `projectile_scene` 根节点脚本，避免 Runner 写 `as Projectile` 触发 LSP 未索引全局类名
const _ProjectileScript: Variant = preload("res://scripts/combat/projectile.gd")

## 最近一次爆炸类效果的世界坐标，用于四个 8 的灼地落点
var _last_explosion_world_pos: Vector2 = Vector2.ZERO


## 执行整份计划；**`world` 须含 `parent`（Node）**；可选 `projectile_scene`。`player` / `enemy_manager` 可从字典覆盖，缺省则经 **`get_combat_player()` / `get_enemy_manager()`**（与 `static var` 同源）
func execute(plan, world: Dictionary) -> void:
	var player: CombatPlayer = world.get("player", null) as CombatPlayer
	if not is_instance_valid(player):
		player = _CombatPlayerScript.get_combat_player() as CombatPlayer
	var enemy_manager: EnemyManager = world.get("enemy_manager", null) as EnemyManager
	if not is_instance_valid(enemy_manager):
		enemy_manager = _EnemyManagerScript.get_enemy_manager() as EnemyManager
	var parent: Node = world.get("parent", null) as Node

	# 默认弹道预制体为 _DefaultProjectileScene
	var projectile_scene: PackedScene = _DefaultProjectileScene

	# 如果 world 字典传入了 projectile_scene（类型为 PackedScene），则用其覆盖默认弹道
	if world.has("projectile_scene") and world["projectile_scene"] is PackedScene:
		projectile_scene = world["projectile_scene"]
		
	# player、enemy_manager、parent 任一无效时，不执行计划
	if not is_instance_valid(player) or not is_instance_valid(enemy_manager) or parent == null:
		return

	# 先遍历 plan.commands，执行所有 phase == PHASE_LOGICAL 的命令（如治疗、无敌等逻辑型指令）
	for cmd in plan.commands:
		# 跳过无效或不是 _CmdScript 类型的命令对象
		if cmd == null or cmd.get_script() != _CmdScript:
			continue
		var c = cmd
		# 只处理 phase 为 PHASE_LOGICAL 的命令
		if c.phase == _CmdScript.PHASE_LOGICAL:
			_run_logical(c, player)

	# 再遍历 plan.commands，按顺序执行所有 phase == PHASE_PRESENTATIONAL 的命令（表现型指令，如发射弹道等）
	for cmd in plan.commands:
		# 跳过无效或不是 _CmdScript 类型的命令对象
		if cmd == null or cmd.get_script() != _CmdScript:
			continue
		var c2 = cmd
		# 只处理 phase 为 PHASE_PRESENTATIONAL 的命令
		if c2.phase == _CmdScript.PHASE_PRESENTATIONAL:
			_run_presentational(c2, player, enemy_manager, parent, projectile_scene)


## 处理治疗与无敌等逻辑相
func _run_logical(cmd, player: CombatPlayer) -> void:
	match cmd.kind:
		_CmdScript.CmdKind.HEAL_PERCENT_MAX:
			player.heal_percent_of_max_health(cmd.heal_ratio)
		_CmdScript.CmdKind.INVULNERABLE_SECONDS:
			player.add_invulnerable_seconds(cmd.invuln_seconds)
		_:
			pass


## 处理弹道、爆炸、激光与灼地
func _run_presentational(
	# 处理表现（弹道、爆炸、激光、灼地等），根据 cmd.kind 分派到具体表现函数
	cmd,
	player: CombatPlayer,
	enemy_manager: EnemyManager,
	parent: Node,
	projectile_scene: PackedScene
) -> void:
	match cmd.kind:
		_CmdScript.CmdKind.PROJECTILE_VOLLEY:
			# 多发弹道表现（如点数 2、3）
			_spawn_projectile_volley(player, enemy_manager, parent, projectile_scene, cmd)
		_CmdScript.CmdKind.EIGHT_EXPLOSIVE_VOLLEY:
			# 点数 8：分扇形发射爆炸弹道（每路直线，命中爆炸），含灼地着地判定
			_spawn_eight_explosive_volley(player, enemy_manager, parent, cmd)
		_CmdScript.CmdKind.EXPLOSION_ONE_SHOT:
			# 立即在目标爆炸，主要用于部分技能牌动画表现
			_spawn_explosion(player, enemy_manager, parent, cmd)
		_CmdScript.CmdKind.LASER_DUAL_BURST:
			# 发射双路激光（如技能 QKA）
			_spawn_laser_dual(player, enemy_manager, parent, cmd)
		_CmdScript.CmdKind.BURNING_GROUND:
			# 生成灼地效果
			_spawn_burning_ground(enemy_manager, parent, cmd)
		_:
			# 其它（未实现或无表现）的命令类型忽略
			pass


## 无 `primary_hostile` 时扇形/并行的基准朝向（速度向优先，否则向右）
func _aim_forward_when_no_hostile(player: CombatPlayer) -> Vector2:
	var v: Vector2 = player.velocity
	if v.length_squared() > 4.0:
		return v.normalized()
	return Vector2.RIGHT


## 多发弹道：点数 2 等经 ProjectileToolSingleton **并行**布局（共向、侧向错开起点），伤害每发相同
func _spawn_projectile_volley(
	player: CombatPlayer,
	enemy_manager: EnemyManager,
	parent: Node,
	projectile_scene: PackedScene,
	cmd
) -> void:
	if projectile_scene == null:
		return # 未设置弹体预制体时直接返回
	# 实际类型为 `TargetConfirmDefault.TargetConfirmResult`（内嵌类）；返回标 `RefCounted` 以兼容当前 LSP 对内嵌类的索引
	var lock_res = TargetConfirmDefault.resolve_global(
		cmd.lock_target_kind,
		player.global_position,
		cmd.lock_query_radius
	)
	if not lock_res.ok:
		return # 未锁定目标则不发射
	var target: CombatEnemy = lock_res.primary_hostile # 主目标（可为 null）
	var forward: Vector2
	if target != null:
		forward = _ProjectileToolScript.aim_forward_from_to(player.global_position, target.global_position) # 有目标时指向敌人
	else:
		forward = _aim_forward_when_no_hostile(player) # 否则采用默认朝向
	var count: int = maxi(1, cmd.count) # 弹数下限为 1
	var line_spacing: float = (
		_CombatTuningScript.RANK_TWO_VOLLEY_PARALLEL_LINE_BASE
		+ cmd.spread_deg * _CombatTuningScript.RANK_TWO_VOLLEY_PARALLEL_LINE_PER_SPREAD_DEG # 扩散角度影响并行线距
	)
	var layouts: Array = _ProjectileToolScript.compute_parallel_layout(
		player.global_position,
		forward,
		count,
		line_spacing # 计算弹体初始布局
	)
	for entry in layouts:
		var spawn_pos: Vector2 = entry[_ProjectileToolScript.RESULT_KEY_POSITION] # 弹体生成位置
		var proj: Node2D = projectile_scene.instantiate() as Projectile
		if proj == null:
			continue
		proj.global_position = spawn_pos
		# 目标填 null 表示直线模式
		proj.configure_from_volley(null, forward, enemy_manager, cmd.damage)
		parent.add_child(proj)


## 点数 8：经 ProjectileToolSingleton **角度扇**从玩家处发射，各弹沿扇向直线飞行，近敌或超时引爆；四条时仅最后一枚在命中点生成灼地
func _spawn_eight_explosive_volley(
	player: CombatPlayer,
	enemy_manager: EnemyManager,
	parent: Node,
	cmd
) -> void:
	# 调用弹道锁定，取得命令指定的目标与相关参数（与多发弹道一致：锚点为玩家世界坐标）
	var lock_res = TargetConfirmDefault.resolve_global(
		cmd.lock_target_kind,
		player.global_position,
		cmd.lock_query_radius
	)
	if not lock_res.ok:
		return
	var target: CombatEnemy = lock_res.primary_hostile
	var forward: Vector2
	# 依据是否有明确目标，决定发射扇方向
	if target != null:
		# 有目标时，沿玩家到目标方向发射
		forward = _ProjectileToolScript.aim_forward_from_to(player.global_position, target.global_position)
	else:
		# 无目标时，用默认前向
		forward = _aim_forward_when_no_hostile(player)
	# 发射弹数量（至少为 1）
	var count: int = maxi(1, cmd.count)
	# 飞行速度：常量（可外部调节）
	var speed: float = _CombatTuningScript.RANK_EIGHT_PAYLOAD_SPEED
	# 角度扇弧度：基础值加扩散参数调整
	var arc_deg: float = (
		_CombatTuningScript.RANK_EIGHT_ANGULAR_FAN_ARC_BASE_DEG
		+ cmd.spread_deg * _CombatTuningScript.RANK_EIGHT_ANGULAR_FAN_ARC_PER_SPREAD_DEG
	)
	# 计算所有弹在扇面上的起点和飞行方向
	var layouts: Array = _ProjectileToolScript.compute_angular_fan_layout(
		player.global_position,
		forward,
		count,
		arc_deg
	)
	var i: int = 0
	# 按需生成每个弹体
	for entry in layouts:
		# 获取此弹的起点和朝向
		var spawn_pos: Vector2 = entry[_ProjectileToolScript.RESULT_KEY_POSITION]
		var flight_dir: Vector2 = entry[_ProjectileToolScript.RESULT_KEY_DIRECTION]
		# 新建弹体节点、设置其位置和逻辑脚本
		var proj := Node2D.new()
		proj.global_position = spawn_pos
		proj.set_script(_EightPayloadScript)
		# 仅最后一弹且满足条件时启用灼地生成
		var spawn_burn: bool = (i == count - 1) and cmd.burn_duration > 0.05 and cmd.radius_mul > 1.0
		# 注入飞行与爆炸/灼地所有参数
		proj.setup(
			enemy_manager,
			parent,
			target,
			cmd.damage,
			cmd.radius,
			speed,
			spawn_burn,
			cmd.radius_mul,
			cmd.burn_duration,
			cmd.burn_dps,
			flight_dir
		)
		# 节点挂到场景树指定父节点
		parent.add_child(proj)
		i += 1


## 在指定位置生成一次性圆形爆炸
func _spawn_explosion(
	player: CombatPlayer,
	enemy_manager: EnemyManager,
	parent: Node,
	cmd
) -> void:
	var target := _nearest_hostile_for_explosion_anchor(enemy_manager, player.global_position)
	var center: Vector2 = player.global_position
	if target != null:
		center = target.global_position
	var radius: float = cmd.radius * cmd.radius_mul
	var dmg: int = int(round(float(cmd.damage) * cmd.damage_mul))
	var ex := Node2D.new()
	ex.set_script(load("res://scripts/combat/explosion_one_shot.gd"))
	ex.setup(enemy_manager, dmg, radius)
	ex.global_position = center
	parent.add_child(ex)
	_last_explosion_world_pos = center


## 多道平行短激光：`cmd.count` 为道数（默认 2，解析阶段已叠全局弹道加成）
func _spawn_laser_dual(player: CombatPlayer, enemy_manager: EnemyManager, parent: Node, cmd) -> void:
	var node := Node2D.new()
	node.set_script(load("res://scripts/combat/laser_burst_effect.gd"))
	var beams: int = maxi(2, cmd.count)
	node.setup(player, enemy_manager, cmd.damage, cmd.laser_duration, 14.0, beams)
	node.global_position = player.global_position
	parent.add_child(node)


## 灼烧地面落在最近一次爆炸中心
func _spawn_burning_ground(enemy_manager: EnemyManager, parent: Node, cmd) -> void:
	var zone := Node2D.new()
	zone.set_script(load("res://scripts/combat/burning_ground_zone.gd"))
	zone.setup(enemy_manager, cmd.radius, cmd.burn_duration, cmd.burn_dps)
	zone.global_position = _last_explosion_world_pos
	parent.add_child(zone)


## 爆炸圆心用最近敌（表现层锚点规则，**非**弹道首发索敌；与 `TargetConfirmDefault` 解耦）
func _nearest_hostile_for_explosion_anchor(enemy_manager: EnemyManager, from_position: Vector2) -> CombatEnemy:
	var nearest: CombatEnemy = null
	var best: float = INF
	for child in enemy_manager.get_children():
		var e := child as CombatEnemy
		if e == null or e.is_dead():
			continue
		var d2 := from_position.distance_squared_to(e.global_position)
		if d2 < best:
			best = d2
			nearest = e
	return nearest
