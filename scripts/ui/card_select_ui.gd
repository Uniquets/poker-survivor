extends Control
class_name CardSelectUI
## 横向选牌区：从 CardPool 抽展示牌，选后通知上层并处理池归还/消耗

## 用于实例化每张可选牌的场景
@export var card_scene: PackedScene
## 每轮展示几张供选
@export var cards_per_selection: int = 3

@onready var _card_container: HBoxContainer = $CardContainer
@onready var _title_label: Label = $Title

## 当前轮可选 CardResource 列表
var _card_options: Array = []
## 当前容器内 Card 控件实例
var _card_instances: Array = []
## 是否允许点击选中
var _is_selecting: bool = true

## 用户选定一张牌时发出（参数为 CardResource）
signal card_selected(card: CardResource)


## 首轮：抽牌并展示
func _ready() -> void:
	_generate_card_options()
	_display_options()


## 从 CardPool 抽取 cards_per_selection 张填入 _card_options
func _generate_card_options() -> void:
	var pool := get_node_or_null("/root/CardPool")
	if pool == null:
		push_warning("[CardSelectUI] 未找到 Autoload CardPool，无法抽牌")
		_card_options.clear()
		return
	if pool.has_method("draw_cards"):
		_card_options = pool.draw_cards(cards_per_selection)
	else:
		_card_options.clear()


## 三选一类：未选 return_card，选中 consume_card
func finalize_pick_from_current_offer(chosen: CardResource) -> void:
	var pool := get_node_or_null("/root/CardPool")
	if pool == null:
		return
	for c in _card_options:
		if c != chosen and pool.has_method("return_card"):
			pool.return_card(c)
	if pool.has_method("consume_card"):
		pool.consume_card(chosen)


## 清空旧节点并延迟重建（避免与信号同帧 free）
func _display_options() -> void:
	_card_instances.clear()
	for child in _card_container.get_children():
		child.queue_free()
	call_deferred("_build_option_cards")


## 实例化选项牌并联点击信号
func _build_option_cards() -> void:
	if not is_instance_valid(_card_container) or card_scene == null:
		return
	_card_instances.clear()
	for i in range(len(_card_options)):
		var card_data = _card_options[i]
		var card_instance = card_scene.instantiate() as Card
		_card_container.add_child(card_instance)
		card_instance.set_card(card_data)
		card_instance.card_clicked.connect(_on_card_clicked)
		_card_instances.append(card_instance)


## 点击某张可选牌：校验后发出 card_selected
func _on_card_clicked(card: Card) -> void:
	if not _is_selecting:
		return
	
	if _card_instances.find(card) == -1:
		return
	
	var selected_card: CardResource = card.card_data
	if selected_card == null:
		return
	
	card.modulate = Color(1, 0.8, 0.6)
	card.position = Vector2(0, -5)
	
	emit_signal("card_selected", selected_card)
	
	print("[ui] card_selected | card=%s damage=%d" % [selected_card.get_full_name(), selected_card.damage])


## 进入下一轮：重新抽牌并展示
func next_round() -> void:
	_is_selecting = true
	_generate_card_options()
	_display_options()


## 禁止再响应点击
func disable_selection() -> void:
	_is_selecting = false


## 清空容器与选项数据
func clear_cards() -> void:
	_card_instances.clear()
	for child in _card_container.get_children():
		child.queue_free()
	_card_options.clear()


## 更新顶部标题文案
func set_title(text: String) -> void:
	if _title_label != null:
		_title_label.text = text


## 是否仍处于可选状态
func is_selecting() -> bool:
	return _is_selecting


## 用指定数组作为本轮选项（不加抽池，用于测试加牌）
func show_cards(cards: Array) -> void:
	_card_options = []
	for card in cards:
		_card_options.append(card)
	_display_options()
	_is_selecting = true
