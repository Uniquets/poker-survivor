extends Node2D
## 单局战斗主场景：选牌开局、HUD、卡时序、摄像机跟随及测试用加牌/排序入口

## 是否显示「添加卡牌」「排序调整」等测试按钮
@export var enable_test_functions: bool = false
## 手牌张数上限（测试加牌用）
@export var max_hand_size: int = 20

@onready var player: CombatPlayer = $Player
@onready var enemy_manager: EnemyManager = $EnemyManager
@onready var card_runtime = $CardRuntime
@onready var auto_attack_system = $AutoAttackSystem
@onready var camera: Camera2D = $Camera2D
@onready var health_bar: ProgressBar = $HUD/HealthBar
@onready var health_label: Label = $HUD/HealthText
@onready var card_hand_ui = $HUD/CardHandUI
@onready var card_select_ui = $HUD/CardSelectUI
@onready var add_card_button: Button = $HUD/AddCardButton
@onready var sort_hand_button: Button = $HUD/SortHandButton
@onready var hand_sort_panel: Control = $HUD/HandSortPanel
@onready var _hud: CanvasLayer = $HUD

## 地图矩形（用于摄像机夹紧）
var _map_bounds := Rect2(Vector2.ZERO, Vector2(CombatTuning.MAP_WIDTH, CombatTuning.MAP_HEIGHT))
## 血条填充样式（便于运行时改色）
var _health_fill_stylebox: StyleBoxFlat
## 是否处于开局/加牌等「选卡 UI」流程（为真时暂停世界、仅 HUD 可点）
var _is_selecting_cards: bool = true

## 开局需选牌总轮数
var _total_selection_count: int = 3
## 当前已完成选牌轮数
var _current_selection_count: int = 0
## 开局阶段已选中的 CardResource 列表
var _selected_cards: Array = []

## 当前与 CardSelectUI 配合的选卡模式（开局三选一 / 加一张 / 无）
enum _CardPickMode { OPENING, ADD_ONE, IDLE }

var _card_pick_mode: _CardPickMode = _CardPickMode.OPENING


## 场景就绪：暂停世界、连信号、初始化血条与选牌 UI
func _ready() -> void:
	# 子节点 _ready 已执行完毕；立刻暂停世界，仅 HUD 可交互（选牌阶段）
	_hud.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	
	player.health_changed.connect(_on_player_health_changed)
	player.died.connect(_on_player_died)
	card_runtime.hand_updated.connect(_on_hand_updated)
	card_runtime.group_played.connect(_on_group_played)
	card_select_ui.card_selected.connect(_on_card_pick_from_ui)
	
	player.set_map_bounds(_map_bounds)
	enemy_manager.target = player
	camera.global_position = player.global_position
	_apply_camera_limits()
	_prepare_health_bar_styles()
	health_bar.max_value = player.max_health
	_refresh_health_ui(player.current_health, player.max_health)
	
	card_hand_ui.visible = false
	card_select_ui.visible = true
	_is_selecting_cards = true
	
	enemy_manager.set_active(false)
	auto_attack_system.process_mode = Node.PROCESS_MODE_DISABLED
	card_runtime.process_mode = Node.PROCESS_MODE_DISABLED
	
	_reset_selection_state()
	
	if add_card_button != null:
		add_card_button.visible = enable_test_functions
		add_card_button.pressed.connect(_on_add_card_button_clicked)
	if sort_hand_button != null:
		sort_hand_button.visible = enable_test_functions
		sort_hand_button.pressed.connect(_on_sort_hand_button_clicked)
	if hand_sort_panel != null:
		hand_sort_panel.sort_saved.connect(_on_hand_sort_overlay_closed)
		hand_sort_panel.sort_cancelled.connect(_on_hand_sort_overlay_closed)
	
	print("[combat] run_started | scene=RunScene")


## 测试：打开手牌排序面板并暂停战斗
func _on_sort_hand_button_clicked() -> void:
	if _is_selecting_cards or card_runtime == null or card_runtime.cards.size() == 0:
		return
	if hand_sort_panel == null:
		return
	hand_sort_panel.open_panel(card_runtime)
	card_hand_ui.visible = false
	add_card_button.visible = false
	if sort_hand_button != null:
		sort_hand_button.visible = false
	_hud.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true


