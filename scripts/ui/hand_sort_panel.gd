extends Control
## 手牌排序：透明命中层接收拖拽；牌跟随指针；插入缝显示半透明虚影；无效区域松手还原
## 保存时 duplicate 交给 CardRuntime.set_cards_order

## 用户确认排序并写入 CardRuntime 后发出
signal sort_saved
## 用户取消或点遮罩关闭面板时发出
signal sort_cancelled

## 单槽宽度（像素）；**固定**，不随排布压缩（与手牌栏一致，靠负间距重叠）
const _SLOT_W := 160
## 槽位高度（像素）；`Card.tscn` 须 `_configure_card_*` 置 scale=1 后铺满槽（与根节点 `custom_minimum_size` 一致）
const _SLOT_H := 240
## 牌不多、条带未顶到视口宽度上限时使用的正间距（像素）
const _DEFAULT_SEP_POSITIVE := 18
## 面板左右与 `Slots` 条带之间的额外占用（内容边距等），用于从视口 70% 反推条带最大宽度
const _PANEL_STRIP_OUTSIDE_X := 96.0
## 面板最小高度（牌条 + 标题/说明/按钮区；牌条高与 `_SLOT_H` 同步）
const _PANEL_MIN_HEIGHT := 420.0
## 拖拽浮层 z_index
const _FLOAT_Z := 120
## 插入虚影透明度系数
const _GHOST_ALPHA := 0.26

@onready var _dim: ColorRect = $Dim
@onready var _panel: PanelContainer = $Center/Panel
@onready var _slots: HBoxContainer = $Center/Panel/VBox/Slots
@onready var _btn_save: Button = $Center/Panel/VBox/Actions/SaveButton
@onready var _btn_cancel: Button = $Center/Panel/VBox/Actions/CancelButton

## 手牌数据源（只读打开时拷贝）
var _card_runtime: CardRuntime = null
## 当前编辑中的手牌顺序副本
var _working: Array = []
## 槽内 Card 场景
@export var card_scene: PackedScene = preload("res://scenes/ui/Card.tscn")
## 排序面板最大宽度占视口宽度的比例；顶格后**只调间距（含负间距重叠）**，不压窄单槽
@export var max_panel_width_ratio: float = 0.7
## 槽间 separation 下限（负得越多重叠越大），与手牌栏场景中间距为负、左右重叠的思路一致
@export var sort_separation_min: int = -96
## 槽间 separation 上限（正间距封顶，避免牌少时间距过大）
@export var sort_separation_max: int = 32

## 是否正在拖拽
var _dragging: bool = false
## 拖拽起始槽下标
var _drag_from: int = -1
## 按下点相对牌左上角的偏移（全局空间用）
var _grab_offset: Vector2 = Vector2.ZERO
## 当前计算的槽宽高（宽恒为 `_SLOT_W`）
var _slot_size: Vector2 = Vector2(_SLOT_W, _SLOT_H)
## 跟随鼠标的浮层牌
var _floating: Card = null
## 插入位置预览牌
var _ghost: Card = null
## 上次计算的插入缝下标（用于减少刷新）
var _last_gap: int = -1
## 当前条带 `HBox` 的 separation，供首尾插入缝 ghost 定位（gap 0 / gap n 不能用条带整矩形边线）
var _strip_separation: int = 8


## 槽内牌：父节点为窄槽 `Control`，`FULL_RECT` 铺满槽；须先 scale=1
func _configure_card_in_slot(c: Card) -> void:
	if c == null:
		return
	c.scale = Vector2.ONE
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.offset_left = 0.0
	c.offset_top = 0.0
	c.offset_right = 0.0
	c.offset_bottom = 0.0


