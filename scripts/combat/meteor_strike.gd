extends Node2D
## 天外陨石单体：负责下落动画、命中结算、对子二段爆炸、三条椭圆火焰与四条包围区域火焰（首颗承载）。

## 敌人管理器（用于遍历敌人并投递伤害）
var _enemy_manager: EnemyManager = null
## 命中关键帧伤害
var _impact_damage: int = 0
## 陨石下落阶段时长（秒）
var _fall_duration_sec: float = 0.6
## 陨石总存在时长（秒）
var _lifetime_sec: float = 5.0
## 陨石整体缩放倍率
var _scale_mul: float = 1.0
## 是否启用对子二段爆炸
var _enable_end_explosion: bool = false
## 对子二段爆炸伤害
var _end_explosion_damage: int = 0
## 是否启用三条椭圆火焰覆盖区
var _enable_ellipse_fire: bool = false
## 三条椭圆火焰每秒伤害
var _ellipse_fire_dps: int = 0
## 三条椭圆火焰跳伤间隔
var _ellipse_fire_tick_sec: float = 0.45
## 是否作为四条包围火焰承载体（仅首颗为 true）
var _enable_polygon_fire_owner: bool = false
## 四条包围火焰凸包点（世界坐标）
var _polygon_world_points: PackedVector2Array = PackedVector2Array()
## 四条包围火焰每秒伤害
var _polygon_fire_dps: int = 0
## 四条包围火焰跳伤间隔
var _polygon_fire_tick_sec: float = 0.45
## 陨石已存在时间（秒）
var _elapsed: float = 0.0
## 三条火焰下次跳伤倒计时
var _ellipse_fire_until_tick: float = 0.0
## 四条火焰下次跳伤倒计时
var _polygon_fire_until_tick: float = 0.0
## 命中是否已触发（防止重复结算）
var _impact_done: bool = false
## 爆炸是否已触发（防止重复结算）
var _explosion_done: bool = false

@onready var _anim: AnimationPlayer = $AnimationPlayer
## 陨石序列帧（SpriteFrames：fall → fall_down）
@onready var _meteor_visual: AnimatedSprite2D = $MeteorVisual
@onready var _impact_area: Area2D = $ImpactArea
@onready var _impact_shape: CollisionShape2D = $ImpactArea/CollisionShape2D
@onready var _explosion_area: Area2D = $ExplosionArea
@onready var _explosion_shape: CollisionShape2D = $ExplosionArea/CollisionShape2D
@onready var _ellipse_fire_area: Area2D = $EllipseFireArea
@onready var _ellipse_fire_shape: CollisionShape2D = $EllipseFireArea/CollisionShape2D
@onready var _polygon_fire_area: Area2D = $PolygonFireArea
@onready var _polygon_fire_shape: CollisionPolygon2D = $PolygonFireArea/CollisionPolygon2D


## 外部注入陨石参数；由 CombatEffectRunner 实例化后调用。
func setup_meteor(
	enemy_manager: EnemyManager,
	impact_damage: int,
	fall_duration_sec: float,
	lifetime_sec: float,
	scale_mul: float,
	enable_end_explosion: bool,
	end_explosion_damage: int,
	enable_ellipse_fire: bool,
	ellipse_fire_dps: int,
	ellipse_fire_tick_sec: float,
	enable_polygon_fire_owner: bool,
	polygon_world_points: PackedVector2Array,
	polygon_fire_dps: int,
	polygon_fire_tick_sec: float
) -> void:
	_enemy_manager = enemy_manager
	_impact_damage = maxi(0, impact_damage)
	_fall_duration_sec = maxf(0.05, fall_duration_sec)
	_lifetime_sec = maxf(_fall_duration_sec, lifetime_sec)
	_scale_mul = maxf(0.05, scale_mul)
	_enable_end_explosion = enable_end_explosion
	_end_explosion_damage = maxi(0, end_explosion_damage)
	_enable_ellipse_fire = enable_ellipse_fire
	_ellipse_fire_dps = maxi(0, ellipse_fire_dps)
	_ellipse_fire_tick_sec = maxf(0.05, ellipse_fire_tick_sec)
	_enable_polygon_fire_owner = enable_polygon_fire_owner
	_polygon_world_points = polygon_world_points
	_polygon_fire_dps = maxi(0, polygon_fire_dps)
	_polygon_fire_tick_sec = maxf(0.05, polygon_fire_tick_sec)


