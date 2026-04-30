extends Control
class_name CardSelectUI
## 横向选牌区：从 CardPool 抽展示牌；全屏 `FullDim` 压暗背景。手牌槽间空隙透过透明区叠在本层全屏暗色上；手牌每张牌提亮由 `CardHandUI.set_hand_card_overlay_glow` 负责（选牌或 H 测试菜单时由 RunScene 驱动）。

## 用于实例化每张可选牌的场景
@export var card_scene: PackedScene
## 每轮展示几张供选
@export var cards_per_selection: int = 3
## 相对手牌单槽尺寸 (160×240) 的倍数；`HBoxContainer` **不会**把 `scale` 算进占位，必须用槽尺寸驱动布局（默认 1 与底栏手牌同大）
@export var option_card_size_multiplier: float = 1.0

@export_group("选牌 · Hover 放大与边框光效")
## 为假时不挂光效层、不连 **`mouse_entered`**，与旧表现一致
@export var select_hover_enabled: bool = true
## 鼠标移入后牌相对槽的缩放（**`1.0`** 为不变）；以牌中心为 **`pivot_offset`**；光效为 **`Card`** 子 **`Panel`**，与牌同变换，贴在牌根矩形（与 **`Card.tscn`** 内贴图同外框）上，不再挂在槽上
@export_range(1.0, 1.35, 0.01) var select_hover_scale: float = 1.1
## 移入过渡到 **`select_hover_scale`** 的时长（秒）
@export_range(0.04, 0.5, 0.01) var select_hover_in_sec: float = 0.14
## 移出还原到 **`1.0`** 的时长（秒）
@export_range(0.06, 0.8, 0.01) var select_hover_out_sec: float = 0.26
## **`StyleBoxFlat`** 描边色（含 alpha）；光晕圈沿 **`Panel`** 内缘，与牌可视外框一致
@export var select_hover_glow_border_color: Color = Color(1.0, 0.94, 0.72, 0.92)
## 相对牌根矩形向外扩展（像素）：**`0`** 时 **`Panel`** 与牌同大，描边贴在控件边缘（与 **`CardFront`** 外框对齐）；**`>0`** 时圈略外扩仍随牌 **`scale`**
@export_range(0.0, 24.0, 1.0) var select_hover_glow_padding_px: float = 0.0
## 与 **`Card.tscn`** 中 **`CardShadow`** 圆角（**`6`**）协调；描边圆角像素
@export_range(0.0, 24.0, 1.0) var select_hover_glow_corner_radius: float = 6.0
## 描边宽度（像素）
@export_range(0, 8, 1) var select_hover_glow_border_width: int = 2
## 外扩柔光阴影；**`0`** 关闭
@export_range(0, 28, 1) var select_hover_glow_shadow_size: int = 10
@export var select_hover_glow_shadow_color: Color = Color(1.0, 0.85, 0.45, 0.5)

## 与 `CardHandUI` 单槽一致（像素）
const _SLOT_W := 160.0
const _SLOT_H := 240.0
## 选项槽上挂的 Hover **`Tween`** 元数据键，清槽前须 **`kill`** 避免指向已释放节点
const _META_SELECT_HOVER_TWEEN := "_select_hover_tween"

## 三选一牌行：置于 `CardArea`（CenterContainer）内以便相对视口水平垂直居中
@onready var _card_container: HBoxContainer = $CardArea/CardContainer
@onready var _title_label: Label = $Title
## 升级选卡时由 **`RunScene`** 显示；点击发 **`offer_skipped`**，由场景侧校验模式后 **`finalize_skip_current_offer`**
@onready var _skip_offer_row: Control = $SkipOfferRow
@onready var _skip_offer_button: Button = $SkipOfferRow/SkipOfferButton

## 当前轮可选 CardResource 列表
var _card_options: Array = []
## 当前轮可选强化效果列表；非空时 UI 按统一卡面展示效果。
var _upgrade_effect_options: Array = []
## 当前容器内 Card 控件实例
var _card_instances: Array = []
## 是否允许点击选中
var _is_selecting: bool = true
## 开局/连续轮次三选一：与 `RunScene` 传入的等级、幸运一致，供加权抽牌
var _offer_player_level: int = 1
var _offer_player_luck: float = 0.0

