extends HBoxContainer
class_name CardHandUI
## 底部手牌条：订阅 CardRuntime；外层槽仅占位，内层 Nudge 承担位移 tween，Card 铺满以保持原场景布局

## 卡牌场景预制
@export var card_scene: PackedScene
## 槽位水平间距（主题覆盖用）
@export var card_spacing: float = -40
## 最多渲染张数（防极端长手）
@export var max_cards_displayed: int = 20

## 缓存的 CardRuntime 引用
var _card_runtime = null
## 当前子节点槽位 Control 列表
var _card_elements: Array = []
## 打出高亮结束后的单次刷新（重启以避免多张牌连续打出时旧定时器提前清空 UI）
var _activation_cleanup_timer: Timer = null

## 打出瞬间高亮颜色
const _ACTIVATE_COLOR := Color(5, 5, 0.55)
## 打出时相对槽位向上位移（像素）
const _ACTIVATE_RISE_PX := -5.0
## 高亮上升段时长（秒）
const _TWEEN_UP_SEC := 0.2
## 回落段时长（秒）
const _TWEEN_DOWN_SEC := 0.2
## 出牌指针位：轻微上移与淡着色
const _PLAYHEAD_Y := -3.0
const _PLAYHEAD_MOD := Color(5, 5, 0.96)
## 单槽宽高（像素）
const _SLOT_W := 80.0
const _SLOT_H := 100.0


## 设置间距并延迟查找 CardRuntime
func _ready() -> void:
	add_theme_constant_override("separation", int(card_spacing))
	_activation_cleanup_timer = Timer.new()
	_activation_cleanup_timer.one_shot = true
	_activation_cleanup_timer.timeout.connect(_update_hand_display)
	add_child(_activation_cleanup_timer)
	print("[ui] CardHandUI ready, starting deferred find")
	call_deferred("_deferred_init")


## 首次绑定 runtime 并建手牌
func _deferred_init() -> void:
	_find_card_runtime()
	_update_hand_display()

## 从当前场景 RunScene 取 CardRuntime 并连信号
func _find_card_runtime() -> void:
	var root = get_tree()
	if root == null:
		print("[ui] CardHandUI error: root is null")
		return
	
	var run_scene = root.get_current_scene()
	if run_scene == null:
		print("[ui] CardHandUI error: current scene is null")
		return
	
	print("[ui] CardHandUI current scene: %s" % run_scene.name)
	
	if run_scene.has_method("get_card_runtime"):
		_card_runtime = run_scene.get_card_runtime()
		if _card_runtime != null:
			_card_runtime.hand_updated.connect(_on_hand_updated)
			_card_runtime.group_played.connect(_on_group_played)
			print("[ui] CardHandUI connected to CardRuntime")
		else:
			print("[ui] CardHandUI warning: get_card_runtime returned null")
	else:
		print("[ui] CardHandUI warning: run_scene has no get_card_runtime method")


## 手牌数据变化：清空高亮状态并重建
func _on_hand_updated() -> void:
	print("[ui] CardHandUI hand_updated signal received")
	_update_hand_display()


## 一组牌打出：先按新指针重建，再对刚打出区间做 tween
func _on_group_played(group_cards: Array, _group_type: String) -> void:
	if _card_runtime == null:
		return
	var start: int = _card_runtime.current_index
	var end: int = start + group_cards.size()
	# 必须刷新：动画用 _card_elements[i] 下标，不用 group_cards 里的节点；且 current_index 变化后
	# 需重建槽位上的 playhead（modulate / nudge.position）。仅「cards 数组长度不变」不等于「UI 槽与指针对齐」。
	# _update_hand_display()
	_play_group_activation_tween(start, end)


## 对 [start, end) 范围内的卡槽统一调用 _activate_card_tween 实现弹出动画
func _play_group_activation_tween(start: int, end: int) -> void:
	print("[ui] CardHandUI _play_group_activation_tween，播放卡牌动画")
	var ran: bool = false
	for i in range(start, end):
		if i < 0 or i >= _card_elements.size():
			continue
		var slot := _card_elements[i] as Control
		if slot == null or slot.get_child_count() < 1:
			continue
		var nudge := slot.get_child(0) as Control
		if nudge == null or nudge.get_child_count() < 1:
			continue
		var c := nudge.get_child(0) as Control
		if c == null or not is_instance_valid(c):
			continue
		if _activate_card_tween(nudge, c):
			ran = true
#
	#if ran and _activation_cleanup_timer != null:
		#_activation_cleanup_timer.stop()
		#_activation_cleanup_timer.wait_time = _TWEEN_UP_SEC + _TWEEN_DOWN_SEC + 0.02
		#_activation_cleanup_timer.start()


