extends ColorRect
class_name Card
## 单张牌 UI：正反面纹理与标签，根节点接收点击

## 绑定的卡牌资源
@export var card_data: CardResource = null
## 是否显示正面
@export var is_face_up: bool = true

## 花色 Unicode 显示顺序：黑桃、红心、方块、梅花
const SUITS = ["♠", "♥", "♦", "♣"]
## 点数显示文本顺序 A-K
const RANKS = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]

## 正面整体容器（底图与角标；翻面时整层隐藏）
@onready var front_face_root: Control = $Front
## 正面底图（场景中挂在 `Front` 下，路径须与场景一致）
@onready var front_texture_rect: TextureRect = $Front/CardFront
@onready var back_texture_rect: TextureRect = $Back

@onready var suit1_label: Label = $Front/Suit1
@onready var num1_label: Label = $Front/Num1
@onready var suit2_label: Label = $Front/Suit2
@onready var num2_label: Label = $Front/Num2

## 左键点整张牌时发出（携带自身）
signal card_clicked(card: Card)
## 与 card_clicked 同时发出，供旧代码兼容
signal card_selected(card: Card)


## 初始化鼠标过滤并刷新显示
func _ready() -> void:
	# 整块牌由根节点接收点击；子节点在场景中设为 IGNORE，避免热区缩成标签/纹理局部
	mouse_filter = Control.MOUSE_FILTER_STOP
	update_display()


## 绑定数据并刷新
func set_card(data: CardResource) -> void:
	card_data = data
	update_display()


## 切换正反面
func flip() -> void:
	is_face_up = !is_face_up
	update_display()


## 设置是否正面朝上并刷新
func set_face_up(face_up: bool) -> void:
	is_face_up = face_up
	update_display()


## 根据 card_data 更新纹理与角标文字
func update_display() -> void:
	if front_face_root == null or front_texture_rect == null or back_texture_rect == null:
		return
	
	# 中文：整层 Front 切换可见性，避免仅隐藏 TextureRect 时角标仍叠在牌背上
	front_face_root.visible = is_face_up
	back_texture_rect.visible = !is_face_up
	
	if card_data != null:
		if card_data.front_texture != null:
			front_texture_rect.texture = card_data.front_texture
		if card_data.back_texture != null:
			back_texture_rect.texture = card_data.back_texture
		
		_update_card_text()


## 写入四角花色/点数标签（红桃/方块与黑桃/梅花同色；勿在场景里给点数 Label 挂固定色的 `LabelSettings`，否则会盖住 `font_color` 覆盖）
func _update_card_text() -> void:
	if card_data == null:
		return
	
	var suit = card_data.suit
	var rank = card_data.rank
	
	var suit_char = SUITS[suit] if suit >= 0 and suit < SUITS.size() else "?"
	var rank_char = RANKS[rank - 1] if rank >= 1 and rank <= 13 else "?"
	# 中文：与标准扑克一致，红心/方块红，黑桃/梅花黑；四角统一用同一色
	var suit_color := Color(1, 0, 0) if suit == 1 or suit == 2 else Color(0, 0, 0)
	
	if suit1_label != null:
		suit1_label.text = suit_char
		suit1_label.add_theme_color_override("font_color", suit_color)
	
	if num1_label != null:
		num1_label.text = rank_char
		num1_label.add_theme_color_override("font_color", suit_color)
	
	if suit2_label != null:
		suit2_label.text = suit_char
		suit2_label.add_theme_color_override("font_color", suit_color)
	
	if num2_label != null:
		num2_label.text = rank_char
		num2_label.add_theme_color_override("font_color", suit_color)


## 左键按下：接受事件并发出选中信号
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			accept_event()
			emit_signal("card_clicked", self)
			emit_signal("card_selected", self)
