class_name Projectile
extends Node2D
## 飞向目标的简单弹道：命中扣血、拖尾线（伤害飘字由受击方经 GameToolSingleton 统一显示）

## 飞行速度（像素/秒）
@export var speed: float = 600.0
## 命中伤害
@export var damage: int = 10
## 拖尾保留点数个数
@export var trail_length: int = 8
## 弹体绘制颜色
@export var color: Color = Color(1, 0.8, 0.2)

## 要追击的目标节点
var target: Node2D
## 无敌对 `primary` 时沿该向直线飞行（世界空间，非零则启用直线模式，与 `enemy_manager_for_straight` 配合可近距命中）
var straight_aim_direction: Vector2 = Vector2.ZERO
## 直线模式时用于与敌重叠判定；null 则仅超时销毁
var enemy_manager_for_straight: EnemyManager = null
## 直线弹近敌判定半径（像素），与点数 8 直线弹同量级
const _STRAIGHT_HIT_RADIUS: float = 22.0
## 为真时 `_process` 走直线分支，不依赖 `target` 有效
var _straight_mode: bool = false
## 飞行方向
var start_direction: Vector2 = Vector2.ZERO
## 发射时全局位置备份
var start_pos: Vector2
## 已飞行秒数（超时强制命中）
var travel_time: float = 0.0
## Line2D 用的历史点
var _trail_points: PackedVector2Array = PackedVector2Array()

@onready var sprite: Sprite2D = $Sprite
@onready var trail: Line2D = $Trail


## 由 `CombatEffectRunner` 多发弹道在 **`parent.add_child` 之前** 调用，写入 `_ready` 会读的字段（避免跨脚本 `as Projectile` / 字符串 `set`）
## `p_target`：追击目标，可为 null 则走直线模式；`p_forward`：无目标时的世界空间朝向；`p_enemy_manager`：直线模式近敌扫描；`p_damage`：命中伤害
func configure_from_volley(
	p_target: Node2D,
	p_forward: Vector2,
	p_enemy_manager: EnemyManager,
	p_damage: int
) -> void:
	damage = p_damage
	target = p_target
	if p_target == null:
		straight_aim_direction = p_forward
		enemy_manager_for_straight = p_enemy_manager
	else:
		straight_aim_direction = Vector2.ZERO
		enemy_manager_for_straight = null


## 生成圆形纹理并记录起点；有有效 `target` 则追击，否则在 `straight_aim_direction` 非零时进入直线模式
func _ready() -> void:
	sprite.texture = _create_projectile_texture()
	start_pos = global_position
	if is_instance_valid(target):
		_straight_mode = false
		start_direction = global_position.direction_to(target.global_position)
	elif straight_aim_direction.length_squared() > 1e-6:
		_straight_mode = true
		start_direction = straight_aim_direction.normalized()
		if start_direction.length_squared() < 1e-6:
			start_direction = Vector2.RIGHT
	else:
		queue_free()
		return
	_trail_points.append(global_position)


## 追击目标或直线移动；直线模式可扫 `enemy_manager_for_straight` 子敌近距命中
func _process(delta: float) -> void:
	if _straight_mode:
		_process_straight(delta)
		return
	if not is_instance_valid(target):
		queue_free()
		return

	travel_time += delta
	var to_target := target.global_position - global_position
	var distance := to_target.length()

	if distance < 30.0 or travel_time > 2.0:
		_hit_target()
		return
	var direction := to_target.normalized()
	global_position += direction * speed * delta
	rotation = direction.angle()

	_update_trail()


## 直线匀速；与任一存活敌距离小于 `_STRAIGHT_HIT_RADIUS` 时对该敌结算伤害并销毁
func _process_straight(delta: float) -> void:
	travel_time += delta
	global_position += start_direction * speed * delta
	rotation = start_direction.angle()
	if enemy_manager_for_straight != null:
		var hit: CombatEnemy = _first_enemy_in_hit_radius()
		if hit != null:
			target = hit
			_hit_target()
			return
	if travel_time > 2.0:
		queue_free()
		return
	_update_trail()


## 在直线弹当前位置找第一个进入命中半径的存活敌
func _first_enemy_in_hit_radius() -> CombatEnemy:
	var r2: float = _STRAIGHT_HIT_RADIUS * _STRAIGHT_HIT_RADIUS
	for child in enemy_manager_for_straight.get_children():
		var e := child as CombatEnemy
		if e == null or e.is_dead():
			continue
		if global_position.distance_squared_to(e.global_position) <= r2:
			return e
	return null


## 对目标 apply_damage 后销毁自身（飘字在 apply_damage 内由 GameToolSingleton 处理）
func _hit_target() -> void:
	if target.has_method("apply_damage"):
		target.apply_damage(damage)
	queue_free()


## 维护拖尾点队列长度
func _update_trail() -> void:
	_trail_points.append(global_position)
	if _trail_points.size() > trail_length:
		_trail_points.remove_at(0)
	trail.points = _trail_points


## 生成 16x16 半透明圆纹理
func _create_projectile_texture() -> Texture2D:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)

	for i in range(16):
		for j in range(16):
			var dx := i - 8
			var dy := j - 8
			var dist := sqrt(dx * dx + dy * dy)
			if dist <= 7:
				var alpha := 1.0 - dist / 7.0
				image.set_pixel(i, j, color * alpha)

	var texture := ImageTexture.create_from_image(image)
	return texture