## 拖拽浮层 / 插入虚影：父节点是全屏 `HandSortPanel`，若误用 `FULL_RECT` 会铺满整屏导致「拖拽时牌突然变大」
func _configure_card_overlay(c: Card, px_size: Vector2) -> void:
	if c == null:
		return
	c.scale = Vector2.ONE
	c.set_anchors_preset(Control.PRESET_TOP_LEFT)
	c.anchor_left = 0.0
	c.anchor_top = 0.0
	c.anchor_right = 0.0
	c.anchor_bottom = 0.0
	c.offset_left = 0.0
	c.offset_top = 0.0
	c.offset_right = 0.0
	c.offset_bottom = 0.0
	c.custom_minimum_size = px_size
	c.size = px_size
	c.pivot_offset = Vector2.ZERO


## 初始隐藏并联按钮与遮罩
func _ready() -> void:
	visible = false
	if _btn_save:
		_btn_save.pressed.connect(_on_save_pressed)
	if _btn_cancel:
		_btn_cancel.pressed.connect(_on_cancel_pressed)
	if _dim:
		_dim.gui_input.connect(_on_dim_gui_input)


## 拖拽中更新浮牌与虚影；松手时结算插入
func _process(_delta: float) -> void:
	if not visible:
		return
	if _dragging and _floating != null:
		var mg := get_global_mouse_position()
		_floating.global_position = mg - _grab_offset
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var g := _gap_index_at_global(mg)
			if g != _last_gap:
				_last_gap = g
				_update_ghost_at_gap(g)
		else:
			_end_drag(mg)


## 打开面板：拷贝 runtime.cards 并建槽
func open_panel(runtime: CardRuntime) -> void:
	_card_runtime = runtime
	_working.clear()
	if runtime != null:
		for c in runtime.cards:
			_working.append(c)
	_dragging = false
	_cleanup_drag_visuals()
	_rebuild_slots()
	call_deferred("_deferred_apply_strip_layout")
	visible = true


## 布局稳定后再算间距
func _deferred_apply_strip_layout() -> void:
	_apply_strip_layout()


## 尺寸变化时重算条带布局
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and visible:
		_apply_strip_layout()


## 保存：set_cards_order 后关面板
func _on_save_pressed() -> void:
	if _card_runtime != null and _working.size() > 0:
		_card_runtime.set_cards_order(_working)
	emit_signal("sort_saved")
	visible = false
	_cleanup_drag_visuals()


## 取消：不关数据源仅关面板
func _on_cancel_pressed() -> void:
	emit_signal("sort_cancelled")
	visible = false
	_cleanup_drag_visuals()


## 点遮罩：拖拽中则中止拖拽，否则等同取消
func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _dragging:
			_dragging = false
			_abort_drag()
		else:
			_on_cancel_pressed()


## 固定单槽宽高；条带宽度 = n×槽宽 + (n−1)×separation（separation 可为负，与手牌栏重叠同理）；顶到视口比例上限后只把 separation 算负
func _apply_strip_layout() -> void:
	var n: int = _working.size()
	if n == 0 or _slots == null:
		return
	var vw: float = get_viewport().get_visible_rect().size.x
	var cap_outer: float = maxf(120.0, vw * clampf(max_panel_width_ratio, 0.2, 1.0))
	var inner_max_strip: float = maxf(40.0, cap_outer - _PANEL_STRIP_OUTSIDE_X)
	var fixed_w: int = _SLOT_W
	var sep: int = 0
	if n == 1:
		sep = 0
	else:
		var natural_strip: float = float(n * fixed_w) + float(n - 1) * float(_DEFAULT_SEP_POSITIVE)
		if natural_strip <= inner_max_strip:
			sep = clampi(_DEFAULT_SEP_POSITIVE, sort_separation_min, sort_separation_max)
		else:
			var sf: float = (inner_max_strip - float(n * fixed_w)) / float(n - 1)
			sep = int(floor(sf))
			sep = clampi(sep, sort_separation_min, sort_separation_max)
	_strip_separation = sep
	_slots.add_theme_constant_override("separation", sep)
	_slot_size = Vector2(float(fixed_w), float(_SLOT_H))
	var strip_w: float = float(n * fixed_w) + float(max(0, n - 1)) * float(sep)
	var outer_w: float = strip_w + _PANEL_STRIP_OUTSIDE_X
	outer_w = minf(outer_w, cap_outer)
	if _panel != null:
		_panel.custom_minimum_size = Vector2(outer_w, _PANEL_MIN_HEIGHT)
	for ch in _slots.get_children():
		if ch is Control:
			var slot_c := ch as Control
			slot_c.custom_minimum_size = _slot_size
			for grand in slot_c.get_children():
				if grand is Card:
					var gc := grand as Card
					_configure_card_in_slot(gc)
					gc.custom_minimum_size = _slot_size
					gc.size = _slot_size


