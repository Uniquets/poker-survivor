extends Control
class_name CardElement
## 包装单张 Card 控件的容器：可选中切换高亮（旧版选牌 UI 用）

## 当前绑定的卡牌数据
@export var card_data: CardResource = null
## 内嵌 Card 场景
@export var card_scene: PackedScene = preload("res://scenes/ui/Card.tscn")

## UI 选中态标记
var is_selected: bool = false
## 子节点 Card 实例
var _card_instance: Card = null

## 选中状态变化时发出（携带本元素）
signal card_selected(element: CardElement)
## 点击牌面时发出
signal card_clicked(element: CardElement)


## 若已有数据则实例化子牌
func _ready() -> void:
	if card_data != null:
		_instantiate_card()


## 设置数据并重建子牌
func set_card(card: CardResource) -> void:
	card_data = card
	_instantiate_card()


## 销毁旧实例并新建 Card、连信号
func _instantiate_card() -> void:
	if _card_instance != null:
		_card_instance.queue_free()
	
	if card_scene != null:
		_card_instance = card_scene.instantiate() as Card
		_card_instance.set_card(card_data)
		_card_instance.card_clicked.connect(_on_card_clicked)
		_card_instance.card_selected.connect(_on_card_selected)
		add_child(_card_instance)


## 根据布尔值更新子牌位移与着色
func set_card_selected(selected: bool) -> void:
	is_selected = selected
	if _card_instance != null:
		if is_selected:
			_card_instance.modulate = Color(1, 0.8, 0.6)
			_card_instance.rect_position = Vector2(0, -5)
		else:
			_card_instance.modulate = Color.WHITE
			_card_instance.rect_position = Vector2(0, 0)


## 子牌点击：切换选中并上抛信号
func _on_card_clicked(_card: Card) -> void:
	is_selected = not is_selected
	set_card_selected(is_selected)
	emit_signal("card_clicked", self)


## 子牌选中信号透传
func _on_card_selected(_card: Card) -> void:
	emit_signal("card_selected", self)
	if card_data != null:
		print("[ui] card_clicked | suit=%d rank=%d selected=%s" % [card_data.suit, card_data.rank, str(is_selected)])
