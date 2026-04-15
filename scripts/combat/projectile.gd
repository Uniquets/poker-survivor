@tool
extends Node2D
## 飞向目标的简单弹道：命中扣血、拖尾线与飘字

## 飞行速度（像素/秒）
@export var speed: float = 600.0
## 命中伤害
@export var damage: int = 10
## 拖尾保留点数个数
@export var trail_length: int = 8
## 弹体绘制颜色
@export var color: Color = Color(1, 0.8, 0.2)

## 飘字字号
@export var hit_text_font_size: int = 24
## 飘字颜色
@export var hit_text_color: Color = Color(1, 0.3, 0.3)
## 飘字存活时间（秒）
@export var hit_text_duration: float = 2.0
## 飘字向上位移（像素）
@export var hit_text_move_distance: float = 40.0

## 要追击的目标节点
var target: Node2D
## 发射时全局位置备份
var start_pos: Vector2
## 已飞行秒数（超时强制命中）
var travel_time: float = 0.0
## Line2D 用的历史点
var _trail_points: PackedVector2Array = PackedVector2Array()

@onready var sprite: Sprite2D = $Sprite
@onready var trail: Line2D = $Trail


## 生成圆形纹理并记录起点
func _ready() -> void:
	sprite.texture = _create_projectile_texture()
	start_pos = global_position
	_trail_points.append(global_position)


## 朝目标移动；近距或超时则命中
func _process(delta: float) -> void:
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


## 对目标 apply_damage 并播放飘字后销毁自身
func _hit_target() -> void:
	if target.has_method("apply_damage"):
		target.apply_damage(damage)
		_create_hit_effect()
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


## 在父节点下创建飘字 Node2D 与 Tween 动画
func _create_hit_effect() -> void:
	var effect := Node2D.new()
	effect.global_position = global_position
	get_parent().add_child(effect)
	
	var label := Label.new()
	label.text = str(damage)
	label.add_theme_color_override("font_color", hit_text_color)
	label.add_theme_font_size_override("font_size", hit_text_font_size)
	effect.add_child(label)
	
	var tween := effect.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(effect, "global_position", effect.global_position + Vector2(0, -hit_text_move_distance), hit_text_duration)
	tween.parallel().tween_property(label, "modulate:a", 0.0, hit_text_duration)
	tween.finished.connect(effect.queue_free)