## 全局坐标映射到插入缝 0..n（越界返回 -1）；负间距重叠时条带非均匀分格，按相邻插入缝中心的中点划分
func _gap_index_at_global(mg: Vector2) -> int:
	var n: int = _working.size()
	if n == 0:
		return -1
	var base := _slots.get_global_rect()
	var r := Rect2(base.position - Vector2(20, 56), base.size + Vector2(40, 112))
	if not r.has_point(mg):
		return -1
	var hx: float = mg.x
	if n == 1:
		var c0: float = _gap_center_x_global(0)
		var c1: float = _gap_center_x_global(1)
		var t: float = (c0 + c1) * 0.5
		return 0 if hx < t else 1
	var centers: Array[float] = []
	for g in range(n + 1):
		centers.append(_gap_center_x_global(g))
	for g in range(n):
		var t_mid: float = (centers[g] + centers[g + 1]) * 0.5
		if hx < t_mid:
			return g
	return n


## 将 from_i 元素移动到插入缝 gap（规则与 remove+insert 一致）
func _apply_insert_gap(from_i: int, gap: int) -> void:
	var n: int = _working.size()
	if from_i < 0 or from_i >= n or gap < 0 or gap > n:
		return
	var item: Variant = _working[from_i]
	_working.remove_at(from_i)
	var insert_at: int = gap
	if gap > from_i:
		insert_at = gap - 1
	insert_at = clampi(insert_at, 0, _working.size())
	_working.insert(insert_at, item)


## 销毁并重建全部槽位与命中层
func _rebuild_slots() -> void:
	for ch in _slots.get_children():
		ch.queue_free()
	for i in range(_working.size()):
		var slot_root := Control.new()
		slot_root.name = "Slot%d" % i
		slot_root.custom_minimum_size = _slot_size
		slot_root.clip_contents = true
		var c := card_scene.instantiate() as Card
		if c:
			_configure_card_in_slot(c)
			c.custom_minimum_size = _slot_size
			c.size = _slot_size
			c.set_card(_working[i] as CardResource)
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot_root.add_child(c)
		var hit := ColorRect.new()
		hit.name = "Hit"
		hit.color = Color(1, 1, 1, 0.02)
		hit.mouse_filter = Control.MOUSE_FILTER_STOP
		hit.set_anchors_preset(Control.PRESET_FULL_RECT)
		hit.offset_left = 0
		hit.offset_top = 0
		hit.offset_right = 0
		hit.offset_bottom = 0
		hit.z_index = 2
		hit.gui_input.connect(_on_hit_gui_input.bind(i))
		slot_root.add_child(hit)
		_slots.add_child(slot_root)
	call_deferred("_deferred_apply_strip_layout")


