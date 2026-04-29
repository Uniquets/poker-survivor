extends Control
class_name CardHandUI
## 底部手牌：`HandFan` 为**无拉伸锚点**的扇形容器，由脚本写 `size`/`position` 实现**水平居中**与**底对齐**；`_dock_shift_y` 仅由悬停/收起驱动；打出组牌**只** tween 各槽 `Nudge` 轻微上弹，不改动 `_dock_shift_y`

## 卡牌场景预制
@export var card_scene: PackedScene
## 最多渲染张数（防极端长手）
@export var max_cards_displayed: int = 20

@export_group("手牌槽")
## 单槽宽（像素），须与 `scenes/ui/Card.tscn` 根节点最小尺寸一致
@export var hand_slot_width: float = 160.0
## 单槽高（像素）
@export var hand_slot_height: float = 240.0

@export_group("扇形布局")
## 少张牌（接近 **`fan_arc_blend_full_at_cards`** 下界）时的枢轴圆半径（像素）；与 **`fan_radius_max_px`** 按张数线性插值，张数 ≥ 该阈值时半径取最大值
@export_range(120.0, 900.0, 5.0) var fan_radius_min_px: float = 420.0
## 手牌张数达到 **`fan_arc_blend_full_at_cards`** 及以上时的枢轴圆半径（像素）；越大同半角下牌间距越疏
@export_range(120.0, 1200.0, 5.0) var fan_radius_max_px: float = 580.0
## 手牌较多时扇形半角（度）上限；少张牌时用 **`fan_arc_half_deg_compact`** 与插值，避免 2～3 张时占满整弧显得过疏
@export_range(6.0, 40.0, 0.5) var fan_arc_half_deg: float = 24.0
## 少张牌（接近 **`fan_arc_blend_full_at_cards`** 下界）时的扇形半角（度）；与 **`fan_arc_half_deg`** 之间按张数插值
@export_range(4.0, 28.0, 0.5) var fan_arc_half_deg_compact: float = 11.0
## 手牌张数 ≥ 此值时半角达到 **`fan_arc_half_deg`**（之间线性插值；须 ≥ 3）
@export_range(3, 30, 1) var fan_arc_blend_full_at_cards: int = 14
## 叠在「牌面自动朝向枢轴」之上的额外倾斜（度），用于整体左旋/右旋微调
@export_range(-30.0, 30.0, 0.1) var fan_tilt_extra_deg: float = 0.0
## 扇区包围盒内边距（像素）
@export_range(0.0, 48.0, 1.0) var fan_bounds_padding: float = 16.0
## 估算竖向占位时，`fan_bounds_padding` 的倍数（越大越不易裁到牌顶）
@export_range(1.0, 5.0, 0.1) var fan_bounds_vertical_pad_factor: float = 3.0
## 扇形容器竖向高度下限（像素），避免张数少时过扁
@export var fan_layout_height_floor_px: float = 280.0
## 最终高度不低于 `H_est * 此比例`（H_est 为几何估算高度）
@export_range(0.15, 0.8, 0.01) var fan_height_min_ratio_of_est: float = 0.35
## 超过 3 张后，在包围盒宽度之外每多一张至少再放宽的像素（与缩小角间距并行，避免「只挤不换行宽」）
@export_range(0.0, 48.0, 1.0) var fan_width_expand_per_card_after_three_px: float = 14.0

@export_group("整体 dock")
## 鼠标在手牌热区内、动画结束后 **`_dock_shift_y`** 的目标值（像素）。`_hand_fan.position.y = size.y - fh + _dock_shift_y`，**负值**表示相对「底边对齐」基准整体**更靠上**，用于固定「弹出后停在哪」
@export_range(-220.0, 80.0, 1.0) var dock_hand_shift_y_hover_px: float = 0.0
## 非悬停收起时，在 **`dock_hand_shift_y_hover_px`** 之上再整体**向下**多移的像素，即收起与悬停间 **`_dock_shift_y`** 的差值（进出热区的行程）
@export_range(0.0, 320.0, 1.0) var dock_hover_raise_px: float = 125.0
## 收起/展开平移动画时长（秒）
@export var dock_tween_sec: float = 0.22