## 首帧初始化：应用缩放、设置碰撞半径、启动动画速度、打开必要火焰区域。
func _ready() -> void:
	_meteor_visual.scale = Vector2.ONE * _scale_mul
	_apply_scaled_circle_radius(_impact_shape, 44.0 * _scale_mul)
	_apply_scaled_circle_radius(_explosion_shape, 68.0 * _scale_mul)
	_apply_scaled_ellipse_radius(_ellipse_fire_shape, Vector2(64.0, 44.0) * _scale_mul)
	if _enable_polygon_fire_owner and _polygon_world_points.size() >= 3:
		_setup_polygon_fire_shape()
	else:
		_polygon_fire_area.monitoring = false
	_ellipse_fire_area.monitoring = _enable_ellipse_fire
	_ellipse_fire_until_tick = _ellipse_fire_tick_sec
	_polygon_fire_until_tick = _polygon_fire_tick_sec
	# 中文：fall_duration_sec 必须真实驱动动画时序；用 speed_scale 将资源时间轴（秒）映射到配置时长。
	var base_len: float = maxf(0.01, _anim.get_animation("fall").length)
	_anim.speed_scale = base_len / _fall_duration_sec
	# 中文：AnimatedSprite2D 需显式 play，仅靠 AnimationPlayer 改 `animation` 属性在部分情况下不会推进帧。
	if _meteor_visual.sprite_frames != null and _meteor_visual.sprite_frames.has_animation("fall"):
		_meteor_visual.play("fall")
		# 中文：落地动画播完后切换到 down_over 常驻循环。
		_meteor_visual.animation_finished.connect(_on_meteor_visual_animation_finished)
	_anim.play("fall")
	# 中文：资源时间轴上命中/切二段动画在 t=0.72；墙钟时间 = 0.72 / speed_scale = 0.72 * fall_dur / base_len（与 0.72*fall_dur 不同）。
	var t_at_key_072: float = 0.72 * _fall_duration_sec / base_len
	var impact_timer: SceneTreeTimer = get_tree().create_timer(t_at_key_072)
	impact_timer.timeout.connect(_on_meteor_timeline_072)


## 按生命周期驱动持续区域跳伤与结束逻辑。
func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _lifetime_sec:
		# 中文：无对子二段爆炸时直接渐隐退出；有爆炸时在退出前触发一次爆炸。
		if _enable_end_explosion and not _explosion_done:
			_trigger_end_explosion_once()
		_play_fade_and_free()
		return
	if _enable_ellipse_fire:
		_ellipse_fire_until_tick -= delta
		if _ellipse_fire_until_tick <= 0.0:
			_ellipse_fire_until_tick = _ellipse_fire_tick_sec
			_apply_area_dot(_ellipse_fire_area, _ellipse_fire_dps)
	if _enable_polygon_fire_owner and _polygon_world_points.size() >= 3:
		_polygon_fire_until_tick -= delta
		if _polygon_fire_until_tick <= 0.0:
			_polygon_fire_until_tick = _polygon_fire_tick_sec
			_apply_polygon_dot(_polygon_fire_dps)


## 与动画资源 t=0.72 对齐的墙钟时刻：切换 fall_down 并触发命中（与定时器一致，避免仅轨道改属性不播帧）。
func _on_meteor_timeline_072() -> void:
	if _meteor_visual.sprite_frames != null and _meteor_visual.sprite_frames.has_animation("fall_down"):
		_meteor_visual.play("fall_down")
	on_impact_frame_event()


## 序列帧播放完成回调：fall_down 播完后切换到 down_over 循环驻留。
func _on_meteor_visual_animation_finished() -> void:
	if _meteor_visual == null:
		return
	# 中文：仅 fall_down 结束后切驻留动画，避免其它动画结束时误切。
	if _meteor_visual.animation == &"fall_down":
		if _meteor_visual.sprite_frames != null and _meteor_visual.sprite_frames.has_animation("down_over"):
			_meteor_visual.play("down_over")


## 动画事件回调：由 AnimationPlayer 调用轨道在命中关键帧触发。
func on_impact_frame_event() -> void:
	if _impact_done:
		return
	_impact_done = true
	_play_impact_hit_sfx()
	_apply_area_damage_once(_impact_area, _impact_damage)


## 将圆形碰撞半径写入场景内既有形状，保持所见即所得。
func _apply_scaled_circle_radius(shape_node: CollisionShape2D, radius_px: float) -> void:
	if shape_node == null:
		return
	var circle: CircleShape2D = shape_node.shape as CircleShape2D
	if circle == null:
		return
	circle.radius = maxf(2.0, radius_px)


## 用胶囊形近似椭圆覆盖区（场景内固定节点，仅改半径与缩放）。
func _apply_scaled_ellipse_radius(shape_node: CollisionShape2D, size_xy: Vector2) -> void:
	if shape_node == null:
		return
	var capsule: CapsuleShape2D = shape_node.shape as CapsuleShape2D
	if capsule == null:
		return
	capsule.radius = maxf(2.0, minf(size_xy.x, size_xy.y) * 0.5)
	capsule.height = maxf(capsule.radius * 2.0 + 2.0, maxf(size_xy.x, size_xy.y))