## 用户选定一张牌时发出（参数为 CardResource）
signal card_selected(card: CardResource)
## 用户选中某个强化效果时发出。
signal upgrade_effect_selected(effect: Resource)
## 用户点击「跳过」：仅作意图；**`RunScene`** 须在 **`LEVEL_UP`** 模式下再 **`finalize_skip_current_offer`**
signal offer_skipped


## 连接跳过键；跳过行默认隐藏，由场景在升级选卡时打开
func _ready() -> void:
	if is_instance_valid(_skip_offer_button):
		_skip_offer_button.pressed.connect(_on_skip_offer_pressed)
	set_skip_offer_visible(false)


## 显示或隐藏升级用「跳过」行（开局/测试加牌等应保持隐藏）；显示时重置 **`disabled`** 以便连升多级后仍可点
func set_skip_offer_visible(show_row: bool) -> void:
	if is_instance_valid(_skip_offer_row):
		_skip_offer_row.visible = show_row
	if is_instance_valid(_skip_offer_button):
		_skip_offer_button.disabled = not show_row


## 开局或刷新一轮：写入等级/幸运并从池抽 `cards_per_selection` 张（加权）
func begin_weighted_offer(player_level: int, player_luck: float) -> void:
	_offer_player_level = player_level
	_offer_player_luck = player_luck
	_generate_card_options()
	_display_options()


## 从 CardPool 抽取 cards_per_selection 张填入 _card_options（优先加权接口）
func _generate_card_options() -> void:
	var pool := get_node_or_null("/root/CardPool")
	if pool == null:
		push_warning("[CardSelectUI] 未找到 Autoload CardPool，无法抽牌")
		_card_options.clear()
		return
	if pool.has_method("draw_cards_for_weighted_offer"):
		_card_options = pool.draw_cards_for_weighted_offer(cards_per_selection, _offer_player_level, _offer_player_luck)
	elif pool.has_method("draw_cards"):
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


## 跳过本轮：当期展示牌**全部**归还卡池（不 **`consume_card`**），清空选项并禁止再点
func finalize_skip_current_offer() -> void:
	var pool := get_node_or_null("/root/CardPool")
	if pool != null:
		for c in _card_options:
			if pool.has_method("return_card"):
				pool.return_card(c)
	_card_options.clear()
	_is_selecting = false
	clear_cards()


## 跳过键：禁用按钮防连点，再发信号；是否合法由 **`RunScene`** 判断（**`show_cards`** 会在跳过后再抽时重新 **`disabled=false`**）
func _on_skip_offer_pressed() -> void:
	if not _is_selecting:
		return
	if is_instance_valid(_skip_offer_button):
		_skip_offer_button.disabled = true
	emit_signal("offer_skipped")


## 清空旧节点并延迟重建（避免与信号同帧 free）
func _display_options() -> void:
	_card_instances.clear()
	for child in _card_container.get_children():
		## 中文：先停 Hover **`Tween`**，再 **`queue_free`**，否则 **`Tween`** 仍引用子 **`Card`**
		_stop_select_hover_tween_on_slot(child)
		child.queue_free()
	call_deferred("_build_option_cards")


## 实例化选项牌：外层槽用 `custom_minimum_size` 占格（HBox 不认 `scale`）；内层 Card 铺满槽并将根 scale 置 1 以免与占位重复放大
func _build_option_cards() -> void:
	if not is_instance_valid(_card_container) or card_scene == null:
		return
	_card_instances.clear()
	## 选项行间距以场景中 `CardArea/CardContainer` 的 `theme_override_constants/separation` 为准，不在此重复赋值
	var mul: float = option_card_size_multiplier
	var cell := Vector2(_SLOT_W * mul, _SLOT_H * mul)

	var option_count: int = _upgrade_effect_options.size() if not _upgrade_effect_options.is_empty() else _card_options.size()
	for i in range(option_count):
		var card_data = _card_options[i] if _upgrade_effect_options.is_empty() else _display_card_for_effect(_upgrade_effect_options[i])
		var slot := Control.new()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.custom_minimum_size = cell

		var card_instance := card_scene.instantiate() as Card
		slot.add_child(card_instance)
		card_instance.set_anchors_preset(Control.PRESET_FULL_RECT)
		card_instance.offset_left = 0
		card_instance.offset_top = 0
		card_instance.offset_right = 0
		card_instance.offset_bottom = 0
		card_instance.scale = Vector2(1.0, 1.0)
		card_instance.set_card(card_data)
		if _upgrade_effect_options.is_empty():
			card_instance.card_clicked.connect(_on_card_clicked)
		else:
			var effect: Resource = _upgrade_effect_options[i] as Resource
			_apply_effect_card_visual(card_instance, effect, card_data)
			card_instance.card_clicked.connect(_on_upgrade_effect_card_clicked.bind(effect))
		_card_instances.append(card_instance)
		_card_container.add_child(slot)
		## 中文：在 **`Card`** 内挂 **`Panel`** 边框光（**`StyleBoxFlat`**），随牌 **`scale`** 与矩形走，不挂在槽上
		if select_hover_enabled:
			_setup_select_hover_on_slot(slot, card_instance)


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