@export_group("悬停热区")
## 热区左右扩展（像素）
@export_range(0.0, 120.0, 1.0) var hover_pad_x: float = 32.0
## 热区向上扩展 = **当前张数插值后的半径** * 此系数 + `hover_pad_top_add_px`（与摆扇半径一致）
@export_range(0.0, 0.35, 0.01) var hover_pad_top_radius_mul: float = 0.12
@export var hover_pad_top_add_px: float = 40.0
## 热区向下扩展（像素）
@export_range(0.0, 120.0, 1.0) var hover_pad_bottom: float = 36.0

@export_group("打出 · 轻微上弹")
## 打出时相对槽内 `Nudge` 本地坐标的垂直位移（负为向上）
@export_range(-24.0, 0.0, 0.5) var play_rise_pixels: float = -5.0
## 打出高亮上升段时长（秒）
@export_range(0.05, 0.6, 0.01) var play_tween_up_sec: float = 0.2
## 打出回落段时长（秒）
@export_range(0.05, 0.6, 0.01) var play_tween_down_sec: float = 0.2
## 打出瞬间对 `Card.modulate` 的着色（高亮）
@export var play_pulse_modulate: Color = Color(5, 5, 0.55)

@export_group("选牌/压暗叠层")
## 选牌或测试菜单压暗时，每张牌 `self_modulate` 提亮系数
@export var overlay_hand_card_self_modulate: Color = Color(1.14, 1.15, 1.2, 1.0)

@onready var _hand_fan: Control = $HandFan

var _card_runtime = null
var _card_elements: Array = []
var _activation_cleanup_timer: Timer = null
var _overlay_glow_active: bool = false
## 鼠标是否希望手牌整体上移（全露）
var _hover_wants_raise: bool = false
var _activation_busy: int = 0
var _dock_tween: Tween = null
## 相对「底对齐全露」位置整体向下平移的像素；0 为全露，越大越下沉（收起态）
var _dock_shift_y: float = 0.0


## 初始化定时器；`HandFan` 不用底锚，避免引擎覆盖 `position`
func _ready() -> void:
	_activation_cleanup_timer = Timer.new()
	_activation_cleanup_timer.one_shot = true
	_activation_cleanup_timer.timeout.connect(_update_hand_display)
	add_child(_activation_cleanup_timer)
	call_deferred("_deferred_init")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		if _card_elements.size() > 0:
			call_deferred("_deferred_relayout_fan_only")


func _deferred_relayout_fan_only() -> void:
	if not is_instance_valid(_hand_fan) or _card_elements.is_empty():
		return
	_layout_fan_slots(_card_elements.size())


## 鼠标在手牌全局热区内则整体上移，离开则移回（与打出 `Nudge` tween 并行；**不因** **`_activation_busy`** 暂停，否则打出牌型时热区整体升降失效）
func _process(_delta: float) -> void:
	if not is_visible_in_tree() or _hand_fan == null:
		return
	if _card_runtime == null:
		return
	var want := _is_mouse_in_hand_hover_zone()
	if want == _hover_wants_raise:
		return
	_hover_wants_raise = want
	_tween_dock_towards_hover(want)


func _deferred_init() -> void:
	_find_card_runtime()
	_update_hand_display()


func _find_card_runtime() -> void:
	var root = get_tree()
	if root == null:
		return
	var run_scene = root.get_current_scene()
	if run_scene == null:
		return
	if run_scene.has_method("get_card_runtime"):
		_card_runtime = run_scene.get_card_runtime()
		if _card_runtime != null:
			_card_runtime.hand_updated.connect(_on_hand_updated)
			_card_runtime.group_played.connect(_on_group_played)


func _on_hand_updated() -> void:
	_update_hand_display()


## 组牌打出：仅对区间内每张牌做 `Nudge` 轻微上弹，**不改变** `_dock_shift_y`（避免整手整体上移）
func _on_group_played(_group_cards: Array, _group_type: String) -> void:
	if _card_runtime == null:
		return
	var start: int = _card_runtime.current_index
	var end: int = start + _group_cards.size()
	_play_group_activation_tween(start, end)


func _play_group_activation_tween(start: int, end: int) -> void:
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
		_activate_card_tween(nudge, c)


