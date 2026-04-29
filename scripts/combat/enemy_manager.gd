extends Node
class_name EnemyManager
## 策划表访问（见 `enemy.gd` 说明）

## 在玩家周围按间隔生成敌人，并限制场上最大数量；有摄像机时在**视口左右外侧**、**顶底墙可走竖带**内落点，并用体积圆 + 多点探测避开 **`world_barrier_collision_layer`**
## 敌实例加在 `units_root`（与玩家同层的 `BattleUnits`）上；由该层 `y_sort_enabled` 按 **global Y** 排序（靠下者压上）
## 约定：`CharacterBody2D` 脚点为原点；精灵子节点上移对齐脚底（见 `player.tscn` / `Slm.tscn`）

## 进程内当前敌人管理器引用（`_enter_tree` 写入、`_exit_tree` 清空）；本局仅应存在一个 `EnemyManager`；其它脚本经 `preload` 后调用 `get_enemy_manager()` 或读此字段
static var enemy_manager_singleton: EnemyManager = null


## 返回当前已注册的全局敌人管理器；未进树或已出场时为 null（跨脚本请 `preload("enemy_manager.gd")` 再调本方法）
static func get_enemy_manager() -> EnemyManager:
	return enemy_manager_singleton


## 敌人场景预制
@export var enemy_scene: PackedScene
## 生成间隔（秒）；默认与 **`EnemyConfig.spawn_interval_seconds`** 资源脚本一致，避免类体访问 **`GameConfig`** 引发解析顺序问题
@export var spawn_interval_seconds: float = 1.5
## 场上敌人数量上限；默认与 **`EnemyConfig.max_alive`** 一致
@export var max_alive_enemies: int = 12
## 相对目标生成半径（像素）；默认与 **`EnemyConfig.spawn_radius`** 一致
@export var spawn_radius: float = 340.0
## 追击目标节点（通常为玩家）
@export var target: Node2D
## 用于「视口外生成」判定的摄像机；未设时回退为旧逻辑（玩家周围 **`spawn_radius`** 环）
@export var spawn_viewport_camera: Camera2D
## 视口轴对齐矩形再 **`grow`** 此边距（像素）；敌人体积圆须**完全**在该矩形**左右外侧**（不在上下沿外刷怪）
@export var spawn_outside_viewport_margin_px: float = 80.0
## 用圆近似敌人体积（脚点为圆心、半径为此值），须与常见敌 **`CollisionShape2D`** 尺度同量级
@export var spawn_body_radius_px: float = 56.0
## 在视口左或右侧、沿 X 再随机外推的深度上限（像素），与 **`spawn_radius`** 取较大者作为原始区间长度，再经 **`spawn_side_outward_depth_cap_px`** 夹紧，避免刷在「屏幕外很远」
@export var spawn_side_extra_depth_px: float = 420.0
## 相对「刚完全出屏」的边线，敌脚点最多再往外的随机深度上限（像素）；越小越贴视口/场景边界
@export_range(32.0, 360.0, 4.0) var spawn_side_outward_depth_cap_px: float = 112.0
## 脚点 Y 须在顶底墙可走带内，再相对墙沿内缩（像素）
@export var spawn_vertical_margin_inside_playfield_px: float = 12.0
## 随机左右侧 + Y 的最大尝试次数
@export var spawn_max_pick_attempts: int = 48
## 兜底时在视口外再外推的距离（像素，沿 X）；过大易离场景过远，建议与 **`spawn_side_outward_depth_cap_px`** 同量级
@export_range(16.0, 280.0, 4.0) var spawn_fallback_extra_px: float = 72.0
## 玩家与敌实例共用的战场单位层（`Node2D` 且启用 `y_sort_enabled`）；未赋值时敌仍加在自身下（仅兼容旧场景）
@export var units_root: Node2D

## 本局玩家侧累计击杀（敌 **`_die`** 时 +1）；与金币等经济解耦，供 HUD 骷髅数展示
signal run_kill_count_changed(new_total: int)

