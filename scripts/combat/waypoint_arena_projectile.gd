extends Node2D
## 策划表访问（见 `enemy.gd` 说明）
## 中文：无 `class_name`（单文件多次解析时与已注册全局名冲突会报「隐藏全局脚本类」）；对接方用 `has_method` / 场景脚本路径

## **锚点圆内随机航点弹道**（与具体牌面点数解耦）：圆内**随机航点**巡航，到达后减速→转向下一航点→加速；运动用 **`_heading`（单位方向）+ `_speed`（标量）** 积分，航向每帧仅转过 `heading_turn_rate·Δt`，不做单帧对向；命中由子节点 **`CombatHitbox2D`** 与敌 **`CombatHurtbox2D`** 重叠投递；总命中次数达 `1+穿透` 后入池或销毁。默认航点预制由牌型目录解析后写入命令 override。

## 类级静态：`WaypointArenaVolleySpawner` 的 `GDScript`，供调用其 `static func`（本脚本已去掉 `class_name`，顶栏 `preload` 无「隐藏全局类」问题）
static var _volley_spawner_script: GDScript = preload("res://scripts/combat/waypoint_arena_volley_spawner.gd")
## 预制体内嵌尾流实例节点名（与 `WaypointArenaBulletProjectile.tscn` 等一致）；池复用时对其内 **`GPUParticles2D`** 做 **`restart`**
const _EMBEDDED_TRAIL_INSTANCE_NAME := "Rank2ProjectileTrail"

## 运动相：巡航接近航点 → 刹车 → 低速对准下一航点 → 加速回巡航
enum _Phase { CRUISE, BRAKE, TURN, RAMP }

var _phase: _Phase = _Phase.CRUISE
## 当前速度向量（像素/秒）；由 `_heading * _speed` 同步，供命中与表现读取
var _vel: Vector2 = Vector2.ZERO
## 运动方向单位向量；**仅**经 `_steer_dir_shortest` 每帧小步更新，禁止单帧赋成目标方向，以实现 U 形平滑转向
var _heading: Vector2 = Vector2.RIGHT
## 标量速率（像素/秒）；与航向解耦，加减速用 `move_toward`
var _speed: float = 0.0
var _waypoint: Vector2 = Vector2.ZERO
var _enemy_manager: EnemyManager = null
var _player: CombatPlayer = null
var _circle_radius: float = 720.0
var _damage: int = 0
var _total_hits: int = 1
var _hits_done: int = 0
var _pierce_exclude: Array = []
## 为真时走表现槽命中反馈与航点专属命中音链（与命令 **`volley_bind_presentation_slots`** 一致）
var _bind_presentation_slots: bool = false
## 命令注入：首击音效
var _cmd_hit_sfx_first: AudioStream = null
## 命令注入：穿透段音效
var _cmd_hit_sfx_pierce: AudioStream = null
## 命令注入：换向段音效
var _cmd_hit_sfx_reroute: AudioStream = null
## 从巡航切入刹车前瞬间的航向（归一化），用于下一航点采样时避免与上一段**几乎反向**，减少「两点间来回弹」观感
var _incoming_dir_before_brake: Vector2 = Vector2.RIGHT
## 命中盒投递：与 **`Projectile`** 一致，重叠时由 **`CombatHitbox2D`** 调 **`CombatHurtbox2D.receive_hit`**
var _hit_delivery: CombatHitDelivery = CombatHitDelivery.new()
## 为真时已排队 `_retire_deferred_impl`，防止同帧重复 **`call_deferred`**；池复用时在 **`setup_waypoint_arena_volley`** 清零
var _retire_deferred_pending: bool = false
## 新航点与「刚到达的上一目标」最小世界距离（占 `_circle_radius` 比例），避免连续目标落在几乎同一处
const _MIN_NEW_WP_SEPARATION_FRAC: float = 0.12
## 新段出射方向与进入刹车前航向的点积下限；低于此视为近似原路掉头，换一批随机
const _MIN_OUT_VS_INCOMING_DOT: float = -0.32

@onready var sprite: Sprite2D = $Sprite


## 入树后延迟配置命中盒，保证子节点已进树且与 **`setup_waypoint_arena_volley`** 写入的 **`_damage`** 一致（含池复用）
func _enter_tree() -> void:
	call_deferred("_setup_combat_hitbox")