## 仅在槽的 `Nudge` 本地坐标上位移，父级 `_dock_shift_y` 不影响该相对动画
func _activate_card_tween(nudge: Control, c: Control) -> bool:
	if nudge == null or c == null or not is_instance_valid(nudge) or not is_instance_valid(c):
		return false
	var ox: float = nudge.position.x
	var base_y: float = nudge.position.y
	_activation_busy += 1
	var tw := c.create_tween()
	tw.set_parallel(true)
	tw.tween_property(c, "modulate", play_pulse_modulate, play_tween_up_sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(nudge, "position", Vector2(ox, base_y + play_rise_pixels), play_tween_up_sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.chain()
	tw.set_parallel(false)
	tw.tween_property(c, "modulate", Color.WHITE, play_tween_down_sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(nudge, "position", Vector2(ox, base_y), play_tween_down_sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.finished.connect(_on_activation_tween_finished, CONNECT_ONE_SHOT)
	return true


func _on_activation_tween_finished() -> void:
	_activation_busy = maxi(0, _activation_busy - 1)
	if _activation_busy > 0:
		return
	if _is_mouse_in_hand_hover_zone():
		_hover_wants_raise = true
		_tween_dock_towards_hover(true)
	else:
		_hover_wants_raise = false
		_tween_dock_towards_hover(false)


func _update_hand_display() -> void:
	_kill_dock_tween()
	## 重建手牌时会 **`queue_free`** 槽内节点，进行中的打出 tween 被引擎杀掉且**不会**触发 **`finished`**；若不把计数清零，**`_activation_busy` 会永久 > 0**，**`_process`** 永远跳过悬停 dock
	_activation_busy = 0
	if _card_runtime == null:
		while _card_elements.size() > 0:
			var el = _card_elements.pop_back()
			if is_instance_valid(el):
				el.queue_free()
		_hover_wants_raise = false
		_apply_dock_shift(0.0)
		_shrink_hand_fan_empty()
		return

	var cards = _card_runtime.cards
	if cards.size() == 0:
		while _card_elements.size() > 0:
			var el0 = _card_elements.pop_back()
			if is_instance_valid(el0):
				el0.queue_free()
		_hover_wants_raise = false
		_apply_dock_shift(0.0)
		_shrink_hand_fan_empty()
		return

	while _card_elements.size() > 0:
		var element = _card_elements.pop_back()
		if is_instance_valid(element):
			element.queue_free()

	var display_count: int = mini(cards.size(), max_cards_displayed)
	for i in range(display_count):
		var card = cards[i]
		var slot_ctrl = _create_card_element(card, i)
		if slot_ctrl != null:
			_card_elements.append(slot_ctrl)
			_hand_fan.add_child(slot_ctrl)

	_layout_fan_slots(display_count)
	_sync_hand_card_overlay_glow()
	if _activation_busy <= 0:
		_apply_dock_shift(dock_hand_shift_y_hover_px if _hover_wants_raise else _collapse_shift_px())


func set_hand_card_overlay_glow(on: bool) -> void:
	_overlay_glow_active = on
	_sync_hand_card_overlay_glow()


func _sync_hand_card_overlay_glow() -> void:
	var target: Color = overlay_hand_card_self_modulate if _overlay_glow_active else Color.WHITE
	for slot: Control in _card_elements:
		if slot == null or not is_instance_valid(slot):
			continue
		if slot.get_child_count() < 1:
			continue
		var nudge: Control = slot.get_child(0) as Control
		if nudge == null or nudge.get_child_count() < 1:
			continue
		var c: Card = nudge.get_child(0) as Card
		if c == null or not is_instance_valid(c):
			continue
		c.self_modulate = target


func _create_card_element(card: CardResource, index: int) -> Control:
	if card_scene == null:
		card_scene = load("res://scenes/ui/Card.tscn")

	var slot_size := Vector2(hand_slot_width, hand_slot_height)
	var slot := Control.new()
	slot.custom_minimum_size = slot_size
	slot.size = slot_size
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.name = "HandSlot_%d" % index

	var nudge := Control.new()
	nudge.name = "Nudge"
	nudge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nudge.set_anchors_preset(Control.PRESET_FULL_RECT)
	nudge.offset_left = 0
	nudge.offset_top = 0
	nudge.offset_right = 0
	nudge.offset_bottom = 0
	nudge.position = Vector2.ZERO

	var element := card_scene.instantiate() as Card
	if element == null:
		return null
	element.set_anchors_preset(Control.PRESET_FULL_RECT)
	element.offset_left = 0
	element.offset_top = 0
	element.offset_right = 0
	element.offset_bottom = 0
	element.set_card(card)

	nudge.add_child(element)
	slot.add_child(nudge)
	return slot


func get_card_count() -> int:
	if _card_runtime == null:
		return 0
	return _card_runtime.cards.size()


func refresh_display() -> void:
	_update_hand_display()


## 摆扇并在 `HandFan` 内水平居中内容；最后写 `HandFan.size` 并 `_reposition_hand_fan`
func _layout_fan_slots(n: int) -> void:
	if n <= 0 or _hand_fan == null:
		return
	var W_parent: float = maxf(32.0, size.x)
	var half_arc: float = _compute_fan_half_arc_rad_for_count(n)
	var R: float = _compute_fan_radius_for_count(n)
	var H_est: float = R * (1.0 - cos(half_arc)) + hand_slot_height + fan_bounds_padding * fan_bounds_vertical_pad_factor
	var H: float = maxf(fan_layout_height_floor_px, H_est)
	var cx: float = W_parent * 0.5
	var pivot_y: float = H - hand_slot_height * 0.5 + R
	var pivot := Vector2(cx, pivot_y)

	for i in range(n):
		if i >= _card_elements.size():
			break
		var slot: Control = _card_elements[i] as Control
		if slot == null:
			continue
		var u: float = 0.5 if n <= 1 else float(i) / float(n - 1)
		var theta: float = lerpf(-half_arc, half_arc, u)
		var center := pivot + Vector2(R * sin(theta), -R * cos(theta))
		slot.pivot_offset = Vector2(hand_slot_width * 0.5, hand_slot_height * 0.5)
		var to_pivot: Vector2 = pivot - center
		if to_pivot.length_squared() < 0.0001:
			slot.rotation = 0.0
		else:
			var v: Vector2 = to_pivot.normalized()
			slot.rotation = v.angle() - PI * 0.5 + deg_to_rad(fan_tilt_extra_deg)
		slot.position = center - slot.pivot_offset
		if slot.get_child_count() >= 1:
			var nudge: Control = slot.get_child(0) as Control
			if nudge != null:
				nudge.position = Vector2.ZERO

	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for j in range(n):
		var s: Control = _card_elements[j] as Control
		if s == null:
			continue
		var corners: Array[Vector2] = [
			Vector2.ZERO,
			Vector2(s.size.x, 0.0),
			Vector2(s.size.x, s.size.y),
			Vector2(0.0, s.size.y),
		]
		var xf := Transform2D(s.rotation, s.position)
		for corner in corners:
			var p: Vector2 = xf * corner
			mn.x = minf(mn.x, p.x)
			mn.y = minf(mn.y, p.y)
			mx.x = maxf(mx.x, p.x)
			mx.y = maxf(mx.y, p.y)

	var pad := fan_bounds_padding
	var shift := Vector2(pad - mn.x, pad - mn.y)
	if shift.length_squared() > 0.0001:
		for j2 in range(n):
			var s2: Control = _card_elements[j2] as Control
			if s2 != null:
				s2.position += shift
		mn += shift
		mx += shift

	var cw: float = mx.x - mn.x
	var fan_w: float = maxf(W_parent, ceil(mx.x + pad))
	var dx: float = (fan_w - cw) * 0.5 - mn.x
	if absf(dx) > 0.01:
		for j3 in range(n):
			var s3: Control = _card_elements[j3] as Control
			if s3 != null:
				s3.position.x += dx
		mn.x += dx
		mx.x += dx

	var fan_h: float = maxf(ceil(mx.y + pad), H_est * fan_height_min_ratio_of_est)
	var extra_w: float = maxf(0.0, float(n - 3)) * fan_width_expand_per_card_after_three_px
	var fan_w_final: float = fan_w + extra_w
	if extra_w > 0.01:
		var dx_extra: float = extra_w * 0.5
		for j4 in range(n):
			var s4: Control = _card_elements[j4] as Control
			if s4 != null:
				s4.position.x += dx_extra
	_hand_fan.size = Vector2(fan_w_final, fan_h)
	_hand_fan.custom_minimum_size = _hand_fan.size
	_reposition_hand_fan()


## 按张数在 **`fan_arc_half_deg_compact`** 与 **`fan_arc_half_deg`** 之间取半角（弧度）；少张紧凑、多张逐步放开弧长并与水平加宽配合
func _compute_fan_half_arc_rad_for_count(n: int) -> float:
	var lo: float = deg_to_rad(clampf(fan_arc_half_deg_compact, 1.0, fan_arc_half_deg))
	var hi: float = deg_to_rad(fan_arc_half_deg)
	if n <= 1:
		return 0.0
	var n_full: int = maxi(3, fan_arc_blend_full_at_cards)
	var denom: float = float(max(1, n_full - 2))
	var t: float = clampf((float(n) - 2.0) / denom, 0.0, 1.0)
	return lerpf(lo, hi, t)


## 按张数在 **`fan_radius_min_px`** 与 **`fan_radius_max_px`** 之间插值（与半角共用 **`fan_arc_blend_full_at_cards`** 的 t，保证弧与半径同步放开）；`n<=1` 取最小半径
func _compute_fan_radius_for_count(n: int) -> float:
	var r_lo: float = minf(fan_radius_min_px, fan_radius_max_px)
	var r_hi: float = maxf(fan_radius_min_px, fan_radius_max_px)
	if n <= 1:
		return r_lo
	var n_full: int = maxi(3, fan_arc_blend_full_at_cards)
	var denom: float = float(max(1, n_full - 2))
	var t: float = clampf((float(n) - 2.0) / denom, 0.0, 1.0)
	return lerpf(r_lo, r_hi, t)


func _shrink_hand_fan_empty() -> void:
	if _hand_fan == null:
		return
	_hand_fan.size = Vector2(64.0, 8.0)
	_hand_fan.custom_minimum_size = _hand_fan.size
	_reposition_hand_fan()


## 将 `HandFan` 底边贴 `CardHandUI` 底边，水平居中；`_dock_shift_y` 在收起时整体下移
func _reposition_hand_fan() -> void:
	if _hand_fan == null:
		return
	var fw: float = _hand_fan.size.x
	var fh: float = _hand_fan.size.y
	if fw < 1.0 or fh < 1.0:
		return
	_hand_fan.position.x = (size.x - fw) * 0.5
	_hand_fan.position.y = size.y - fh + _dock_shift_y


## 收起态 **`_dock_shift_y`**：悬停基准下移 **`dock_hover_raise_px`**（与 **`dock_hand_shift_y_hover_px`** 解耦，便于单独调「弹出后位置」与「行程」）
func _collapse_shift_px() -> float:
	return dock_hand_shift_y_hover_px + maxf(0.0, dock_hover_raise_px)


## 写入 dock 偏移并立刻重算 `HandFan` 在父控件内的位置（无 tween）
func _apply_dock_shift(v: float) -> void:
	_dock_shift_y = v
	_reposition_hand_fan()


func _tween_dock_towards_hover(raised: bool) -> void:
	if _hand_fan == null:
		return
	_kill_dock_tween()
	var target: float = dock_hand_shift_y_hover_px if raised else _collapse_shift_px()
	var tw := create_tween()
	_dock_tween = tw
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(_apply_dock_shift, _dock_shift_y, target, dock_tween_sec)


func _kill_dock_tween() -> void:
	if _dock_tween != null and is_instance_valid(_dock_tween):
		_dock_tween.kill()
	_dock_tween = null


func _is_mouse_in_hand_hover_zone() -> bool:
	var hr: Rect2 = _hand_fan.get_global_rect()
	if hr.size.x <= 1.0 or hr.size.y <= 1.0:
		return false
	var pad_x: float = hover_pad_x
	var n_hover: int = _card_elements.size()
	var R_hover: float = _compute_fan_radius_for_count(n_hover)
	var pad_top: float = R_hover * hover_pad_top_radius_mul + hover_pad_top_add_px
	var pad_bot: float = hover_pad_bottom
	hr = hr.grow_individual(pad_x, pad_top, pad_x, pad_bot)
	return hr.has_point(get_global_mouse_position())