## 点击强化效果卡面后发出统一选择信号。
func _on_upgrade_effect_card_clicked(card: Card, effect: Resource) -> void:
	if not _is_selecting:
		return
	if _card_instances.find(card) == -1:
		return
	if effect == null:
		return
	card.modulate = Color(1, 0.8, 0.6)
	card.position = Vector2(0, -5)
	emit_signal("upgrade_effect_selected", effect)


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
		_stop_select_hover_tween_on_slot(child)
		child.queue_free()
	_card_options.clear()
	_upgrade_effect_options.clear()


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
	_upgrade_effect_options.clear()
	for card in cards:
		_card_options.append(card)
	_display_options()
	_is_selecting = true
	if is_instance_valid(_skip_offer_button) and is_instance_valid(_skip_offer_row) and _skip_offer_row.visible:
		_skip_offer_button.disabled = false


## 展示强化效果三选一；统一使用卡面背景，卡牌效果显示点数花色，非卡牌效果显示文字。
func show_upgrade_effects(effects: Array) -> void:
	_card_options.clear()
	_upgrade_effect_options = []
	for effect in effects:
		if effect is Resource:
			_upgrade_effect_options.append(effect)
	_display_options()
	_is_selecting = true
	if is_instance_valid(_skip_offer_button) and is_instance_valid(_skip_offer_row) and _skip_offer_row.visible:
		_skip_offer_button.disabled = false


## 返回强化效果需要按普通卡牌样式展示的卡牌。
func _display_card_for_effect(effect: Resource) -> CardResource:
	if effect != null and effect.has_method("get_display_card"):
		return effect.call("get_display_card") as CardResource
	return null


## 按效果类型刷新卡面：非卡牌效果清空角标并在中间显示标题和说明。
func _apply_effect_card_visual(card_instance: Card, effect: Resource, display_card: CardResource) -> void:
	if card_instance == null or effect == null:
		return
	if display_card != null:
		return
	var labels: Array[String] = ["Suit1", "Num1", "Suit2", "Num2"]
	for path in labels:
		var label := card_instance.get_node_or_null("Front/%s" % path) as Label
		if label != null:
			label.text = ""
	var text := Label.new()
	text.name = "UpgradeEffectText"
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.set_anchors_preset(Control.PRESET_FULL_RECT)
	text.offset_left = 20.0
	text.offset_top = 64.0
	text.offset_right = -20.0
	text.offset_bottom = -48.0
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", 18)
	text.add_theme_color_override("font_color", Color(0.08, 0.07, 0.06, 1.0))
	var title: String = str(effect.get("title"))
	var desc: String = str(effect.get("description"))
	text.text = title if desc.strip_edges().is_empty() else "%s\n%s" % [title, desc]
	card_instance.get_node("Front").add_child(text)


## 若槽上存有 Hover **`Tween`**，**`kill`** 并移除元数据，避免与 **`queue_free`** 竞态
func _stop_select_hover_tween_on_slot(slot: Node) -> void:
	if slot == null or not slot.has_meta(_META_SELECT_HOVER_TWEEN):
		return
	var tw: Tween = slot.get_meta(_META_SELECT_HOVER_TWEEN) as Tween
	if tw != null and is_instance_valid(tw):
		tw.kill()
	slot.remove_meta(_META_SELECT_HOVER_TWEEN)