## 由 `WaypointArenaVolleySpawner` 在挂树前调用；**`spawn_world`** 为首帧世界坐标（通常即攻击锚点）；对象池复用时每次重跑以重置运动与表现
## 配置路径弹对象参数，重置其各项状态，为新一轮弹道做准备
func setup_waypoint_arena_volley(
	player: CombatPlayer, # 来自玩家对象, 绑定投射物归属
	enemy_manager: EnemyManager, # 敌方管理器, 供采样目标
	cmd, # 指令对象, 包含各种参数 (如伤害、轨迹等)
	spawn_world: Vector2 # 初始世界坐标
) -> void:
	_retire_deferred_pending = false # 取消已延迟清理标志
	_phase = _Phase.CRUISE # 进入初始巡航状态
	_hits_done = 0 # 已命中数重置
	_pierce_exclude.clear() # 穿透排除表清空
	_incoming_dir_before_brake = Vector2.RIGHT # 上一转向向量重置
	_player = player # 记录玩家
	_enemy_manager = enemy_manager # 记录敌人管理器
	_damage = maxi(0, cmd.damage) # 设置本次伤害值(不得低于0)
	_total_hits = maxi(1, 1 + maxi(0, cmd.volley_pierce_extra_targets)) # 计算最大命中目标数
	_bind_presentation_slots = cmd.volley_bind_presentation_slots # 是否槽表现绑定
	_cmd_hit_sfx_first = cmd.sfx_hit_first as AudioStream # 首击音效
	_cmd_hit_sfx_pierce = cmd.sfx_hit_pierce as AudioStream # 穿透音效
	_cmd_hit_sfx_reroute = cmd.sfx_hit_reroute as AudioStream # 换向音效
	_hit_delivery.knockback_speed = cmd.hit_knockback_speed # 设置击退速度
	# _hit_delivery.use_parallel_volley_knockback_profile = true # 并排弹使用平行击退设定
	_circle_radius = maxf(8.0, cmd.lock_query_radius) # 锁定采样半径最小值 8.0
	global_position = spawn_world # 设置世界坐标
	var c0: Vector2 = _anchor_center() # 圆盘中心锚点
	_waypoint = _random_point_in_disk(c0, _circle_radius) # 随机采样圆盘内新航点
	var to0: Vector2 = _waypoint - global_position # 首段目标向量
	var mech0: CombatMechanicsTuning = GameConfig.COMBAT_MECHANICS as CombatMechanicsTuning # 游戏数值调优参数
	var vmax: float = mech0.waypoint_max_speed # 取最大速度
	if to0.length_squared() > 1e-4:
		_heading = to0.normalized() # 有效目标则取归一航向
	else:
		_heading = Vector2.RIGHT # 否则默认向右
	_speed = vmax * 0.38 # 初始速度为基准速度的 0.38 倍
	_sync_vel_from_heading_speed() # 刷新速度向量
	_apply_placeholder_sprite_when_missing() # 无贴图时涂占位
	_restart_embedded_trail_particles() # 出场时重启尾流粒子


func _ready() -> void:
	_volley_spawner_script.register_projectile(self)
	_apply_placeholder_sprite_when_missing()


## 与 `setup_waypoint_arena_volley` 共用：精灵无贴图时写占位纹理（尾迹在预制体场景内配置，不在此脚本挂载）
func _apply_placeholder_sprite_when_missing() -> void:
	var spr: Sprite2D = get_node_or_null("Sprite") as Sprite2D
	if spr != null and spr.texture == null:
		spr.texture = _create_fallback_texture()


## 在子树中查找首个 **`GPUParticles2D`**（内嵌尾流预制根下常见一层 **`Control`** 包一层粒子）
func _find_first_gpu_particles_2d(root: Node) -> GPUParticles2D:
	if root == null:
		return null
	if root is GPUParticles2D:
		return root as GPUParticles2D
	for c in root.get_children():
		var found: GPUParticles2D = _find_first_gpu_particles_2d(c)
		if found != null:
			return found
	return null


## 对象池再次出场时清空粒子状态，避免拖尾接在上一次飞行末尾
func _restart_embedded_trail_particles() -> void:
	var inst_root: Node = get_node_or_null(_EMBEDDED_TRAIL_INSTANCE_NAME)
	if inst_root == null:
		return
	var parts: GPUParticles2D = _find_first_gpu_particles_2d(inst_root)
	if parts != null:
		parts.restart()


func _exit_tree() -> void:
	_volley_spawner_script.unregister_projectile(self)
	_volley_spawner_script.notify_projectile_freed()


