extends RefCounted
class_name CombatEffectRunner
## 消费 PlayPlan：先执行 logical 命令，再执行 presentational 命令（与 `docs/详细设计.md` 第 9 节一致）

## 策划表访问（见 `enemy.gd` 说明）

const _CmdScript = preload("res://scripts/cards/play_effect_command.gd")
const _CMD_METEOR_STORM: int = 1001
## 扇形爆炸载荷专用弹道脚本（非 Projectile.tscn）
const _ExplosivePayloadScript = preload("res://scripts/combat/eight_explosive_projectile.gd")
## 弹道几何 `static` 方法与常量：经 `preload` 调用以满足 LSP「勿在 Autoload 实例上调静态方法」；与 Autoload `ProjectileToolSingleton` 为同一脚本
const _ProjectileToolScript = preload("res://scripts/core/projectile_tool_singleton.gd")
## 与 `CombatPlayer` / `EnemyManager` 为同一 `.gd`；标为 `Variant` 避免 LSP 将 `preload` 误标为节点基类而查不到脚本级 `static` 成员
const _CombatPlayerScript: Variant = preload("res://scripts/combat/player.gd")
const _EnemyManagerScript: Variant = preload("res://scripts/combat/enemy_manager.gd")
## 与 `class_name Projectile` 同脚本；用于校验 `projectile_scene` 根节点脚本，避免 Runner 写 `as Projectile` 触发 LSP 未索引全局类名
const _ProjectileScript: Variant = preload("res://scripts/combat/projectile.gd")
const _WaypointArenaVolleySpawnerScript = preload("res://scripts/combat/waypoint_arena_volley_spawner.gd")
## 爆炸逻辑根节点预制体：内含 **`CombatHitbox2D`**，碰撞圆在编辑器内可调
const _ExplosionOneShotScene: PackedScene = preload("res://scenes/combat/ExplosionOneShot.tscn")

## 最近一次爆炸类效果的世界坐标，用于四个 8 的灼地落点
var _last_explosion_world_pos: Vector2 = Vector2.ZERO


## 执行整份计划；**`world` 须含 `parent`（Node）**；可选 `projectile_scene`（仅用于测试覆写）。`player` / `enemy_manager` 可从字典覆盖，缺省则经 **`get_combat_player()` / `get_enemy_manager()`**（与 `static var` 同源）
func execute(plan, world: Dictionary) -> void:
	var player: CombatPlayer = world.get("player", null) as CombatPlayer
	if not is_instance_valid(player):
		player = _CombatPlayerScript.get_combat_player() as CombatPlayer
	var enemy_manager: EnemyManager = world.get("enemy_manager", null) as EnemyManager
	if not is_instance_valid(enemy_manager):
		enemy_manager = _EnemyManagerScript.get_enemy_manager() as EnemyManager
	var parent: Node = world.get("parent", null) as Node

	# 默认并行弹道：只允许调用方测试覆写；正式链路由命令内 override 决定
	var projectile_scene: PackedScene = null

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
			# 多发弹道表现（并行直线/穿透等）
			_spawn_projectile_volley(player, enemy_manager, parent, projectile_scene, cmd)
		_CmdScript.CmdKind.WAYPOINT_VOLLEY:
			# 航点圆内随机多发：专用场景体 + 并发补发
			_spawn_waypoint_volley(player, enemy_manager, parent, projectile_scene, cmd)
		_CmdScript.CmdKind.EXPLOSIVE_VOLLEY:
			# 扇形爆炸载荷弹道（每路直线，命中爆炸），含灼地着地判定
			_spawn_explosive_volley(player, enemy_manager, parent, cmd)
		_CmdScript.CmdKind.EXPLOSION_ONE_SHOT:
			# 立即在目标爆炸，主要用于部分技能牌动画表现
			_spawn_explosion(player, enemy_manager, parent, cmd)
		_CmdScript.CmdKind.LASER_DUAL_BURST:
			# 发射双路激光（如技能 QKA）
			_spawn_laser_dual(player, enemy_manager, parent, cmd)
		_CmdScript.CmdKind.BURNING_GROUND:
			# 生成灼地效果
			_spawn_burning_ground(enemy_manager, parent, cmd)
		_CMD_METEOR_STORM:
			# 天外陨石：先采样落点，再由陨石脚本执行命中/爆炸/火焰
			_spawn_meteor_storm(player, enemy_manager, parent, cmd)
		_:
			# 其它（未实现或无表现）的命令类型忽略
			pass


