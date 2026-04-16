extends Node
## Autoload **GameToolSingleton**：全局工具方法入口（世界坐标飘字等）；**无玩法判定**。各系统按需在此增加工具方法。

## 世界坐标系下挂工具生成节点（如飘字）的父节点；需要世界空间表现时由场景在 _ready 调用 bind_world_layer
var _world_layer: Node2D = null

## 飘字默认字号（像素）
const _FLOAT_FONT_SIZE: int = 24
## 飘字默认存活时间（秒）
const _FLOAT_DURATION: float = 2.0
## 飘字默认上移距离（像素）
const _FLOAT_MOVE_PIXELS: float = 40.0

## 伤害飘字颜色
const _FLOAT_COLOR_DAMAGE: Color = Color(1, 0.3, 0.3)
## 治疗飘字颜色
const _FLOAT_COLOR_HEAL: Color = Color(0.35, 0.95, 0.45)


## 注册世界空间工具节点的挂载点（与 Camera2D 同层变换）
func bind_world_layer(layer: Node2D) -> void:
	_world_layer = layer


## 世界空间伤害数字飘字（amount≤0 时不生成）
func world_damage_float(world_position: Vector2, amount: int, offset: Vector2 = Vector2.ZERO) -> void:
	if amount <= 0:
		return
	_world_float_spawn(world_position + offset, str(amount), _FLOAT_COLOR_DAMAGE, _FLOAT_FONT_SIZE, _FLOAT_DURATION, _FLOAT_MOVE_PIXELS)


## 世界空间治疗量飘字，文本带「+」前缀（amount≤0 时不生成）
func world_heal_float(world_position: Vector2, amount: int, offset: Vector2 = Vector2.ZERO) -> void:
	if amount <= 0:
		return
	_world_float_spawn(world_position + offset, "+%d" % amount, _FLOAT_COLOR_HEAL, _FLOAT_FONT_SIZE, _FLOAT_DURATION, _FLOAT_MOVE_PIXELS)


## 世界空间自定义文案飘字
func world_custom_float(
	world_position: Vector2,
	text: String,
	color: Color,
	font_size: int = _FLOAT_FONT_SIZE,
	duration_seconds: float = _FLOAT_DURATION,
	move_pixels: float = _FLOAT_MOVE_PIXELS,
	offset: Vector2 = Vector2.ZERO
) -> void:
	if text.is_empty():
		return
	_world_float_spawn(world_position + offset, text, color, font_size, duration_seconds, move_pixels)


## 优先使用已绑定世界层，否则回落到 current_scene 下的 Node2D
func _resolve_world_parent() -> Node:
	if _world_layer != null and is_instance_valid(_world_layer):
		return _world_layer
	var st := get_tree()
	if st == null:
		return null
	var cs: Node = st.current_scene
	if cs is Node2D:
		return cs
	return null


## 在场景树中生成 Node2D + Label，上移并淡出后回收
func _world_float_spawn(pos: Vector2, text: String, color: Color, font_size: int, duration_seconds: float, move_pixels: float) -> void:
	var parent := _resolve_world_parent()
	if parent == null:
		return

	var effect := Node2D.new()
	effect.global_position = pos
	parent.add_child(effect)

	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	effect.add_child(label)

	var tween := effect.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(
		effect,
		"global_position",
		effect.global_position + Vector2(0, -move_pixels),
		duration_seconds
	)
	tween.parallel().tween_property(label, "modulate:a", 0.0, duration_seconds)
	tween.finished.connect(effect.queue_free)