## 配置四条包围火焰多边形：世界点转为本地点写入场景预置的 CollisionPolygon2D。
func _setup_polygon_fire_shape() -> void:
	var local := PackedVector2Array()
	for p in _polygon_world_points:
		local.append(to_local(p))
	_polygon_fire_shape.polygon = local
	_polygon_fire_area.monitoring = true


## 对 Area2D 重叠敌人结算一次即时伤害（用于命中/爆炸）。
func _apply_area_damage_once(area: Area2D, damage: int) -> void:
	if _enemy_manager == null or area == null:
		return
	var per_hit: int = maxi(0, damage)
	if per_hit <= 0:
		return
	for child in _enemy_manager.get_units_root().get_children():
		var enemy: CombatEnemy = child as CombatEnemy
		if enemy == null or enemy.is_dead():
			continue
		var enemy_pos: Vector2 = enemy.get_hurtbox_anchor_global()
		if not _is_point_inside_area(enemy_pos, area):
			continue
		var hit := CombatHitDelivery.new()
		hit.source = self
		hit.damage = per_hit
		hit.knockback_speed = 0.0
		CombatHurtbox2D.deliver_to_enemy_best_effort(enemy, hit, enemy_pos)


func resolve_impact_hit_sfx() -> AudioStream:
	var cat: PlayShapeCatalog = GameConfig.PLAY_SHAPE_CATALOG as PlayShapeCatalog
	if cat == null:
		cat = load("res://config/card_shape_config.tres") as PlayShapeCatalog
	return cat.default_hit_sfx_first if cat != null else null


func _play_impact_hit_sfx() -> void:
	var stream: AudioStream = resolve_impact_hit_sfx()
	if stream == null:
		return
	var ap := AudioStreamPlayer2D.new()
	ap.stream = stream.duplicate(true) as AudioStream
	ap.global_position = global_position
	ap.finished.connect(ap.queue_free)
	call_deferred("_deferred_attach_impact_hit_sfx_player", ap)


func _deferred_attach_impact_hit_sfx_player(ap: AudioStreamPlayer2D) -> void:
	if not is_instance_valid(ap):
		return
	var holder: Node = get_parent()
	if holder == null or not is_instance_valid(holder):
		ap.queue_free()
		return
	holder.add_child(ap)
	ap.play()


## 对 Area2D 重叠敌人结算一次 DoT 跳伤（无击退）。
func _apply_area_dot(area: Area2D, dps: int) -> void:
	var per_tick: int = maxi(1, int(round(float(maxi(0, dps)) * _ellipse_fire_tick_sec)))
	_apply_area_damage_once(area, per_tick)


## 对四条包围多边形内敌人结算一次 DoT 跳伤（无击退）。
func _apply_polygon_dot(dps: int) -> void:
	if _enemy_manager == null:
		return
	if _polygon_world_points.size() < 3:
		return
	var per_tick: int = maxi(1, int(round(float(maxi(0, dps)) * _polygon_fire_tick_sec)))
	for child in _enemy_manager.get_units_root().get_children():
		var enemy: CombatEnemy = child as CombatEnemy
		if enemy == null or enemy.is_dead():
			continue
		var enemy_pos: Vector2 = enemy.get_hurtbox_anchor_global()
		if not Geometry2D.is_point_in_polygon(enemy_pos, _polygon_world_points):
			continue
		var hit := CombatHitDelivery.new()
		hit.source = self
		hit.damage = per_tick
		hit.knockback_speed = 0.0
		CombatHurtbox2D.deliver_to_enemy_best_effort(enemy, hit, enemy_pos)


## 对子二段爆炸触发一次（按场景爆炸区范围）。
func _trigger_end_explosion_once() -> void:
	if _explosion_done:
		return
	_explosion_done = true
	_apply_area_damage_once(_explosion_area, _end_explosion_damage)


## 播放渐隐并销毁节点。
func _play_fade_and_free() -> void:
	set_process(false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.finished.connect(queue_free)


## 判定世界点是否位于指定 Area2D 覆盖区内（按场景内形状近似）。
func _is_point_inside_area(world_pos: Vector2, area: Area2D) -> bool:
	if area == _impact_area:
		var r1: float = (_impact_shape.shape as CircleShape2D).radius
		return global_position.distance_to(world_pos) <= r1
	if area == _explosion_area:
		var r2: float = (_explosion_shape.shape as CircleShape2D).radius
		return global_position.distance_to(world_pos) <= r2
	if area == _ellipse_fire_area:
		var local: Vector2 = to_local(world_pos)
		var capsule: CapsuleShape2D = _ellipse_fire_shape.shape as CapsuleShape2D
		var half_h: float = maxf(0.01, capsule.height * 0.5)
		var rx: float = maxf(0.01, capsule.radius)
		var ry: float = maxf(0.01, half_h)
		var norm: float = (local.x * local.x) / (rx * rx) + (local.y * local.y) / (ry * ry)
		return norm <= 1.0
	return false