## 排序保存或取消后：恢复暂停、显示手牌与测试按钮
func _on_hand_sort_overlay_closed() -> void:
	get_tree().paused = false
	_hud.process_mode = Node.PROCESS_MODE_INHERIT
	card_hand_ui.visible = true
	if enable_test_functions:
		if add_card_button != null:
			add_card_button.visible = true
		if sort_hand_button != null:
			sort_hand_button.visible = true


## 重置开局选牌状态与 UI 标题
func _reset_selection_state() -> void:
	_selected_cards = []
	_current_selection_count = 0
	_card_pick_mode = _CardPickMode.OPENING
	card_select_ui.set_title("选择卡牌 (%d/%d)" % [_current_selection_count, _total_selection_count])


## 来自选卡 UI 的选中：按当前模式分发给开局或加牌
func _on_card_pick_from_ui(card: CardResource) -> void:
	match _card_pick_mode:
		_CardPickMode.ADD_ONE:
			_complete_add_one_card(card)
		_CardPickMode.OPENING:
			_on_opening_pick(card)
		_:
			pass


## 开局选牌：写入列表、推进轮次或结束开局
func _on_opening_pick(card: CardResource) -> void:
	card_select_ui.finalize_pick_from_current_offer(card)
	_selected_cards.append(card)
	_current_selection_count += 1
	
	print("[ui] card_selected | selection=%d card=%s damage=%d" % [_current_selection_count, card.get_full_name(), card.damage])
	
	if _current_selection_count >= _total_selection_count:
		_finish_selection()
	else:
		card_select_ui.set_title("选择卡牌 (%d/%d)" % [_current_selection_count, _total_selection_count])
		card_select_ui.next_round()


## 开局选满：解除暂停、启动 CardRuntime 与自动战斗
func _finish_selection() -> void:
	_is_selecting_cards = false
	get_tree().paused = false
	_hud.process_mode = Node.PROCESS_MODE_INHERIT
	
	card_select_ui.visible = false
	card_select_ui.disable_selection()
	card_hand_ui.visible = true
	
	print("[ui] finish_selection: selected cards count = %d" % _selected_cards.size())
	for card in _selected_cards:
		print("[ui] finish_selection: card = %s damage=%d" % [card.get_full_name(), card.damage])
	
	card_runtime.cards = _selected_cards
	print("[ui] finish_selection: card_runtime.cards size = %d" % card_runtime.cards.size())
	
	card_runtime.process_mode = Node.PROCESS_MODE_INHERIT
	card_runtime.start_new_run()
	
	enemy_manager.set_active(true)
	auto_attack_system.process_mode = Node.PROCESS_MODE_INHERIT
	auto_attack_system.start_card_system()
	
	card_hand_ui.refresh_display()
	
	_card_pick_mode = _CardPickMode.IDLE
	
	if enable_test_functions and add_card_button != null:
		add_card_button.visible = true
	if enable_test_functions and sort_hand_button != null:
		sort_hand_button.visible = true
	
	print("[ui] selection_complete | total=%d cards=%s" % [_selected_cards.size(), _get_selected_cards_text()])


## 将已选牌名拼成一行日志用字符串
func _get_selected_cards_text() -> String:
	var names = []
	for card in _selected_cards:
		names.append(card.get_full_name())
	return ", ".join(names)


## 每帧：选卡阶段不跟摄像机，否则跟随玩家
func _process(_delta: float) -> void:
	if _is_selecting_cards:
		return
	
	_update_camera_follow()


## 玩家血量变化时刷新血条 UI
func _on_player_health_changed(current_health: int, max_health: int) -> void:
	_refresh_health_ui(current_health, max_health)
	if current_health == max_health:
		return
	print("[combat] hp_changed | current=%d max=%d" % [current_health, max_health])


## 玩家死亡：停怪、停自动攻击与卡时序
func _on_player_died() -> void:
	enemy_manager.set_active(false)
	auto_attack_system.process_mode = Node.PROCESS_MODE_DISABLED
	card_runtime.process_mode = Node.PROCESS_MODE_DISABLED
	print("[combat] run_failed | reason=player_dead")


## 手牌数据变更时打日志（调试用）
func _on_hand_updated() -> void:
	var card_names = []
	for card in card_runtime.cards:
		card_names.append(card.get_full_name())
	print("[cards] hand_updated | cards=%s" % ", ".join(card_names))


## 一组牌打出时打日志（调试用）
func _on_group_played(cards, group_type) -> void:
	var card_names = []
	for card in cards:
		card_names.append(card.get_full_name())
	print("[cards] group_played | type=%s cards=%s" % [group_type, ", ".join(card_names)])