## 无 `primary_hostile` 时扇形/并行的基准朝向（速度向优先，否则向右）
func _aim_forward_when_no_hostile(player: CombatPlayer) -> Vector2:
	var v: Vector2 = player.velocity
	if v.length_squared() > 4.0:
		return v.normalized()
	return Vector2.RIGHT


## 多发弹道：整洁优化版。负责从玩家位置并行布局多发弹体，预制体只取命令 override（无第三层全局兜底）。

func _spawn_projectile_volley(
	player: CombatPlayer,
	enemy_manager: EnemyManager,
	parent: Node,
	projectile_scene: PackedScene,
	cmd
) -> void:
	# 1. 参数检查与锁敌
	var lock_res = TargetConfirmDefault.resolve_global(
		cmd.lock_target_kind,
		player.get_attack_anchor_global(),
		cmd.lock_query_radius
	)
	if not lock_res.ok:
		return

	var target: CombatEnemy = lock_res.primary_hostile

	# 2. 计算朝向
	var forward: Vector2 = (
		_ProjectileToolScript.aim_forward_from_to(
			player.get_attack_anchor_global(),
			target.get_hurtbox_anchor_global()
		) if target != null else _aim_forward_when_no_hostile(player)
	)

	# 3. 基本参数
	var count := maxi(1, cmd.count)

	var line_spacing: float = (
		cmd.volley_line_spacing
	)

	# 4. 计算并行布局
	var layouts := _ProjectileToolScript.compute_parallel_layout(
		player.get_attack_anchor_global(),
		forward,
		count,
		line_spacing
	)

	# 5. 选定弹体预制体
	var scene_for_spawn: PackedScene = cmd.projectile_scene_override as PackedScene
	if scene_for_spawn == null:
		scene_for_spawn = projectile_scene
	if scene_for_spawn == null:
		push_warning("CombatEffectRunner: PROJECTILE_VOLLEY 缺少 projectile_scene_override，已跳过本次发射")
		return

	# 6. 其他参数
	var pierce := maxi(0, cmd.volley_pierce_extra_targets)

	# 7. 发射音效
	var fire_stream: AudioStream = cmd.sfx_fire as AudioStream
	if fire_stream:
		_play_volley_fire_sfx_at(parent, fire_stream, player.get_attack_anchor_global())

	# 8. 生成与发射弹体
	for entry in layouts:
		var spawn_pos: Vector2 = entry[_ProjectileToolScript.RESULT_KEY_POSITION]
		var inst: Node = scene_for_spawn.instantiate()
		if inst == null or not (inst is Node2D):
			continue
		if not inst.has_method("configure_from_volley"):
			push_error("CombatEffectRunner: 弹道预制缺少 configure_from_volley: %s" % scene_for_spawn.resource_path)
			continue

		var proj: Node2D = inst
		proj.global_position = spawn_pos

		proj.configure_from_volley(
			null,                           # 直线模式
			forward,
			enemy_manager,
			cmd.damage,
			pierce,
			cmd.volley_bind_presentation_slots,
			false,
			cmd.volley_linear_pierce,
			cmd.volley_use_primary_scene,
			cmd.hit_knockback_speed,
			cmd.sfx_hit_first as AudioStream,
			cmd.sfx_hit_pierce as AudioStream,
			cmd.sfx_hit_reroute as AudioStream
		)
		parent.call_deferred("add_child", proj)


## 航点齐射：`WaypointArenaProjectile` + `WaypointArenaVolleySpawner`；预制体只取命令 override
func _spawn_waypoint_volley(
	player: CombatPlayer,
	enemy_manager: EnemyManager,
	parent: Node,
	_projectile_scene: PackedScene,
	cmd
) -> void:
	var fire4: AudioStream = cmd.sfx_fire as AudioStream
	if fire4 != null:
		_play_volley_fire_sfx_at(parent, fire4, player.get_attack_anchor_global())
	_WaypointArenaVolleySpawnerScript.begin_volley(player, enemy_manager, parent, cmd)