## 配置子节点 **`CombatHitbox2D`**：层掩码对齐 **`GameConfig.GAME_GLOBAL`**，写入投递并启动重叠监听（伤害在 Hitbox 内已结算）
func _setup_combat_hitbox() -> void:
	if not is_inside_tree():
		return
	var hb: Area2D = get_node_or_null("CombatHitbox2D") as Area2D
	if hb == null:
		return
	_hit_delivery.damage = maxi(0, _damage)
	_hit_delivery.source = self
	if hb.has_method("set_hit_delivery"):
		hb.call("set_hit_delivery", _hit_delivery)
	var gg := GameConfig.GAME_GLOBAL
	if hb.has_method("configure_collision_layers"):
		hb.call(
			"configure_collision_layers",
			gg.combat_hitbox_collision_layer,
			gg.combat_hurtbox_collision_layer
		)
	if hb.has_signal("hit_body") and not hb.hit_body.is_connected(_on_combat_hitbox_hit_body):
		hb.hit_body.connect(_on_combat_hitbox_hit_body)
	if hb.has_method("start_monitoring"):
		hb.call("start_monitoring")


## 命中盒回调：扣血已在 Hitbox→Hurtbox 完成；此处做穿透排除、音效、受击表现与入池
func _on_combat_hitbox_hit_body(body: Node2D, hit_pos: Vector2) -> void:
	var e := body as CombatEnemy
	if e == null or e.is_dead():
		return
	if _hits_done >= _total_hits:
		return
	if _pierce_exclude.has(e):
		return
	_hits_done += 1
	_play_hit_sfx()
	_spawn_volley_hit_feedback_at(hit_pos)
	_pierce_exclude.append(e)
	if _hits_done >= _total_hits:
		_retire()


## 每帧：分相积分位置/速度（命中由 **`CombatHitbox2D`** 驱动）
func _process(delta: float) -> void:
	if _enemy_manager == null:
		_retire()
		return
	if _hits_done >= _total_hits:
		_retire()
		return

	_volley_spawner_script.maybe_periodic_batch_waypoint_refresh()

	var mech: CombatMechanicsTuning = GameConfig.COMBAT_MECHANICS as CombatMechanicsTuning
	var max_sp: float = mech.waypoint_max_speed
	var accel: float = mech.waypoint_accel
	var decel: float = mech.waypoint_decel
	var arrive_d: float = maxf(4.0, mech.waypoint_arrive_distance)
	var slow_r: float = maxf(arrive_d * 1.5, mech.waypoint_arrival_slowing_radius)
	var brake_th: float = mech.waypoint_brake_speed_threshold
	var v_turn: float = maxf(20.0, mech.waypoint_reorient_cruise_speed)
	var turn_k: float = mech.waypoint_heading_turn_rate

	var turn_step: float = turn_k * delta

	match _phase:
		_Phase.CRUISE:
			var to_wp: Vector2 = _waypoint - global_position
			var dist: float = to_wp.length()
			if dist < arrive_d:
				_incoming_dir_before_brake = _heading
				_phase = _Phase.BRAKE
			else:
				var target_dir: Vector2 = to_wp / maxf(dist, 0.001)
				var dspeed: float = max_sp
				if dist < slow_r:
					dspeed = max_sp * clampf(dist / slow_r, 0.12, 1.0)
				_heading = _steer_dir_shortest(_heading, target_dir, turn_step)
				_speed = move_toward(_speed, dspeed, accel * delta)
				_sync_vel_from_heading_speed()
				global_position += _vel * delta
				_set_rotation_from_vel()

		_Phase.BRAKE:
			var to_b: Vector2 = _waypoint - global_position
			var dist_b: float = to_b.length()
			var tdir_b: Vector2
			if dist_b > 6.0:
				tdir_b = to_b / dist_b
			else:
				tdir_b = _heading
			_heading = _steer_dir_shortest(_heading, tdir_b, turn_step)
			_speed = move_toward(_speed, 0.0, decel * delta)
			_sync_vel_from_heading_speed()
			global_position += _vel * delta
			_set_rotation_from_vel()
			if _speed < brake_th:
				var finished_wp: Vector2 = _waypoint
				_waypoint = _pick_next_waypoint_distinct(finished_wp)
				_phase = _Phase.TURN

		_Phase.TURN:
			var to_w: Vector2 = _waypoint - global_position
			var tdir: Vector2 = to_w.normalized() if to_w.length_squared() > 1e-6 else Vector2.RIGHT
			_heading = _steer_dir_shortest(_heading, tdir, turn_step)
			_speed = move_toward(_speed, v_turn, accel * delta)
			_sync_vel_from_heading_speed()
			global_position += _vel * delta
			_set_rotation_from_vel()
			if _heading.dot(tdir) > 0.985 and _speed >= v_turn * 0.9:
				_phase = _Phase.RAMP

		_Phase.RAMP:
			var to_w2: Vector2 = _waypoint - global_position
			var tdir2: Vector2 = to_w2.normalized() if to_w2.length_squared() > 1e-6 else Vector2.RIGHT
			_heading = _steer_dir_shortest(_heading, tdir2, turn_step)
			_speed = move_toward(_speed, max_sp, accel * delta)
			_sync_vel_from_heading_speed()
			global_position += _vel * delta
			_set_rotation_from_vel()
			if _speed >= max_sp * 0.93 and _heading.dot(tdir2) > 0.97:
				_phase = _Phase.CRUISE