## 构建贴在 **`Card`** 矩形上的 **`StyleBoxFlat`**：**`bg_color` 全透明**，仅描边 + 外阴影形成外圈光，不提亮牌面中心
func _build_select_hover_glow_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	sb.border_color = select_hover_glow_border_color
	var bw: int = clampi(select_hover_glow_border_width, 0, 8)
	sb.set_border_width_all(bw)
	var rad_i: int = maxi(0, roundi(select_hover_glow_corner_radius))
	sb.corner_radius_top_left = rad_i
	sb.corner_radius_top_right = rad_i
	sb.corner_radius_bottom_right = rad_i
	sb.corner_radius_bottom_left = rad_i
	var sh: int = maxi(0, select_hover_glow_shadow_size)
	sb.shadow_size = sh
	sb.shadow_color = select_hover_glow_shadow_color
	sb.shadow_offset = Vector2.ZERO
	return sb


## 在 **`Card`** 内添加 **`Panel`** 光晕层：铺满牌根并可选外扩；**`Front`**（含 **`CardFront`** 精灵）须盖在光效之上，避免描边/阴影压住牌面
func _setup_select_hover_on_slot(slot: Control, card: Card) -> void:
	if not is_instance_valid(slot) or not is_instance_valid(card):
		return
	var glow := Panel.new()
	glow.name = "SelectHoverGlowRing"
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	var pad: float = maxf(0.0, select_hover_glow_padding_px)
	glow.offset_left = -pad
	glow.offset_top = -pad
	glow.offset_right = pad
	glow.offset_bottom = pad
	glow.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	var sb: StyleBoxFlat = _build_select_hover_glow_style()
	glow.add_theme_stylebox_override(&"panel", sb)
	card.add_child(glow)
	## 中文：与 **`Card.tscn`** 一致，**`Front`** 为正面贴图与角标根节点；光效插到其**前**一顺位，绘制时牌面挡住中心，外扩阴影仍可露出边缘
	var front_root: Node = card.get_node_or_null("Front")
	if front_root != null:
		card.move_child(glow, front_root.get_index())
	else:
		push_warning("[CardSelectUI] Card 缺少子节点 Front，SelectHoverGlowRing 无法置于牌面之下")
	card.mouse_entered.connect(_on_select_offer_card_hover_entered.bind(slot, card, glow))
	card.mouse_exited.connect(_on_select_offer_card_hover_exited.bind(slot, card, glow))


## 鼠标移入选项牌：以牌中心为轴放大，并渐显边框光效
func _on_select_offer_card_hover_entered(slot: Control, card: Card, glow: Panel) -> void:
	if not select_hover_enabled or not is_instance_valid(slot) or not is_instance_valid(card):
		return
	_stop_select_hover_tween_on_slot(slot)
	## 中文：布局后 **`size`** 才可靠；**`pivot_offset`** 取中心避免放大时牌「往一角飘」
	card.pivot_offset = card.size * 0.5
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "scale", Vector2.ONE * select_hover_scale, select_hover_in_sec)
	if is_instance_valid(glow):
		tw.tween_property(glow, "self_modulate", Color(1.0, 1.0, 1.0, 1.0), select_hover_in_sec)
	slot.set_meta(_META_SELECT_HOVER_TWEEN, tw)


## 鼠标移出选项牌：缩回 **`1`** 并渐隐边框光效
func _on_select_offer_card_hover_exited(slot: Control, card: Card, glow: Panel) -> void:
	if not select_hover_enabled or not is_instance_valid(slot) or not is_instance_valid(card):
		return
	_stop_select_hover_tween_on_slot(slot)
	var tw2: Tween = create_tween()
	tw2.set_parallel(true)
	tw2.set_trans(Tween.TRANS_CUBIC)
	tw2.set_ease(Tween.EASE_IN_OUT)
	tw2.tween_property(card, "scale", Vector2.ONE, select_hover_out_sec)
	var g: Panel = glow
	if is_instance_valid(g):
		tw2.tween_property(g, "self_modulate", Color(1.0, 1.0, 1.0, 0.0), select_hover_out_sec)
	slot.set_meta(_META_SELECT_HOVER_TWEEN, tw2)
