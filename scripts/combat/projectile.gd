class_name Projectile
extends Node2D
## 飞行速度（像素/秒）
@export var speed: float = 600.0
## 命中伤害
@export var damage: int = 10
## 弹体绘制颜色
@export var color: Color = Color(1, 0.8, 0.2)

@export_group("命中表现")
## 首段命中音效；**`null`** 时回落 **`PlayShapeCatalog.default_hit_sfx_first`**
@export var hit_sfx_first: AudioStream
## 穿透后续命中；**`null`** 时回落 **`PlayShapeCatalog.default_hit_sfx_pierce`**（再回落首击）
@export var hit_sfx_pierce: AudioStream
## 链式穿透第二段起优先；**`null`** 则走穿透音分支（与数值表航点换向音语义并列，由预制配置）
@export var hit_sfx_reroute: AudioStream
## 命中点受击反馈预制；**`null`** 且绑定表现槽时回落读 **`COMBAT_PRESENTATION.hit_feedback_vfx_scene`**
@export var hit_feedback_vfx_scene: PackedScene

## 要追击的目标节点
var target: Node2D
## 无敌对 `primary` 时沿该向直线飞行（世界空间，非零则启用直线模式，与 `enemy_manager_for_straight` 配合可近距命中）
var straight_aim_direction: Vector2 = Vector2.ZERO
## 直线模式时用于与敌重叠判定；null 则仅超时销毁
var enemy_manager_for_straight: EnemyManager = null
## 追击弹「贴脸」超时等逻辑仍参考的像素量级；**物理命中**以 **`CombatHitbox2D.hit_collision_shape`**（**`NodePath`**，常指向兄弟 **`HitShape`**）解析出的 **`CollisionShape2D`** 为准，缺省则 **`CombatHitbox2D`** 脚本内回退圆（与 38 对齐量级）
const _HOMING_HIT_DISTANCE: float = 38.0
## 程序化弹体纹理边长（像素）；原 16，默认略调大
const _PROJECTILE_TEX_SIZE: int = 28
## 弹体实心区外缘半径（像素），与 `_PROJECTILE_TEX_SIZE` 中心对齐
const _PROJECTILE_TEX_BODY_RADIUS: float = 11.0
## 为真时 `_process` 走直线分支，不依赖 `target` 有效
var _straight_mode: bool = false
## 飞行方向（直线段）
var start_direction: Vector2 = Vector2.ZERO
## steering 模式下当前速度方向（单位向量）
var _velocity_dir: Vector2 = Vector2.RIGHT
## 发射时全局位置备份
var start_pos: Vector2
## 已飞行秒数（超时强制命中）
var travel_time: float = 0.0
## 穿透：本弹允许的总命中次数 = `1 + p_pierce_extra_after_first`
var _total_hits_allowed: int = 1
## 已完成命中次数（用于音效分支）
var _hits_done: int = 0
## 已命中过的敌对，链式索敌时排除
var _pierce_exclude: Array = []
## 穿透链扫描用；与直线模式共用同一 `EnemyManager` 引用
var _enemy_manager_for_pierce: EnemyManager = null
## 为真时走 **`COMBAT_PRESENTATION` / `COMBAT_MECHANICS`** 的并行弹道表现与击退档（回落弹道为 false）
var _bind_presentation_slots: bool = false
## 为真且绑定表现槽：并行**主槽**预制与主槽发射音语义对齐；为假则**副槽**
var _use_primary_parallel_scene: bool = false
## 为真且第二段命中起：优先播预制体上 **`hit_sfx_reroute`**（与航点换向链式音分支共用开关）
var _prefer_reroute_hit_after_first: bool = false
## 对子/三条 2：沿 `start_direction` 直线穿透多敌；为假时命中后弹射追最近下一敌
var _linear_pierce_mode: bool = false
## 命令注入：首击命中音
var _cmd_hit_sfx_first: AudioStream = null
## 命令注入：穿透段命中音
var _cmd_hit_sfx_pierce: AudioStream = null
## 命令注入：换向段命中音
var _cmd_hit_sfx_reroute: AudioStream = null
## 命中盒投递：伤害与来源（**`CombatHitbox2D`** 重叠 Hurtbox 时扣血；超时兜底见 **`_hit_target`**）
var _hit_delivery: CombatHitDelivery = CombatHitDelivery.new()


## 对敌对 **`Node2D`** 取瞄准/距离用世界点：**`CombatEnemy`** 用 **`Hurtbox`** 锚点，其余用节点原点
func _aim_point_for_target(t: Node2D) -> Vector2:
	if t == null or not is_instance_valid(t):
		return Vector2.ZERO
	if t is CombatEnemy:
		return (t as CombatEnemy).get_hurtbox_anchor_global()
	return t.global_position