## 距上次生成累计秒数
var _spawn_timer := 0.0
## 是否允许生成
var _active := true
## 本局击杀计数（仅统计；不在此做奖励结算）
var run_kill_count: int = 0
## 测试菜单「疯狂模式」：为真时每击杀一只敌约 **`TEST_CRAZY_RESPAWN_DELAY_SEC`** 秒后额外生成 **`TEST_CRAZY_RESPAWN_COUNT`** 只同预制体敌（不计入常规 **`max_alive_enemies`** 上限）
var test_crazy_kill_respawn_enabled: bool = false
## 疯狂模式延迟（秒）
const TEST_CRAZY_RESPAWN_DELAY_SEC: float = 3.0
## 疯狂模式每次补怪数量
const TEST_CRAZY_RESPAWN_COUNT: int = 3
## 场景加载时的生成间隔基底（秒），供随等级缩放：`max(下限, 基底/(1+k*(等级-1)))`（见 `EnemyConfig.spawn_interval_level_k`）；**`_ready`** 用当前 **`spawn_interval_seconds`** 写入
## 中文：类体不读 **`GameConfig.ENEMY_CONFIG`**（与 **`GAME_GLOBAL`** 同属 `GameConfig` 静态初始化链）
var _base_spawn_interval_seconds: float = 1.5


## 进入场景树时注册为全局单例（供 `CombatEffectRunner`、索敌等获取）
func _enter_tree() -> void:
	if enemy_manager_singleton != null and is_instance_valid(enemy_manager_singleton) and enemy_manager_singleton != self:
		push_warning("EnemyManager: 重复注册全局单例，将覆盖为当前节点")
	enemy_manager_singleton = self


## 离开场景树时注销单例
func _exit_tree() -> void:
	if enemy_manager_singleton == self:
		enemy_manager_singleton = null


## 开局或重开战斗时清零击杀展示
func reset_run_kill_count() -> void:
	run_kill_count = 0
	emit_signal("run_kill_count_changed", run_kill_count)


## 敌死亡时由 **`CombatEnemy._die`** 调用，累加本局击杀；**`killed`** 非空且开启疯狂模式时登记延时补怪
func register_enemy_kill(killed: CombatEnemy = null) -> void:
	run_kill_count += 1
	emit_signal("run_kill_count_changed", run_kill_count)
	if not test_crazy_kill_respawn_enabled or killed == null:
		return
	var ps: PackedScene = _packed_scene_for_enemy_template(killed)
	if ps == null:
		return
	var respawn_timer: SceneTreeTimer = get_tree().create_timer(TEST_CRAZY_RESPAWN_DELAY_SEC)
	respawn_timer.timeout.connect(
		func () -> void:
			if not is_instance_valid(self):
				return
			_spawn_crazy_mode_batch(ps),
		CONNECT_ONE_SHOT
	)


## 初始化随机种子；若检查器里 `units_root` 未解析（常见为 `NodePath` 相对根写错），从父节点按名绑定 `BattleUnits`
func _ready() -> void:
	_base_spawn_interval_seconds = spawn_interval_seconds
	randomize()
	if units_root == null or not is_instance_valid(units_root):
		var p := get_parent()
		if p != null:
			var bu := p.get_node_or_null("BattleUnits")
			if bu is Node2D:
				units_root = bu as Node2D


## 返回挂载玩家与敌人的 Y-sort 父节点；未配置 `units_root` 时回退为自身
func get_units_root() -> Node:
	if units_root != null and is_instance_valid(units_root):
		return units_root
	return self


## 计时满足且未达上限时生成一只怪
func _process(delta: float) -> void:
	if not _active:
		return
	if enemy_scene == null or not is_instance_valid(target):
		return
	if _alive_enemy_count() >= max_alive_enemies:
		return

	_spawn_timer += delta
	if _spawn_timer < spawn_interval_seconds:
		return

	_spawn_timer = 0.0
	_spawn_enemy()


## 开关生成逻辑（选牌阶段可关）
func set_active(active: bool) -> void:
	_active = active


## 按玩家战斗等级刷新生成间隔：等级越高间隔越短，不低于 `EnemyConfig.spawn_interval_min_seconds`
func apply_spawn_interval_for_player_level(player_level: int) -> void:
	var lvl: int = maxi(1, player_level)
	var ec: EnemyConfig = GameConfig.ENEMY_CONFIG
	var denom: float = 1.0 + ec.spawn_interval_level_k * float(max(0, lvl - 1))
	spawn_interval_seconds = maxf(ec.spawn_interval_min_seconds, _base_spawn_interval_seconds / denom)


