extends Control
class_name CardSelectController
## 简易多轮选牌：用 SimpleCard 拼HBox，不经过 CardPool（演示/旧流程）

## 每轮展示数量
@export var cards_per_selection: int = 3
## 需要完成的轮数
@export var total_selections: int = 3

## 已选中的字典项列表（suit/rank）
var selected_cards: Array = []
## 已完成轮数
var current_selection: int = 0
## 当前轮创建的 SimpleCard 引用
var card_elements: Array = []

## 全部轮次选完后发出
signal selection_complete(cards)


## 进入第一轮选择
func _ready() -> void:
	start_selection()


## 重置状态并展示第一轮
func start_selection() -> void:
	selected_cards = []
	current_selection = 0
	show_next_selection()


## 清屏后随机生成牌并摆 SimpleCard
func show_next_selection() -> void:
	clear_cards()
	var cards = generate_random_cards()
	
	var container = HBoxContainer.new()
	container.spacing = 50
	container.position = Vector2((size.x - 300) / 2, size.y / 2 - 100)
	add_child(container)
	
	for i in range(cards_per_selection):
		var card = cards[i]
		var label = SimpleCard.new()
		label.suit = card.suit
		label.rank = card.rank
		label.rect_size = Vector2(60, 80)
		label.horizontal_alignment = 1
		label.vertical_alignment = 1
		label.clicked.connect(_on_card_clicked)
		label.metadata["suit"] = card.suit
		label.metadata["rank"] = card.rank
		card_elements.append(label)
		container.add_child(label)
	
	update_progress()


## 生成不重复随机 suit/rank 字典列表
func generate_random_cards() -> Array:
	var cards = []
	var used = []
	
	for i in range(cards_per_selection):
		var suit: int
		var rank: int
		var card_id: int
		var found = false
		
		while not found:
			suit = randi() % 4
			rank = (randi() % 13) + 1
			card_id = suit * 13 + rank
			if not used.has(card_id):
				found = true
				used.append(card_id)
		
		cards.append({"suit": suit, "rank": rank})
	
	return cards


## 移除动态创建的 HBox 子节点
func clear_cards() -> void:
	for child in get_children():
		if child is HBoxContainer:
			child.queue_free()
	card_elements.clear()


## 点击某 SimpleCard：记录选择并进入下一轮或结束
func _on_card_clicked(card) -> void:
	var selected = {
		"suit": card.metadata["suit"],
		"rank": card.metadata["rank"]
	}
	
	selected_cards.append(selected)
	current_selection += 1
	
	print("[select] card_selected | selection=%d/%d | suit=%d rank=%d" % [
		current_selection, total_selections, selected.suit, selected.rank
	])
	
	if current_selection >= total_selections:
		end_selection()
	else:
		show_next_selection()


## 清屏并显示完成文案、发 selection_complete
func end_selection() -> void:
	clear_cards()
	
	var result_label = Label.new()
	result_label.text = "选择完成！\n已选 %d 张卡牌" % selected_cards.size()
	result_label.position = Vector2((size.x - 200) / 2, size.y / 2)
	result_label.rect_size = Vector2(200, 100)
	result_label.horizontal_alignment = 1
	result_label.add_theme_font_size_override("font_size", 24)
	add_child(result_label)
	
	emit_signal("selection_complete", selected_cards)
	print("[select] selection_complete | total_cards=%d" % selected_cards.size())


## 若场景存在 Progress 节点则更新文案
func update_progress() -> void:
	var progress_label = get_node_or_null("Progress")
	if progress_label:
		progress_label.text = "%d/%d" % [current_selection + 1, total_selections]


## 返回已选列表副本引用
func get_selected_cards() -> Array:
	return selected_cards