@onready var sprite: Sprite2D = $Sprite
## 通用命中盒：**碰撞圆半径在 `.tscn` 内编辑**；此处仅配 **`GameConfig.GAME_GLOBAL`** 层掩码并启动监听
@onready var _combat_hitbox: Area2D = $CombatHitbox2D


## 由 `CombatEffectRunner` 多发弹道在 **`parent.add_child` 之前** 调用。
## **`p_pierce_extra_after_first`**：首次命中后还可再结算的**额外**敌人数（0=只打一敌）。
## **`p_bind_presentation_slots`**：是否绑定全局表现槽（预制体/命中音/击退并行档）；**同时为真**时投递 **`use_parallel_volley_knockback_profile`**
## **`p_prefer_reroute_hit_after_first`**：第二段命中起是否优先走预制体 **`hit_sfx_reroute`**
## **`p_linear_pierce`**：直线穿透多敌；为假时命中后改为追下一目标
## **`p_use_primary_parallel_scene`**：绑定表现槽时是否选用并行**主槽**预制与主槽发射音链
## **`p_hit_knockback_speed`**：每次调用均写入 **`CombatHitDelivery.knockback_speed`**（含 **`-1`**），避免对象池复用上一次的显式值残留
func configure_from_volley(
	p_target: Node2D,
	p_forward: Vector2,
	p_enemy_manager: EnemyManager,
	p_damage: int,
	p_pierce_extra_after_first: int = 0,
	p_bind_presentation_slots: bool = false,
	p_prefer_reroute_hit_after_first: bool = false,
	p_linear_pierce: bool = false,
	p_use_primary_parallel_scene: bool = false,
	p_hit_knockback_speed: float = -1.0,
	p_hit_sfx_first: AudioStream = null,
	p_hit_sfx_pierce: AudioStream = null,
	p_hit_sfx_reroute: AudioStream = null
) -> void:
	damage = p_damage
	_hit_delivery.damage = maxi(0, p_damage)
	_hit_delivery.source = self
	_hit_delivery.knockback_speed = p_hit_knockback_speed
	target = p_target
	_bind_presentation_slots = p_bind_presentation_slots
	_use_primary_parallel_scene = p_use_primary_parallel_scene
	_prefer_reroute_hit_after_first = p_prefer_reroute_hit_after_first
	_linear_pierce_mode = p_linear_pierce
	_cmd_hit_sfx_first = p_hit_sfx_first
	_cmd_hit_sfx_pierce = p_hit_sfx_pierce
	_cmd_hit_sfx_reroute = p_hit_sfx_reroute
	_total_hits_allowed = maxi(1, 1 + maxi(0, p_pierce_extra_after_first))
	_hits_done = 0
	_pierce_exclude.clear()
	if _total_hits_allowed > 1 and p_enemy_manager != null:
		_enemy_manager_for_pierce = p_enemy_manager
	if p_target == null:
		straight_aim_direction = p_forward
		enemy_manager_for_straight = p_enemy_manager
	else:
		straight_aim_direction = Vector2.ZERO
		enemy_manager_for_straight = null


## 精灵无贴图时生成程序化圆点；美术外观以并行弹道 **`.tscn`** 内嵌为准
func _ready() -> void:
	if sprite.texture == null:
		sprite.texture = _create_projectile_texture()
	start_pos = global_position
	if is_instance_valid(target):
		_straight_mode = false
		var to_t: Vector2 = _aim_point_for_target(target) - global_position
		if to_t.length_squared() > 1e-6:
			start_direction = to_t.normalized()
			_velocity_dir = start_direction
		else:
			start_direction = Vector2.RIGHT
			_velocity_dir = start_direction
	elif straight_aim_direction.length_squared() > 1e-6:
		_straight_mode = true
		start_direction = straight_aim_direction.normalized()
		if start_direction.length_squared() < 1e-6:
			start_direction = Vector2.RIGHT
		_velocity_dir = start_direction
	else:
		call_deferred("_queue_free_after_physics")
		return
	## 推迟到 **`CombatHitbox2D`** 的 **`call_deferred`** 收编形状之后，避免 **`apply_circle_radius_px` / `start_monitoring`** 对着空子级
	call_deferred("_setup_combat_hitbox")


## 配置子节点 **`CombatHitbox2D`**：`mask` 对齐 **`combat_hurtbox_collision_layer`**；写入投递并监听重叠
func _setup_combat_hitbox() -> void:
	if _combat_hitbox == null:
		return
	var gg := GameConfig.GAME_GLOBAL
	if _combat_hitbox.has_method("set_hit_delivery"):
		_combat_hitbox.call("set_hit_delivery", _hit_delivery)
	if _combat_hitbox.has_method("configure_collision_layers"):
		_combat_hitbox.call(
			"configure_collision_layers",
			gg.combat_hitbox_collision_layer,
			gg.combat_hurtbox_collision_layer
		)
	if _combat_hitbox.has_signal("hit_body") and not _combat_hitbox.hit_body.is_connected(_on_combat_hitbox_hit_body):
		_combat_hitbox.hit_body.connect(_on_combat_hitbox_hit_body)
	if _combat_hitbox.has_method("start_monitoring"):
		_combat_hitbox.call("start_monitoring")