## 统计 `units_root` 下仍存活的 `CombatEnemy` 数量（不含玩家；用于生成上限）
func _alive_enemy_count() -> int:
	var n := 0
	for c in get_units_root().get_children():
		var ce := c as CombatEnemy
		if ce == null or ce.is_dead():
			continue
		n += 1
	return n


## 在合法世界坐标摆一只敌人并设 **`target`**：优先「摄像机视口外 + 非世界阻挡层」；无摄像机时回退旧环逻辑
func _spawn_enemy() -> void:
	if enemy_scene == null:
		return
	_spawn_enemy_from_scene(enemy_scene, _pick_spawn_world_position())


## 用指定预制体在 **`world_pos`** 生成一只敌（常规生成与疯狂补怪共用）
func _spawn_enemy_from_scene(ps: PackedScene, world_pos: Vector2) -> void:
	if ps == null or not is_instance_valid(target):
		return
	var enemy: Node = ps.instantiate()
	if enemy == null:
		return
	enemy.global_position = world_pos
	if enemy is CombatEnemy:
		(enemy as CombatEnemy).target = target
	get_units_root().add_child(enemy)
	print("[spawn] enemy_spawned | enemies=%d" % _alive_enemy_count())


## 由击杀登记延时触发：连刷 **`TEST_CRAZY_RESPAWN_COUNT`** 只，**不**受 **`max_alive_enemies`** 限制（测试用）
func _spawn_crazy_mode_batch(ps: PackedScene) -> void:
	if ps == null or not is_instance_valid(target):
		return
	for __i in range(TEST_CRAZY_RESPAWN_COUNT):
		_spawn_enemy_from_scene(ps, _pick_spawn_world_position())


## 从被击杀实例解析用于复活的 **`PackedScene`**：无场景路径时回落 **`enemy_scene`**
func _packed_scene_for_enemy_template(killed: CombatEnemy) -> PackedScene:
	if killed == null or not is_instance_valid(killed):
		return enemy_scene
	var path: String = killed.get_scene_file_path()
	if path.is_empty():
		return enemy_scene
	var res: Resource = load(path)
	if res is PackedScene:
		return res as PackedScene
	return enemy_scene


## 选取合法生成世界坐标：**仅**摄像机视口**左或右**外侧；脚点 Y 在顶底墙可走竖带内；用 **`spawn_body_radius_px`** 圆与多点采样保证**不在墙体内**且圆与视口膨胀矩形不相交
func _pick_spawn_world_position() -> Vector2:
	if target == null or not is_instance_valid(target):
		return Vector2.ZERO
	if spawn_viewport_camera == null or not is_instance_valid(spawn_viewport_camera):
		var random_direction_legacy := Vector2.RIGHT.rotated(randf_range(0.0, TAU))
		return target.global_position + random_direction_legacy * spawn_radius
	var cam: Camera2D = spawn_viewport_camera
	var vis: Rect2 = _camera_visible_world_rect(cam)
	var m: float = spawn_outside_viewport_margin_px
	var R: float = maxf(4.0, spawn_body_radius_px)
	var y_span: Vector2 = _playable_feet_y_span()
	var y_lo: float = y_span.x
	var y_hi: float = y_span.y
	var raw_depth: float = maxf(spawn_radius, spawn_side_extra_depth_px)
	var depth: float = minf(raw_depth, maxf(24.0, spawn_side_outward_depth_cap_px))
	var ex: Rect2 = vis.grow(m)
	for _i in range(spawn_max_pick_attempts):
		var go_left: bool = randf() < 0.5
		var sx: float
		if go_left:
			var x_max: float = ex.position.x - R - 2.0
			var x_min: float = x_max - depth
			sx = randf_range(x_min, x_max)
		else:
			var x_min_r: float = ex.end.x + R + 2.0
			var x_max_r: float = x_min_r + depth
			sx = randf_range(x_min_r, x_max_r)
		var sy: float = randf_range(y_lo, y_hi)
		if not _foot_circle_clear_of_expanded_viewport(sx, sy, vis, m, R):
			continue
		if _spawn_barrier_overlap_for_foot(sx, sy, R):
			continue
		return Vector2(sx, sy)
	var pad_x: float = minf(spawn_fallback_extra_px + R, R + maxf(16.0, spawn_side_outward_depth_cap_px))
	var y_mid: float = (y_lo + y_hi) * 0.5
	if randf() < 0.5:
		return Vector2(ex.position.x - pad_x, y_mid)
	return Vector2(ex.end.x + pad_x, y_mid)