## 在父节点下挂一次性 `AudioStreamPlayer2D` 播放配置内音效（流可空则调用方已过滤）
func _play_volley_fire_sfx_at(world_parent: Node, stream: AudioStream, world_pos: Vector2) -> void:
	if stream == null or world_parent == null:
		return
	var ap := AudioStreamPlayer2D.new()
	ap.stream = stream.duplicate(true) as AudioStream
	ap.global_position = world_pos
	ap.finished.connect(ap.queue_free)
	## 经本节点单次 **`call_deferred`** 完成挂父与 **`play()`**，避免 `world_parent.add_child` 与 `ap.play` 分两 object 入队导致同帧顺序错乱
	call_deferred("_deferred_attach_volley_fire_sfx_player", world_parent, ap)


## 在消息队列中保证 **`world_parent.add_child(ap)`** 后再 **`ap.play()`**
func _deferred_attach_volley_fire_sfx_player(world_parent: Node, ap: AudioStreamPlayer2D) -> void:
	if not is_instance_valid(world_parent) or not is_instance_valid(ap):
		return
	world_parent.add_child(ap)
	ap.play()


## 扇形爆炸载荷：经 ProjectileToolSingleton **角度扇**从玩家处发射，各弹沿扇向直线飞行，近敌或超时引爆；四条时仅最后一枚在命中点生成灼地
func _spawn_explosive_volley(
	player: CombatPlayer,
	enemy_manager: EnemyManager,
	parent: Node,
	cmd
) -> void:
	# 调用弹道锁定，取得命令指定的目标与相关参数（与多发弹道一致：锚点为玩家攻击锚点）
	var lock_res = TargetConfirmDefault.resolve_global(
		cmd.lock_target_kind,
		player.get_attack_anchor_global(),
		cmd.lock_query_radius
	)
	if not lock_res.ok:
		return
	var target: CombatEnemy = lock_res.primary_hostile
	var forward: Vector2
	# 依据是否有明确目标，决定发射扇方向
	if target != null:
		# 有目标时，沿玩家到目标方向发射
		forward = _ProjectileToolScript.aim_forward_from_to(
			player.get_attack_anchor_global(),
			target.get_hurtbox_anchor_global()
		)
	else:
		# 无目标时，用默认前向
		forward = _aim_forward_when_no_hostile(player)
	# 发射弹数量（至少为 1）
	var count: int = maxi(1, cmd.count)
	var mech8: CombatMechanicsTuning = GameConfig.COMBAT_MECHANICS as CombatMechanicsTuning
	var speed: float = mech8.explosive_payload_speed
	# 角度扇弧度：基础值加扩散参数调整
	var arc_deg: float = (
		mech8.explosive_angular_fan_arc_base_deg
		+ cmd.spread_deg * mech8.explosive_angular_fan_arc_per_spread_deg
	)
	# 计算所有弹在扇面上的起点和飞行方向
	var layouts: Array = _ProjectileToolScript.compute_angular_fan_layout(
		player.get_attack_anchor_global(),
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
		proj.set_script(_ExplosivePayloadScript)
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
		# 节点挂到场景树指定父节点（同帧可能遇「父忙」）
		parent.call_deferred("add_child", proj)
		i += 1


## 在指定位置生成一次性圆形爆炸
func _spawn_explosion(
	player: CombatPlayer,
	enemy_manager: EnemyManager,
	parent: Node,
	cmd
) -> void:
	var target := _nearest_hostile_for_explosion_anchor(enemy_manager, player.get_attack_anchor_global())
	var center: Vector2 = player.get_attack_anchor_global()
	if target != null:
		center = target.get_hurtbox_anchor_global()
	var radius: float = cmd.radius * cmd.radius_mul
	var dmg: int = int(round(float(cmd.damage) * cmd.damage_mul))
	var ex := _ExplosionOneShotScene.instantiate()
	ex.setup(enemy_manager, dmg, radius)
	ex.global_position = center
	parent.call_deferred("add_child", ex)
	_last_explosion_world_pos = center


## 多道平行短激光：`cmd.count` 为道数（默认 2，解析阶段已叠全局弹道加成）
func _spawn_laser_dual(player: CombatPlayer, enemy_manager: EnemyManager, parent: Node, cmd) -> void:
	var node := Node2D.new()
	node.set_script(load("res://scripts/combat/laser_burst_effect.gd"))
	var beams: int = maxi(2, cmd.count)
	node.setup(player, enemy_manager, cmd.damage, cmd.laser_duration, 14.0, beams)
	node.global_position = player.get_attack_anchor_global()
	parent.call_deferred("add_child", node)


## 灼烧地面落在最近一次爆炸中心
func _spawn_burning_ground(enemy_manager: EnemyManager, parent: Node, cmd) -> void:
	var zone := Node2D.new()
	zone.set_script(load("res://scripts/combat/burning_ground_zone.gd"))
	zone.setup(enemy_manager, cmd.radius, cmd.burn_duration, cmd.burn_dps)
	zone.global_position = _last_explosion_world_pos
	parent.call_deferred("add_child", zone)


## 爆炸圆心用最近敌（表现层锚点规则，**非**弹道首发索敌；与 `TargetConfirmDefault` 解耦）
func _nearest_hostile_for_explosion_anchor(enemy_manager: EnemyManager, from_position: Vector2) -> CombatEnemy:
	var nearest: CombatEnemy = null
	var best: float = INF
	for child in enemy_manager.get_units_root().get_children():
		var e := child as CombatEnemy
		if e == null or e.is_dead():
			continue
		var d2 := from_position.distance_squared_to(e.get_hurtbox_anchor_global())
		if d2 < best:
			best = d2
			nearest = e
	return nearest


## 执行天外陨石：采样落点并批量实例化陨石；四条时将凸包点下发给首颗陨石生成包围火焰区。
func _spawn_meteor_storm(
	_player: CombatPlayer,
	enemy_manager: EnemyManager,
	parent: Node,
	cmd
) -> void:
	# 中文：陨石表现层优先挂到 BattleUnits（启用 y_sort_enabled），使其与玩家/敌人按 Y 轴统一排序。
	var spawn_parent: Node = parent
	var battle_units: Node = parent.get_node_or_null("BattleUnits") as Node
	if battle_units != null:
		spawn_parent = battle_units
	var scene: PackedScene = cmd.meteor_scene_override as PackedScene
	if scene == null:
		push_warning("CombatEffectRunner: METEOR_STORM 缺少 meteor_scene_override，已跳过本次发射")
		return
	var camera: Camera2D = parent.get_viewport().get_camera_2d()
	if camera == null:
		push_warning("CombatEffectRunner: METEOR_STORM 缺少活动 Camera2D，已跳过本次发射")
		return
	# 中文：统一采样入口——根据配置决定“随机敌人位置”或“随机点位”，并由同一套校验约束视图与距离规则。
	var points: PackedVector2Array = _sample_meteor_points(camera, enemy_manager, parent, cmd)
	var hull_points: PackedVector2Array = PackedVector2Array()
	if bool(cmd.meteor_enable_polygon_fire):
		hull_points = _ProjectileToolScript.compute_convex_hull(points)
	for i in range(points.size()):
		var inst: Node = scene.instantiate()
		if inst == null or not (inst is Node2D):
			continue
		if not inst.has_method("setup_meteor"):
			push_error("CombatEffectRunner: 陨石预制缺少 setup_meteor: %s" % scene.resource_path)
			continue
		var meteor_node: Node2D = inst
		meteor_node.global_position = points[i]
		meteor_node.setup_meteor(
			enemy_manager,
			int(cmd.meteor_impact_damage),
			float(cmd.meteor_fall_duration_sec),
			float(cmd.meteor_lifetime_sec),
			float(cmd.meteor_scale_mul),
			bool(cmd.meteor_enable_end_explosion),
			int(cmd.meteor_end_explosion_damage),
			bool(cmd.meteor_enable_ellipse_fire),
			int(cmd.meteor_ellipse_fire_dps),
			float(cmd.meteor_ellipse_fire_tick_sec),
			bool(cmd.meteor_enable_polygon_fire) and i == 0,
			hull_points,
			int(cmd.meteor_polygon_fire_dps),
			float(cmd.meteor_polygon_fire_tick_sec)
		)
		spawn_parent.call_deferred("add_child", meteor_node)


## 按命令配置采样陨石落点：可走随机敌人位置或随机点位，并在必要时回退补齐。
func _sample_meteor_points(
	camera: Camera2D,
	enemy_manager: EnemyManager,
	_parent: Node,
	cmd
) -> PackedVector2Array:
	var points := PackedVector2Array()
	var target_count: int = maxi(1, int(cmd.meteor_count))
	var max_attempts: int = maxi(1, int(cmd.meteor_sample_max_attempts))
	var min_dist: float = maxf(0.0, float(cmd.meteor_point_min_distance))
	var max_dist: float = maxf(min_dist, float(cmd.meteor_point_max_distance))
	var limit_dist: bool = bool(cmd.meteor_limit_point_distance)
	# 中文：分支语义——开启“随机敌人取样”时先尝试敌人位置，不足数量再回退随机点位补齐。
	if bool(cmd.meteor_sample_from_random_enemy):
		_collect_points_from_random_enemies(
			points, enemy_manager, camera, target_count, max_attempts, min_dist, max_dist, limit_dist
		)
	if points.size() < target_count:
		_collect_points_from_random_area(
			points, camera, target_count, max_attempts, min_dist, max_dist, limit_dist
		)
	return points


## 从活敌人中随机抽取位置作为候选落点；统一应用视图与距离限制校验。
func _collect_points_from_random_enemies(
	out_points: PackedVector2Array,
	enemy_manager: EnemyManager,
	camera: Camera2D,
	target_count: int,
	max_attempts: int,
	min_dist: float,
	max_dist: float,
	limit_dist: bool
) -> void:
	if enemy_manager == null:
		return
	var enemies: Array[CombatEnemy] = []
	for child in enemy_manager.get_units_root().get_children():
		var enemy: CombatEnemy = child as CombatEnemy
		if enemy == null or enemy.is_dead():
			continue
		enemies.append(enemy)
	if enemies.is_empty():
		return
	var tries: int = 0
	while out_points.size() < target_count and tries < max_attempts:
		tries += 1
		var idx: int = randi_range(0, enemies.size() - 1)
		var pos: Vector2 = enemies[idx].get_hurtbox_anchor_global()
		if not _is_point_in_camera_view(camera, pos):
			continue
		if not _is_valid_meteor_distance(pos, out_points, min_dist, max_dist, limit_dist):
			continue
		out_points.append(pos)


## 在相机可见区内随机采样点位；根据开关决定是否应用 min/max 距离限制。
func _collect_points_from_random_area(
	out_points: PackedVector2Array,
	camera: Camera2D,
	target_count: int,
	max_attempts: int,
	min_dist: float,
	max_dist: float,
	limit_dist: bool
) -> void:
	# 中文：随机点位必须在“世界坐标可视矩形”内采样，不能直接用屏幕像素坐标。
	var world_rect: Rect2 = _get_camera_world_rect(camera)
	var tries: int = 0
	while out_points.size() < target_count and tries < max_attempts:
		tries += 1
		var candidate := Vector2(
			randf_range(world_rect.position.x, world_rect.end.x),
			randf_range(world_rect.position.y, world_rect.end.y)
		)
		if not _is_point_in_camera_view(camera, candidate):
			continue
		if not _is_valid_meteor_distance(candidate, out_points, min_dist, max_dist, limit_dist):
			continue
		out_points.append(candidate)


## 判定候选点是否在当前相机可见区域内（将视口局部坐标转换为世界坐标后比较）。
func _is_point_in_camera_view(camera: Camera2D, world_pos: Vector2) -> bool:
	var world_rect: Rect2 = _get_camera_world_rect(camera)
	return world_rect.has_point(world_pos)


## 计算 Camera2D 当前可视的世界矩形：以屏幕中心和 zoom 推导世界宽高。
func _get_camera_world_rect(camera: Camera2D) -> Rect2:
	var vp_size: Vector2 = camera.get_viewport_rect().size
	var half_size_world: Vector2 = (vp_size * camera.zoom) * 0.5
	var center: Vector2 = camera.get_screen_center_position()
	return Rect2(center - half_size_world, half_size_world * 2.0).abs()


## 落点间距校验：关闭限制时总是通过；开启时需满足与已选点距离在 [min, max]。
func _is_valid_meteor_distance(
	candidate: Vector2,
	points: PackedVector2Array,
	min_dist: float,
	max_dist: float,
	limit_dist: bool
) -> bool:
	if not limit_dist:
		return true
	for p in points:
		var d: float = candidate.distance_to(p)
		# 中文：距离限制为互斥边界——小于最小间距过密，超过最大间距过散，任一触发都拒绝该候选点。
		if d < min_dist or d > max_dist:
			return false
	return true