## 命中盒回调：伤害已由 Hitbox→Hurtbox 投递；此处仅做锁定校验、穿透计数与表现
func _on_combat_hitbox_hit_body(body: Node2D, hit_pos: Vector2) -> void:
	var e := body as CombatEnemy
	if e == null or e.is_dead():
		return
	if _hits_done >= _total_hits_allowed:
		return
	if _pierce_exclude.has(e):
		return
	if not _straight_mode:
		if not is_instance_valid(target) or e != target:
			return
	target = e
	_advance_after_hit(hit_pos, e)


## 追击目标或直线移动；直线模式可扫 `enemy_manager_for_straight` 子敌近距命中
func _process(delta: float) -> void:
	if _straight_mode:
		_process_straight(delta)
		return
	if not is_instance_valid(target):
		call_deferred("_queue_free_after_physics")
		return

	travel_time += delta
	var to_target: Vector2 = _aim_point_for_target(target) - global_position
	if travel_time > 2.0:
		_hit_target()
		return

	var direction: Vector2 = to_target.normalized()
	global_position += direction * speed * delta
	rotation = direction.angle()


## 直线匀速；命中改由子节点 **`CombatHitbox2D`** 的 **`area_entered`**（对 **`CombatHurtbox2D`**）驱动
func _process_straight(delta: float) -> void:
	travel_time += delta
	global_position += start_direction * speed * delta
	rotation = start_direction.angle()
	if travel_time > 2.0:
		call_deferred("_queue_free_after_physics")
		return


## 对目标结算伤害（超时等非 Hitbox 路径）：经 **`CombatHurtbox2D`** 投递；**`hit_world_pos`** 为飘字/反馈落点
func _hit_target(hit_world_pos: Vector2 = Vector2.ZERO) -> void:
	if target == null:
		call_deferred("_queue_free_after_physics")
		return
	var ce := target as CombatEnemy
	if ce == null:
		call_deferred("_queue_free_after_physics")
		return
	var fb_pos: Vector2 = hit_world_pos
	if fb_pos == Vector2.ZERO:
		fb_pos = ce.get_hurtbox_anchor_global()
	CombatHurtbox2D.deliver_to_enemy_best_effort(ce, _hit_delivery, fb_pos)
	_advance_after_hit(fb_pos, ce)


## 单次命中后：音效、受击预制、穿透链/直线切换或销毁（**不**再调用 `apply_damage`，物理命中已在 Hitbox 内投递）
func _advance_after_hit(fb_pos: Vector2, hit_enemy: CombatEnemy) -> void:
	_hits_done += 1
	_play_volley_hit_sfx()
	_spawn_hit_feedback_if_configured(fb_pos)
	_pierce_exclude.append(hit_enemy)

	if _hits_done >= _total_hits_allowed:
		call_deferred("_queue_free_after_physics")
		return

	if _enemy_manager_for_pierce == null:
		call_deferred("_queue_free_after_physics")
		return

	if _linear_pierce_mode:
		target = null
		_straight_mode = true
		enemy_manager_for_straight = _enemy_manager_for_pierce
		return

	var next_e: CombatEnemy = _find_next_pierce_target()
	if next_e == null:
		call_deferred("_queue_free_after_physics")
		return

	target = next_e
	_straight_mode = false
	travel_time = 0.0
	enemy_manager_for_straight = null
	straight_aim_direction = Vector2.ZERO
	start_direction = global_position.direction_to(_aim_point_for_target(target))


## 在 `_enemy_manager_for_pierce` 中取距当前弹体最近、未在 `_pierce_exclude` 的存活敌
func _find_next_pierce_target() -> CombatEnemy:
	var best_d2: float = INF
	var best_e: CombatEnemy = null
	for child in _enemy_manager_for_pierce.get_units_root().get_children():
		var e := child as CombatEnemy
		if e == null or e.is_dead():
			continue
		if _pierce_exclude.has(e):
			continue
		var d2: float = global_position.distance_squared_to(e.get_hurtbox_anchor_global())
		if d2 < best_d2:
			best_d2 = d2
			best_e = e
	return best_e