## 单张牌弹出并变色动画；参数为 Nudge 层及 Card 控件，成功处理返回 true
func _activate_card_tween(nudge: Control, c: Control) -> bool:
	# 中文：负责单张牌上弹与变色动画，确保节点有效后执行c
	# 打印nudge和c的id
	if nudge == null or c == null or not is_instance_valid(nudge) or not is_instance_valid(c):
		return false
	var ox: float = nudge.position.x
	var base_y: float = nudge.position.y
	print("[ui] CardHandUI _activate_card_tween，nudge的id为%d，c的id为%d" % [nudge.get_instance_id(), c.get_instance_id()])
	var tw := c.create_tween()
	tw.set_parallel(true)
	tw.tween_property(c, "modulate", _ACTIVATE_COLOR, _TWEEN_UP_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(nudge, "position", Vector2(ox, base_y + _ACTIVATE_RISE_PX), _TWEEN_UP_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.chain()
	tw.set_parallel(false)
	tw.tween_property(c, "modulate", Color.WHITE, _TWEEN_DOWN_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(nudge, "position", Vector2(ox, base_y), _TWEEN_DOWN_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return true


## 销毁旧槽并按 runtime.cards 重建
func _update_hand_display() -> void:
	if _card_runtime == null:
		print("[ui] CardHandUI: card_runtime is null")
		return
	
	var cards = _card_runtime.cards
	print("[ui] CardHandUI _update_hand_display，重建卡牌，长度为%d" % cards.size())

	if cards.size() == 0:
		print("[ui] CardHandUI: cards array is empty")
		return
	
	while _card_elements.size() > 0:
		var element = _card_elements.pop_back()
		element.queue_free()

	var display_count = min(cards.size(), max_cards_displayed)
	
	print("[ui] CardHandUI displaying %d cards" % display_count)
	
	for i in range(display_count):
		var card = cards[i]
		var element = _create_card_element(card, i)
		if element != null:
			_card_elements.append(element)
			add_child(element)


## 创建占位槽：外层只占 HBox 一格、无绘制；Nudge 层负责整体上下位移；Card 铺满内层以保持场景内布局比例
## 创建一张手牌的显示元素（包含占位槽、nudge 动画层与卡牌渲染）
## @param card: CardResource 实例, 需显示的卡牌数据
## @param index: int, 该卡在手牌中的序号（用于确定位置和是否为播放指针位置）
## @return Control, 返回手牌栏的最外层槽节点，内含 nudge 控件和具体卡牌
func _create_card_element(card: CardResource, index: int) -> Control:
	# 卡片场景资源懒加载（仅首次用到时加载 .tscn 文件）
	if card_scene == null:
		card_scene = load("res://scenes/ui/Card.tscn")

	# 创建最外层槽（仅占格，无交互和渲染，便于 HBox 布局）
	var slot_size := Vector2(_SLOT_W, _SLOT_H)  # 中文：槽的像素尺寸来自常量
	var slot := Control.new()  # 最外层槽：仅用于布局
	slot.custom_minimum_size = slot_size
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 不拦截鼠标事件
	slot.name = "HandSlot_%d" % index  # 便于调试

	# 创建 Nudge 层（支持动画卡牌整体上下移动，无绘制）
	var nudge := Control.new()
	nudge.name = "Nudge"
	nudge.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 不拦截鼠标事件
	nudge.set_anchors_preset(Control.PRESET_FULL_RECT)  # 填满父槽
	nudge.offset_left = 0
	nudge.offset_top = 0
	nudge.offset_right = 0
	nudge.offset_bottom = 0

	# 实例化卡牌渲染节点（Card 场景）
	var element := card_scene.instantiate() as Card
	if element == null:
		print("[ui] CardHandUI error: failed to instantiate Card scene")
		return null  # 实例化失败，记录日志并返回

	element.set_anchors_preset(Control.PRESET_FULL_RECT)  # 填满 Nudge 层
	element.offset_left = 0
	element.offset_top = 0
	element.offset_right = 0
	element.offset_bottom = 0
	element.set_card(card)  # 绑定数据
	print("[ui] CardHandUI created card: %s" % card.get_full_name())

	# 判断该卡是否是“播放指针”所指向的卡（逻辑判定用来高亮动画、标位移）
	# var is_playhead: bool = index == _card_runtime.current_index
	# if is_playhead:
	# 	nudge.position = Vector2(0, _PLAYHEAD_Y)  # 播放指针：整体上移
	# 	element.modulate = _PLAYHEAD_MOD  # “指针”特有变色（高亮等效果）
	# else:
	# 	nudge.position = Vector2.ZERO  # 其他卡居中无位移
	# 	element.modulate = Color.WHITE  # 默认渲染色

	nudge.add_child(element)   # 先将卡牌节点添加到 Nudge 层
	slot.add_child(nudge)      # 再把 Nudge 层放到最外层槽
	return slot                # 返回槽节点供外层布局


## 返回当前手牌张数（无 runtime 则 0）
func get_card_count() -> int:
	if _card_runtime == null:
		return 0
	return _card_runtime.cards.size()


## 外部强制刷新显示
func refresh_display() -> void:
	_update_hand_display()