## 槽命中层按下：开始拖拽
func _on_hit_gui_input(event: InputEvent, slot_index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_begin_drag(slot_index, event.global_position)
		accept_event()


## 生成浮层并记录抓取偏移
func _begin_drag(from_idx: int, global_press: Vector2) -> void:
	if from_idx < 0 or from_idx >= _working.size() or _dragging:
		return
	_dragging = true
	_drag_from = from_idx
	var slot := _slots.get_child(from_idx) as Control
	var card: Card = null
	for sub in slot.get_children():
		if sub is Card:
			card = sub as Card
			break
	if card == null:
		return
	var cr := card.get_global_rect()
	_grab_offset = global_press - cr.position
	_floating = card_scene.instantiate() as Card
	_configure_card_overlay(_floating, _slot_size)
	_floating.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_floating.set_card(_working[from_idx] as CardResource)
	_floating.z_index = _FLOAT_Z
	_floating.z_as_relative = false
	add_child(_floating)
	_floating.global_position = global_press - _grab_offset
	if card:
		card.modulate = Color(1, 1, 1, 0.18)
	_last_gap = -1
	_update_ghost_at_gap(_gap_index_at_global(global_press))


## 松手：合法缝则插入并重排，否则中止
func _end_drag(global_release: Vector2) -> void:
	if not _dragging:
		return
	_dragging = false
	var g := _gap_index_at_global(global_release)
	if g < 0:
		_abort_drag()
		return
	# 原牌左右两条「家」缝，松手视为不移动
	if g == _drag_from or g == _drag_from + 1:
		_abort_drag()
		return
	_apply_insert_gap(_drag_from, g)
	_rebuild_slots()
	_cleanup_drag_visuals()
	_drag_from = -1
	_last_gap = -1


## 放弃本次拖拽视觉状态
func _abort_drag() -> void:
	_cleanup_drag_visuals()
	_drag_from = -1
	_last_gap = -1


## 移除浮层/虚影并恢复槽内牌不透明
func _cleanup_drag_visuals() -> void:
	if is_instance_valid(_floating):
		_floating.queue_free()
	_floating = null
	if is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null
	for i in _slots.get_child_count():
		var sl := _slots.get_child(i) as Control
		for j in sl.get_child_count():
			var ch := sl.get_child(j)
			if ch is Card:
				(ch as CanvasItem).modulate = Color.WHITE


## 在插入缝处显示半透明预览牌
func _update_ghost_at_gap(gap: int) -> void:
	if not _dragging or _drag_from < 0:
		return
	var n: int = _working.size()
	if gap < 0 or gap > n:
		if is_instance_valid(_ghost):
			_ghost.visible = false
		return
	if gap == _drag_from or gap == _drag_from + 1:
		if is_instance_valid(_ghost):
			_ghost.visible = false
		return
	if not is_instance_valid(_ghost):
		_ghost = card_scene.instantiate() as Card
		_configure_card_overlay(_ghost, _slot_size)
		_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ghost.z_index = _FLOAT_Z - 1
		_ghost.z_as_relative = false
		add_child(_ghost)
	_configure_card_overlay(_ghost, _slot_size)
	_ghost.set_card(_working[_drag_from] as CardResource)
	_ghost.modulate = Color(1, 1, 1, _GHOST_ALPHA)
	_ghost.visible = true
	var x_center: float = _gap_center_x_global(gap)
	var y_top: float = _slots.get_global_rect().position.y
	_ghost.global_position = Vector2(x_center - _ghost.size.x * 0.5, y_top)


## 插入缝中心的全局 X（用于摆 ghost）；gap 0 / n 须在首槽外侧、尾槽外侧各留半格间距，避免贴边错位
func _gap_center_x_global(gap: int) -> float:
	var n := _working.size()
	if n == 0:
		return _slots.get_global_rect().get_center().x
	var sep := float(_strip_separation)
	if gap == 0:
		var s0 := _slots.get_child(0) as Control
		return s0.get_global_rect().position.x - sep * 0.5
	if gap == n:
		var sn := _slots.get_child(n - 1) as Control
		return sn.get_global_rect().end.x + sep * 0.5
	var left := (_slots.get_child(gap - 1) as Control).get_global_rect().end.x
	var right := (_slots.get_child(gap) as Control).get_global_rect().position.x
	return (left + right) * 0.5
