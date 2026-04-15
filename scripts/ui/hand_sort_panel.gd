extends Control
## 手牌排序：透明命中层接收拖拽；牌跟随指针；插入缝显示半透明虚影；无效区域松手还原
## 保存时 duplicate 交给 CardRuntime.set_cards_order

## 用户确认排序并写入 CardRuntime 后发出
signal sort_saved
## 用户取消或点遮罩关闭面板时发出
signal sort_cancelled

## 槽位最小宽度（像素）
const _MIN_SLOT_W := 44
## 槽位最大宽度（像素）
const _MAX_SLOT_W := 86
## 槽位高度（像素）
const _SLOT_H := 132
## 拖拽浮层 z_index
const _FLOAT_Z := 120
## 插入虚影透明度系数
const _GHOST_ALPHA := 0.26

@onready var _dim: ColorRect = $Dim
@onready var _slots: HBoxContainer = $Center/Panel/VBox/Slots
@onready var _btn_save: Button = $Center/Panel/VBox/Actions/SaveButton
@onready var _btn_cancel: Button = $Center/Panel/VBox/Actions/CancelButton

## 手牌数据源（只读打开时拷贝）
var _card_runtime: CardRuntime = null
## 当前编辑中的手牌顺序副本
var _working: Array = []
## 槽内 Card 场景
@export var card_scene: PackedScene = preload("res://scenes/ui/Card.tscn")

## 是否正在拖拽
var _dragging: bool = false
## 拖拽起始槽下标
var _drag_from: int = -1
## 按下点相对牌左上角的偏移（全局空间用）
var _grab_offset: Vector2 = Vector2.ZERO
## 当前计算的槽宽高
var _slot_size: Vector2 = Vector2(_MAX_SLOT_W, _SLOT_H)
## 跟随鼠标的浮层牌
var _floating: Card = null
## 插入位置预览牌
var _ghost: Card = null
## 上次计算的插入缝下标（用于减少刷新）
var _last_gap: int = -1


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


## 按可用宽度计算 separation 与单槽宽高
func _apply_strip_layout() -> void:
	var n: int = _working.size()
	if n == 0 or _slots == null:
		return
	var inner: float = _slots.size.x
	if inner < 80.0:
		var p := _slots.get_parent() as Control
		if p:
			inner = max(80.0, p.size.x - 8.0)
		else:
			inner = 560.0
	var sep: int = 8
	var w: int = _MAX_SLOT_W
	if n == 1:
		w = clampi(int(inner), _MIN_SLOT_W, _MAX_SLOT_W)
	else:
		for try_sep in range(24, 1, -1):
			sep = try_sep
			var avail_for_cards: float = inner - float((n - 1) * sep)
			w = int(floor(avail_for_cards / float(n)))
			w = clampi(w, _MIN_SLOT_W, _MAX_SLOT_W)
			if float(n * w + (n - 1) * sep) <= inner + 0.5:
				break
		while n * w + (n - 1) * sep > int(inner) and sep > 2:
			sep -= 1
		while n * w + (n - 1) * sep > int(inner) and w > _MIN_SLOT_W:
			w -= 1
	_slots.add_theme_constant_override("separation", sep)
	_slot_size = Vector2(float(w), float(_SLOT_H))
	for ch in _slots.get_children():
		if ch is Control:
			var slot_c := ch as Control
			slot_c.custom_minimum_size = _slot_size
			for grand in slot_c.get_children():
				if grand is Card:
					var gc := grand as Control
					gc.custom_minimum_size = _slot_size
					gc.size = _slot_size


## 全局坐标映射到插入缝 0..n（越界返回 -1）
func _gap_index_at_global(mg: Vector2) -> int:
	var n: int = _working.size()
	if n == 0:
		return -1
	var base := _slots.get_global_rect()
	var r := Rect2(base.position - Vector2(14, 56), base.size + Vector2(28, 112))
	if not r.has_point(mg):
		return -1
	var relx: float = mg.x - base.position.x
	var strip_w: float = max(base.size.x, 1.0)
	var bin: float = relx / strip_w * float(n + 1)
	return clampi(int(floor(bin)), 0, n)


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
		var c := card_scene.instantiate() as Card
		if c:
			c.set_anchors_preset(Control.PRESET_TOP_LEFT)
			c.custom_minimum_size = _slot_size
			c.size = _slot_size
			c.position = Vector2.ZERO
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
	var card := slot.get_child(0) as Card
	var cr := card.get_global_rect()
	_grab_offset = global_press - cr.position
	_floating = card_scene.instantiate() as Card
	_floating.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_floating.set_card(_working[from_idx] as CardResource)
	_floating.custom_minimum_size = _slot_size
	_floating.size = _slot_size
	_floating.set_anchors_preset(Control.PRESET_TOP_LEFT)
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
		_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ghost.custom_minimum_size = _slot_size
		_ghost.size = _slot_size
		_ghost.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_ghost.z_index = _FLOAT_Z - 1
		_ghost.z_as_relative = false
		add_child(_ghost)
	_ghost.custom_minimum_size = _slot_size
	_ghost.size = _slot_size
	_ghost.set_card(_working[_drag_from] as CardResource)
	_ghost.modulate = Color(1, 1, 1, _GHOST_ALPHA)
	_ghost.visible = true
	var x_center: float = _gap_center_x_global(gap)
	var y_top: float = _slots.get_global_rect().position.y
	_ghost.global_position = Vector2(x_center - _ghost.size.x * 0.5, y_top)


## 插入缝中心的全局 X（用于摆 ghost）
func _gap_center_x_global(gap: int) -> float:
	var r := _slots.get_global_rect()
	var n := _working.size()
	if n == 0:
		return r.get_center().x
	if gap <= 0:
		return r.position.x
	if gap >= n:
		return r.position.x + r.size.x
	var left := (_slots.get_child(gap - 1) as Control).get_global_rect().end.x
	var right := (_slots.get_child(gap) as Control).get_global_rect().position.x
	return (left + right) * 0.5