## 按命中次序播放命中音效（可空）；依赖当前 **`_hits_done`**（已在调用处自增）
## **语义**：命令注入音效优先，其次预制体槽，再回落表现表默认解析。
func _play_volley_hit_sfx() -> void:
	var stream: AudioStream = null
	var cat: PlayShapeCatalog = GameConfig.PLAY_SHAPE_CATALOG as PlayShapeCatalog
	var default_hit_first: AudioStream = cat.default_hit_sfx_first if cat != null else null
	var default_hit_pierce: AudioStream = cat.default_hit_sfx_pierce if cat != null else null
	## 中文：首击 — 命令注入优先，再预制体槽，否则表现表默认
	if _hits_done == 1:
		if _cmd_hit_sfx_first != null:
			stream = _cmd_hit_sfx_first
		elif hit_sfx_first != null:
			stream = hit_sfx_first
		else:
			stream = default_hit_first
	## 中文：换向链 — 开关为真时优先命令注入 reroute，再预制体 reroute
	elif _prefer_reroute_hit_after_first and (_cmd_hit_sfx_reroute != null or hit_sfx_reroute != null):
		stream = _cmd_hit_sfx_reroute if _cmd_hit_sfx_reroute != null else hit_sfx_reroute
	## 中文：穿透段 — 预制 **`hit_sfx_pierce`** 或并行专属穿透音或表现表默认穿透音
	else:
		if _cmd_hit_sfx_pierce != null:
			stream = _cmd_hit_sfx_pierce
		elif hit_sfx_pierce != null:
			stream = hit_sfx_pierce
		else:
			stream = default_hit_pierce if default_hit_pierce != null else default_hit_first
	if stream == null:
		return
	## 多段穿透会在短时内多次播同一配置流；**同一 `AudioStream` 资源**挂到多个 Player 会**共享播放进度**，故每路 **`duplicate(true)`**
	## **`add_child` 与 `play` 不得分两 object 入队**：多弹同帧时 `ap.play()` 可能先于入树执行 → 偶发无声；改为单次 **`call_deferred`** 内先挂子再 **`play()`**
	var ap := AudioStreamPlayer2D.new()
	ap.stream = stream.duplicate(true) as AudioStream
	ap.global_position = global_position
	ap.finished.connect(ap.queue_free)
	call_deferred("_deferred_attach_hit_sfx_player", ap)


## 在 **`_physics_process` / 命中信号栈**外完成挂子与播放，且保证 **`add_child` → `play()`** 顺序
## 音效须挂在 **`get_parent()`**（战场层）而非本弹体：否则同一帧内紧随其后的 **`queue_free`** 会拆掉子 **`AudioStreamPlayer2D`**，密集命中时表现为偶发无声
func _deferred_attach_hit_sfx_player(ap: AudioStreamPlayer2D) -> void:
	if not is_instance_valid(ap):
		return
	var holder: Node = get_parent()
	if holder == null or not is_instance_valid(holder):
		ap.queue_free()
		return
	holder.add_child(ap)
	ap.play()


## 在敌受击世界坐标生成打击反馈预制；**`hit_feedback_vfx_scene`** 优先，空且绑定表现槽时读 **`COMBAT_PRESENTATION.hit_feedback_vfx_scene`**。
func _spawn_hit_feedback_if_configured(hit_world_pos: Vector2) -> void:
	var ps: PackedScene = null
	if hit_feedback_vfx_scene != null:
		ps = hit_feedback_vfx_scene
	elif _bind_presentation_slots:
		ps = GameConfig.COMBAT_PRESENTATION.hit_feedback_vfx_scene
	else:
		return
	if ps == null:
		return
	var p := get_parent()
	if p == null:
		return
	var inst: Node = ps.instantiate()
	inst.global_position = hit_world_pos
	p.call_deferred("add_child", inst)


## 空闲帧再销毁本节点：避免在 **`CombatHitbox2D`** 的 **`area_entered`**（physics）栈内同步拆掉子 **`Area2D`** 触发 `collision_object_2d` 警告
func _queue_free_after_physics() -> void:
	if is_instance_valid(self) and not is_queued_for_deletion():
		queue_free()


## 生成正方形半透明圆纹理（边长见 `_PROJECTILE_TEX_SIZE`）
func _create_projectile_texture() -> Texture2D:
	var sz := _PROJECTILE_TEX_SIZE
	var half := float(sz) * 0.5
	var image := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)

	for i in range(sz):
		for j in range(sz):
			var dx := float(i) - half
			var dy := float(j) - half
			var dist := sqrt(dx * dx + dy * dy)
			if dist <= _PROJECTILE_TEX_BODY_RADIUS:
				var alpha := 1.0 - dist / maxf(_PROJECTILE_TEX_BODY_RADIUS, 0.001)
				image.set_pixel(i, j, color * alpha)

	var texture := ImageTexture.create_from_image(image)
	return texture