## 取当前玩家攻击锚点；玩家失效时用自身位置为圆心（退化）
func _anchor_center() -> Vector2:
	if is_instance_valid(_player):
		return _player.get_attack_anchor_global()
	return global_position


## 由 `WaypointArenaVolleySpawner` 按配置间隔统一下发：新航点为当前锚点圆内随机，相位拉回巡航并令速度大致指向新目标
func apply_batch_waypoint_refresh_in_player_disk() -> void:
	if _enemy_manager == null:
		return
	if not is_instance_valid(_player):
		return
	var c: Vector2 = _anchor_center()
	_waypoint = _random_point_in_disk(c, _circle_radius)
	_phase = _Phase.CRUISE
	_sync_vel_from_heading_speed()
	_set_rotation_from_vel()


## 圆盘内均匀随机点（相对 `center`）
func _random_point_in_disk(center: Vector2, radius: float) -> Vector2:
	var t: float = randf() * TAU
	var rr: float = sqrt(randf()) * maxf(1.0, radius)
	return center + Vector2(cos(t), sin(t)) * rr


## 到达上一航点后选取**下一**随机航点：新点由 `_random_point_in_disk` 落在当前锚点圆内；另做与上一目标分离、勿近反向出射等筛选
## **参数**：`finished_wp` — 本段巡航目标（即将离开的点）
func _pick_next_waypoint_distinct(finished_wp: Vector2) -> Vector2:
	var center: Vector2 = _anchor_center()
	var r: float = maxf(1.0, _circle_radius)
	var min_sep: float = maxf(32.0, r * _MIN_NEW_WP_SEPARATION_FRAC)
	var min_sep2: float = min_sep * min_sep
	var min_leg2: float = 110.0
	var in_dir: Vector2 = _incoming_dir_before_brake
	if in_dir.length_squared() < 1e-6:
		in_dir = Vector2.RIGHT
	in_dir = in_dir.normalized()
	var best_relaxed: Vector2 = Vector2.ZERO
	var best_relaxed_score: float = -2.0
	for __attempt in range(18):
		var cand: Vector2 = _random_point_in_disk(center, r)
		if cand.distance_squared_to(finished_wp) < min_sep2:
			continue
		var leg: Vector2 = cand - global_position
		if leg.length_squared() < min_leg2:
			continue
		var out_dir: Vector2 = leg.normalized()
		var forwardness: float = out_dir.dot(in_dir)
		if forwardness >= _MIN_OUT_VS_INCOMING_DOT:
			return cand
		if forwardness > best_relaxed_score:
			best_relaxed_score = forwardness
			best_relaxed = cand
	if best_relaxed_score > -1.5:
		return best_relaxed
	return _random_point_in_disk(center, r)


## 生命周期结束：入 Spawner 全局池以复用；池满则真正 `queue_free`（`_exit_tree` 统一注销并补发队列）
func _retire() -> void:
	if _retire_deferred_pending:
		return
	_retire_deferred_pending = true
	call_deferred("_retire_deferred_impl")


## 空闲帧再离树入池或销毁，避免在 **`CombatHitbox2D`** 的 physics 重叠回调内同步 **`remove_child`** 子 **`Area2D`**
func _retire_deferred_impl() -> void:
	_retire_deferred_pending = false
	if not is_instance_valid(self):
		return
	if _volley_spawner_script.return_waypoint_volley_to_pool(self):
		return
	queue_free()


func _set_rotation_from_vel() -> void:
	## 根节点朝向与合成速度一致
	if _vel.length_squared() > 1e-6:
		rotation = _vel.angle()
	elif _heading.length_squared() > 1e-6:
		rotation = _heading.angle()