## 摄像机在边距内跟随玩家并限制在地图内
func _update_camera_follow() -> void:
	var next_camera_position := camera.global_position
	var delta := player.global_position - next_camera_position
	if absf(delta.x) > CombatTuning.CAMERA_FOLLOW_MARGIN_X:
		next_camera_position.x = player.global_position.x - signf(delta.x) * CombatTuning.CAMERA_FOLLOW_MARGIN_X
	if absf(delta.y) > CombatTuning.CAMERA_FOLLOW_MARGIN_Y:
		next_camera_position.y = player.global_position.y - signf(delta.y) * CombatTuning.CAMERA_FOLLOW_MARGIN_Y

	var viewport_size := get_viewport_rect().size
	var half_viewport := viewport_size * 0.5
	next_camera_position.x = clampf(next_camera_position.x, _map_bounds.position.x + half_viewport.x, _map_bounds.end.x - half_viewport.x)
	next_camera_position.y = clampf(next_camera_position.y, _map_bounds.position.y + half_viewport.y, _map_bounds.end.y - half_viewport.y)
	camera.global_position = next_camera_position


## 将 Camera2D 硬边界设为地图矩形
func _apply_camera_limits() -> void:
	camera.limit_left = int(_map_bounds.position.x)
	camera.limit_top = int(_map_bounds.position.y)
	camera.limit_right = int(_map_bounds.end.x)
	camera.limit_bottom = int(_map_bounds.end.y)


## 更新血条数值、文字与分段颜色
func _refresh_health_ui(current_health: int, max_health: int) -> void:
	health_bar.max_value = max_health
	health_bar.value = current_health
	health_label.text = "HP %d / %d" % [current_health, max_health]

	var ratio = float(current_health) / max(float(max_health), 1.0)
	if ratio > 0.6:
		_set_health_fill_color(Color(0.2, 0.9, 0.35))
	elif ratio > 0.3:
		_set_health_fill_color(Color(0.95, 0.8, 0.25))
	else:
		_set_health_fill_color(Color(0.95, 0.2, 0.2))


## 复制血条 fill 样式以便运行时改填充色
func _prepare_health_bar_styles() -> void:
	var fill_style := health_bar.get_theme_stylebox("fill")
	if fill_style is StyleBoxFlat:
		_health_fill_stylebox = (fill_style as StyleBoxFlat).duplicate()
		health_bar.add_theme_stylebox_override("fill", _health_fill_stylebox)


## 设置血条填充颜色
func _set_health_fill_color(fill_color: Color) -> void:
	if _health_fill_stylebox != null:
		_health_fill_stylebox.bg_color = fill_color


## 供 UI 查询场景内 CardRuntime 节点
func get_card_runtime():
	return card_runtime


## 测试：从卡池抽三张进入选卡，加入手牌
func _on_add_card_button_clicked() -> void:
	if card_runtime.cards.size() >= max_hand_size:
		print("[test] add_card failed: hand is full (%d/%d)" % [card_runtime.cards.size(), max_hand_size])
		return
	
	var card_pool = get_node("/root/CardPool")
	var random_cards = []
	if card_pool != null:
		random_cards = card_pool.draw_cards(3)
	if random_cards.size() == 0:
		print("[test] add_card failed: card pool is empty")
		return
	
	_card_pick_mode = _CardPickMode.ADD_ONE
	
	card_select_ui.set_title("选择添加的卡牌")
	card_select_ui.show_cards(random_cards)
	card_select_ui.visible = true
	
	card_hand_ui.visible = false
	_is_selecting_cards = true
	
	_hud.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	
	add_card_button.visible = false
	if sort_hand_button != null:
		sort_hand_button.visible = false


## 测试加牌流程结束：池结算、加牌、恢复战斗与按钮
func _complete_add_one_card(card: CardResource) -> void:
	if _card_pick_mode != _CardPickMode.ADD_ONE:
		return
	_card_pick_mode = _CardPickMode.IDLE
	
	card_select_ui.finalize_pick_from_current_offer(card)
	card_runtime.add_card(card)
	print("[test] card added | %s" % card.get_full_name())
	
	get_tree().paused = false
	_hud.process_mode = Node.PROCESS_MODE_INHERIT
	
	card_select_ui.visible = false
	card_hand_ui.visible = true
	_is_selecting_cards = false
	
	if enable_test_functions:
		add_card_button.visible = true
		if sort_hand_button != null:
			sort_hand_button.visible = true