## 当前场景下地牢条带根（**`dungeon_strip_playfield`** 组优先，便于复制预制后改名）；否则 **`DungeonStripEnvironment`** / 旧 **`DungeonWorldBarriers`**
func _find_dungeon_world_barriers() -> Node:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	var by_group: Node = scene.get_tree().get_first_node_in_group("dungeon_strip_playfield") as Node
	if by_group != null:
		return by_group
	var n: Node = scene.get_node_or_null("DungeonStripEnvironment")
	if n != null:
		return n
	return scene.get_node_or_null("DungeonWorldBarriers")


## 可走竖带内脚点 Y 范围 **[min,max]**；无墙节点时用 **`map_height`** 比例回退
func _playable_feet_y_span() -> Vector2:
	var br: Node = _find_dungeon_world_barriers()
	if br != null and br.has_method("get_playable_feet_y_span_world"):
		return br.get_playable_feet_y_span_world(spawn_vertical_margin_inside_playfield_px) as Vector2
	var h: float = GameConfig.GAME_GLOBAL.map_height
	return Vector2(h * 0.12, h * 0.88)


## 以脚点为圆心、半径 **`R`** 的占位圆与视口 **`vis` 再 grow `margin_px`** 后的矩形在 X 上**完全不相交**（只接受左右外侧）
func _foot_circle_clear_of_expanded_viewport(sx: float, _sy: float, vis: Rect2, margin_px: float, R: float) -> bool:
	var ex: Rect2 = vis.grow(margin_px)
	var fully_left: bool = (sx + R) < ex.position.x
	var fully_right: bool = (sx - R) > ex.end.x
	return fully_left or fully_right


## 在脚点附近多点探测 **`world_barrier_collision_layer`**，避免圆心落在缝外但体积仍压进顶底墙
func _spawn_barrier_overlap_for_foot(sx: float, sy: float, R: float) -> bool:
	var pts: Array[Vector2] = [
		Vector2(sx, sy),
		Vector2(sx, sy - R * 0.85),
		Vector2(sx, sy - R * 1.55),
		Vector2(sx + R * 0.75, sy),
		Vector2(sx - R * 0.75, sy),
		Vector2(sx + R * 0.55, sy - R * 0.9),
		Vector2(sx - R * 0.55, sy - R * 0.9),
	]
	for p in pts:
		if _is_point_blocked_by_world_barrier(p):
			return true
	return false


## 计算 **`Camera2D`** 当前视口在世界坐标下的轴对齐矩形（按 **`zoom`** 缩放半尺寸）
func _camera_visible_world_rect(cam: Camera2D) -> Rect2:
	var half: Vector2 = get_viewport().get_visible_rect().size * 0.5
	if cam.zoom.x > 0.001 and cam.zoom.y > 0.001:
		half /= cam.zoom
	var c: Vector2 = cam.get_screen_center_position()
	return Rect2(c - half, half * 2.0)


## 用 **`PhysicsDirectSpaceState2D.intersect_point`** 检测该世界点是否落在 **`world_barrier_collision_layer`** 的 **`StaticBody2D`** 上（墙体内不可生成）
func _is_point_blocked_by_world_barrier(world_pt: Vector2) -> bool:
	var w2: World2D = target.get_world_2d()
	if w2 == null:
		return false
	var space: PhysicsDirectSpaceState2D = w2.direct_space_state
	var q: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	q.position = world_pt
	q.collision_mask = GameConfig.GAME_GLOBAL.world_barrier_collision_layer
	var hits: Array = space.intersect_point(q, 8)
	return not hits.is_empty()