## 由 `_heading` 与 `_speed` 写回 `_vel`，保证全阶段速度方向一致
func _sync_vel_from_heading_speed() -> void:
	if _heading.length_squared() < 1e-10:
		_heading = Vector2.RIGHT
	else:
		_heading = _heading.normalized()
	_vel = _heading * _speed


## 将单位方向 `from_dir` 沿最短角转向 `to_dir`，单步转角不超过 `max_angle_rad`（弧度）；用于巡航/转向/加速段，避免速度空间直线插值造成「折线弹道」。
func _steer_dir_shortest(from_dir: Vector2, to_dir: Vector2, max_angle_rad: float) -> Vector2:
	if max_angle_rad <= 0.0:
		return from_dir.normalized() if from_dir.length_squared() > 1e-10 else Vector2.RIGHT
	if to_dir.length_squared() < 1e-10:
		return from_dir.normalized() if from_dir.length_squared() > 1e-10 else Vector2.RIGHT
	if from_dir.length_squared() < 1e-10:
		return to_dir.normalized()
	var a: Vector2 = from_dir.normalized()
	var b: Vector2 = to_dir.normalized()
	var cross: float = a.x * b.y - a.y * b.x
	var dotv: float = a.dot(b)
	var angle_between: float = atan2(cross, dotv)
	var step: float = clampf(angle_between, -max_angle_rad, max_angle_rad)
	return a.rotated(step)


## 在命中点实例化表现表 **`hit_feedback_vfx_scene`**（绑定表现槽时）
func _spawn_volley_hit_feedback_at(world_pos: Vector2) -> void:
	if not _bind_presentation_slots:
		return
	var ps: PackedScene = GameConfig.COMBAT_PRESENTATION.hit_feedback_vfx_scene
	if ps == null:
		return
	var p := get_parent()
	if p == null:
		return
	var inst: Node = ps.instantiate()
	inst.global_position = world_pos
	p.call_deferred("add_child", inst)


## 航点弹命中音效：命令注入优先，再回落 `PlayShapeCatalog` 外层默认
func _play_hit_sfx() -> void:
	var cat: PlayShapeCatalog = GameConfig.PLAY_SHAPE_CATALOG as PlayShapeCatalog
	var stream: AudioStream = null
	var default_hit_first: AudioStream = cat.default_hit_sfx_first if cat != null else null
	var default_hit_pierce: AudioStream = cat.default_hit_sfx_pierce if cat != null else null
	var hit_primary: AudioStream = _cmd_hit_sfx_first if _cmd_hit_sfx_first != null else default_hit_first
	if _bind_presentation_slots:
		if _hits_done == 1:
			stream = hit_primary
		elif _cmd_hit_sfx_reroute != null:
			stream = _cmd_hit_sfx_reroute
		else:
			var ph: AudioStream = _cmd_hit_sfx_pierce
			stream = ph if ph != null else (hit_primary if hit_primary != null else default_hit_pierce)
	else:
		if _hits_done == 1:
			stream = default_hit_first
		else:
			stream = default_hit_pierce if default_hit_pierce != null else default_hit_first
	if stream == null:
		return
	var ap := AudioStreamPlayer2D.new()
	ap.stream = stream.duplicate(true) as AudioStream
	ap.global_position = global_position
	ap.finished.connect(ap.queue_free)
	call_deferred("_deferred_attach_hit_sfx_player", ap)


## 与 **`Projectile`** 一致：单次延迟内 **`add_child` → `play()`**；挂到 **`get_parent()`** 避免弹体 **`queue_free`** 时拆掉播放器导致无声
func _deferred_attach_hit_sfx_player(ap: AudioStreamPlayer2D) -> void:
	if not is_instance_valid(ap):
		return
	var holder: Node = get_parent()
	if holder == null or not is_instance_valid(holder):
		ap.queue_free()
		return
	holder.add_child(ap)
	ap.play()


func _create_fallback_texture() -> Texture2D:
	var sz := 28
	var half := float(sz) * 0.5
	var image := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var body_r: float = 11.0
	for i in range(sz):
		for j in range(sz):
			var dx := float(i) - half
			var dy := float(j) - half
			var dist := sqrt(dx * dx + dy * dy)
			if dist <= body_r:
				var alpha := 1.0 - dist / maxf(body_r, 0.001)
				image.set_pixel(i, j, Color(1, 0.85, 0.25) * alpha)
	return ImageTexture.create_from_image(image)
