extends Label
class_name SimpleCard
## 用 Label 文本模拟一张小牌（花色+点数），供简易选牌控制器使用

## 花色 0-3
@export var suit: int = 0
## 点数 1-13
@export var rank: int = 1
## 是否处于选中高亮
var is_selected: bool = false

## 被点击时发出自身引用
signal clicked(card)


## 初次显示内容
func _ready() -> void:
	update_display()


## 刷新文本与字体色
func update_display() -> void:
	var suit_char = get_suit_char()
	var rank_char = get_rank_char()
	var suit_color = get_suit_color()
	
	text = rank_char + suit_char
	add_theme_color_override("font_color", suit_color)
	add_theme_font_size_override("font_size", 32)


## Unicode 花色字符
func get_suit_char() -> String:
	var suits = ["\u2660", "\u2665", "\u2666", "\u2663"]
	if suit >= 0 and suit < suits.size():
		return suits[suit]
	return "?"


## 点数字符串
func get_rank_char() -> String:
	var ranks = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
	if rank >= 1 and rank <= 13:
		return ranks[rank - 1]
	return "?"


## 红系花色用红色字，其余黑色
func get_suit_color() -> Color:
	if suit == 1 or suit == 2:
		return Color(0.8, 0.2, 0.2)
	return Color(0.1, 0.1, 0.1)


## 切换选中时字体色（与花色色区分）
func set_selected(selected: bool) -> void:
	is_selected = selected
	if is_selected:
		add_theme_color_override("font_color", Color(1, 0.5, 0))
	else:
		add_theme_color_override("font_color", get_suit_color())


## 全局输入：左键切换选中并发 clicked（注意与 Card 不同为 _input）
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_selected = not is_selected
				set_selected(is_selected)
				emit_signal("clicked", self)
				print("[card] clicked | suit=%d rank=%d" % [suit, rank])
