extends Node2D
## 策划表访问（见 `enemy.gd` 说明）

## 单局战斗主场景：选牌开局、HUD、卡时序、摄像机跟随及测试菜单（H：加牌/排序/自选花点）

## 取得 Autoload **`GlobalAudioManager`**；未注册时返回 null
func _global_audio_service() -> Node:
	return get_tree().root.get_node_or_null("GlobalAudioManager") as Node


## 策划表入口：与 `res://config/*.tres` 为同一资源引用，在此检查器修改即写入磁盘；与 `_GC` 预载同源
# @export_group("策划配置")
# @export var player_basics_config: PlayerBasicsConfig = preload("res://config/player_basics_config.tres")
# @export var game_global_config: GameGlobalConfig = preload("res://config/game_global_config.tres")
# @export var enemy_config: EnemyConfig = preload("res://config/enemy_config.tres")
# @export var combat_presentation_defaults: CombatPresentationDefaults = preload("res://config/combat_presentation_defaults.tres")
# @export var card_face_config: CardFaceConfig = preload("res://config/card_face_config.tres")
# @export var card_draw_probability_config: CardDrawProbabilityConfig = preload("res://config/card_draw_probability_config.tres")

## 是否启用测试能力：为真时按 H 打开测试菜单（内含原「添加卡牌」「排序调整」及自选牌）
@export var enable_test_functions: bool = false
## 手牌张数上限（测试加牌用）
@export var max_hand_size: int = 20

@export_group("单位 · 玩家")
## 关卡开始时实例化的玩家预制；根节点须带 **`CombatPlayer`**（通常为 **`CharacterBody2D` + `player.gd`**）
@export var player_scene: PackedScene = preload("res://scenes/player/player.tscn")

@export_group("地牢 · 条带环境")
## 含循环条图、顶底墙与 **`TopWalkableEdge`/`BottomWalkableEdge`** 的节点路径；复制 **`DungeonStripEnvironment.tscn`** 换图后把 **`RunScene`** 下实例改名时，在此改路径指向新子节点
@export var dungeon_strip_node: NodePath = NodePath("DungeonStripEnvironment")

## 选牌 / 排序 / 测试菜单等非常驻 HUD，由 `_setup_transient_hud` 挂到 `CanvasLayer`（场景中仅存战斗常驻条）
const _CARD_SELECT_SCENE := preload("res://scenes/ui/CardSelectUI.tscn")
const _HAND_SORT_SCENE := preload("res://scenes/ui/HandSortPanel.tscn")
const _TEST_MENU_SCENE := preload("res://scenes/ui/TestMenuPanel.tscn")
const _CardPickFlowScript: GDScript = preload("res://scripts/combat/card_pick_flow.gd")
const _RunHudControllerScript: GDScript = preload("res://scripts/ui/run_hud_controller.gd")
const _AddCardUpgradeEffectScript: GDScript = preload("res://scripts/upgrades/add_card_upgrade_effect.gd")

@export_group("奖励池")
## 升级时使用的三选一强化效果池；当前升级加牌会动态包装为 AddCardUpgradeEffect。
@export var level_up_upgrade_pool: Resource = null
## 精英奖励拾取时使用的三选一强化效果池。
@export var elite_upgrade_pool: Resource = preload("res://config/upgrade_offer_pool_elite.tres")

## 由 **`_spawn_player_character`** 在 **`_ready`** 首段写入；根为 **`BattleUnits`** 子节点
var player: CombatPlayer = null
@onready var _battle_units: Node2D = $BattleUnits
@onready var enemy_manager: EnemyManager = $EnemyManager
@onready var card_runtime = $CardRuntime
@onready var auto_attack_system = $AutoAttackSystem
@onready var camera: Camera2D = $Camera2D
@onready var health_bar: TextureProgressBar = $HUD/LayoutRoot/TopLeft/HealthBarCT/HealthBar
@onready var health_label: Label = $HUD/LayoutRoot/TopLeft/HealthBarCT/HealthText
@onready var level_label: Label = $HUD/LayoutRoot/TopLeft/ExpBar/LevelLabel
@onready var exp_bar: TextureProgressBar = $HUD/LayoutRoot/TopLeft/ExpBar
@onready var mix_card_bar: TextureProgressBar = $HUD/LayoutRoot/TopLeft/MixCardBarCT/MixCardBar
@onready var label_wave_timer: Label = $HUD/LayoutRoot/TopCenter/Label_WaveTimer
@onready var label_resource_skull: Label = $HUD/LayoutRoot/TopRight/ResourceVBox/RowSkull/Label_ResourceSkull
@onready var slot_pause_button: TextureButton = $HUD/LayoutRoot/TopRight/Slot_PauseButton
@onready var card_hand_ui = $HUD/LayoutRoot/BottomCenter/CardHandUI
@onready var _hud: CanvasLayer = $HUD
## 常驻 HUD 全屏根（`RunScene` 内血条/手牌等均在其下）；非常驻 UI 作为 `HUD` 的兄弟插在本节点之后以叠在画面上方
@onready var _hud_layout_root: Control = $HUD/LayoutRoot

## 运行时挂到 HUD 的非常驻控件（主场景 `.tscn` 中不保存）
var card_select_ui: Control
## 与 `CardSelectUI.FullDim` 同色；叠在常驻 `LayoutRoot` 之上、选牌 UI 之下，仅测试菜单打开时显示（手牌在 `LayoutRoot` 内，无法用旧版「HUD 下手牌 index」精确定位到牌下层）
var test_menu_full_dim: ColorRect
var hand_sort_panel: Control
var test_menu_panel: Control
var _run_hud: RunHudController = _RunHudControllerScript.new()

## 地图矩形（用于摄像机纵向夹紧与玩家 **`y`** 夹紧）；横向无限时 **`x`** 边界仅作占位，摄像机与玩家横向不夹到此矩形
## 中文：类体不读 **`GameConfig.GAME_GLOBAL`**；首帧由 **`_configure_dungeon_playfield`** 写入（避免与 `GameConfig` 静态初始化循环引用）
var _map_bounds: Rect2 = Rect2()
## 与 **`GameConfig.GAME_GLOBAL.dungeon_horizontal_infinite`** 同步；在 **`_configure_dungeon_playfield`** 写入
var _dungeon_horizontal_infinite: bool = false
var _card_pick_flow: CardPickFlow = _CardPickFlowScript.new()
## 升级选卡时 **`CardSelectUI`** 的 **`z_index`**：须高于底栏 **`CardHandUI`**，否则底部「跳过」键被手牌层盖住
const _CARD_SELECT_Z_ABOVE_HAND: int = 80
## 顶部 HUD 倒计时展示用总秒数（**20 分钟**）；仅展示递减，胜负等逻辑后续再接
const _MATCH_CLOCK_START_SECONDS: float = 20.0 * 60.0

## 剩余展示秒数；在 **`_finish_selection`** 初始化，**`_process`** 中按非暂停递减
var _match_display_seconds: float = _MATCH_CLOCK_START_SECONDS

## 从 PackedScene 实例化选牌、排序、测试菜单及测试菜单全屏压暗层；作为 `HUD` 子节点插在 **`_hud_layout_root`** 之后，避免误用嵌套手牌的 `get_index()`（该 index 相对 `BottomCenter` 而非 `HUD`）
func _setup_transient_hud() -> void:
	card_select_ui = _CARD_SELECT_SCENE.instantiate() as Control
	hand_sort_panel = _HAND_SORT_SCENE.instantiate() as Control
	test_menu_panel = _TEST_MENU_SCENE.instantiate() as Control
	hand_sort_panel.visible = false
	test_menu_panel.visible = false

	test_menu_full_dim = ColorRect.new()
	test_menu_full_dim.name = "TestMenuFullDim"
	test_menu_full_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	test_menu_full_dim.color = Color(0.05, 0.06, 0.1, 0.78)
	test_menu_full_dim.visible = false
	test_menu_full_dim.set_anchors_preset(Control.PRESET_FULL_RECT)

	var insert_after_layout: int = _hud_layout_root.get_index() + 1
	_hud.add_child(card_select_ui)
	_hud.move_child(card_select_ui, insert_after_layout)
	_hud.add_child(test_menu_full_dim)
	_hud.move_child(test_menu_full_dim, insert_after_layout)
	_hud.add_child(hand_sort_panel)
	_hud.add_child(test_menu_panel)
	_run_hud.bind_health(health_bar, health_label)
	_run_hud.bind_progression(level_label, exp_bar)
	_run_hud.bind_mix_card_bar(mix_card_bar)
	_run_hud.bind_match_clock(label_wave_timer)
	_run_hud.bind_kill_count(label_resource_skull)
	_run_hud.bind_hand_overlay(test_menu_full_dim, card_select_ui, card_hand_ui, test_menu_panel)


## 在 **`BattleUnits`** 下从 **`player_scene`** 生成玩家，并对齐 **`PlayerSpawn`**（**`Marker2D`**）世界坐标；失败时 **`push_error`**
func _spawn_player_character() -> void:
	if player_scene == null:
		push_error("RunScene: player_scene 未配置，无法创建玩家")
		return
	var inst: Node = player_scene.instantiate()
	if not inst is CombatPlayer:
		push_error("RunScene: player_scene 根节点须为 CombatPlayer（当前为 %s）" % inst.get_class())
		inst.queue_free()
		return
	player = inst as CombatPlayer
	player.name = "Player"
	_battle_units.add_child(player)
	var spawn_pt: Node2D = _battle_units.get_node_or_null("PlayerSpawn") as Node2D
	if spawn_pt != null and is_instance_valid(spawn_pt):
		player.global_position = spawn_pt.global_position
	else:
		push_warning("RunScene: 未找到 BattleUnits/PlayerSpawn（Marker2D），玩家位置保持预制默认")


## 场景就绪：生成玩家、暂停世界、连信号、初始化血条与选牌 UI
func _ready() -> void:
	GameToolSingleton.bind_world_layer(self)
	_spawn_player_character()
	if player == null:
		return
	_setup_transient_hud()
	_hud.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

	player.health_changed.connect(_on_player_health_changed)
	player.died.connect(_on_player_died)
	player.experience_state_changed.connect(_on_player_experience_state_changed)
	player.leveled_up.connect(_on_player_leveled_up)
	card_runtime.hand_updated.connect(_on_hand_updated)
	card_runtime.group_played.connect(_on_group_played)
	card_select_ui.card_selected.connect(_on_card_pick_from_ui)
	if card_select_ui.has_signal("offer_skipped"):
		card_select_ui.offer_skipped.connect(_on_card_select_offer_skipped)

	_configure_dungeon_playfield()
	_apply_strip_spawn_anchor_world_x()
	camera.global_position = player.global_position
	_apply_camera_limits()
	_refresh_health_ui(player.current_health, player.get_effective_max_health())
	_refresh_progression_ui(player.combat_level, player.get_xp_in_segment(), player.get_xp_needed_this_segment())

	card_hand_ui.visible = false
	card_select_ui.visible = true
	_card_pick_flow.is_selecting_cards = true

	enemy_manager.set_active(false)
	auto_attack_system.process_mode = Node.PROCESS_MODE_DISABLED
	card_runtime.process_mode = Node.PROCESS_MODE_DISABLED

	_reset_selection_state()

	if card_select_ui.has_method("begin_weighted_offer"):
		var lk_opening: float = 0.0
		if player.combat_stats != null:
			lk_opening = player.combat_stats.luck
		card_select_ui.begin_weighted_offer(player.combat_level, lk_opening)

	if test_menu_panel != null:
		test_menu_panel.visible = false
		if enable_test_functions:
			test_menu_panel.add_pool_requested.connect(_on_test_menu_add_pool)
			test_menu_panel.sort_requested.connect(_on_test_menu_sort)
			test_menu_panel.add_custom_requested.connect(_on_test_menu_add_custom)
			test_menu_panel.close_requested.connect(_on_test_menu_close)
			test_menu_panel.crazy_mode_changed.connect(_on_test_menu_crazy_mode_changed)
	if hand_sort_panel != null:
		hand_sort_panel.sort_saved.connect(_on_hand_sort_overlay_closed)
		hand_sort_panel.sort_cancelled.connect(_on_hand_sort_overlay_closed)

	if enemy_manager != null:
		var kill_cb := Callable(self, "_on_enemy_run_kill_count_changed")
		if not enemy_manager.run_kill_count_changed.is_connected(kill_cb):
			enemy_manager.run_kill_count_changed.connect(kill_cb)
	if slot_pause_button != null:
		var pause_cb := Callable(self, "_on_hud_pause_button_pressed")
		if not slot_pause_button.pressed.is_connected(pause_cb):
			slot_pause_button.pressed.connect(pause_cb)

	_match_display_seconds = _MATCH_CLOCK_START_SECONDS
	_refresh_match_clock_label()
	_sync_enemy_manager_match_time()
	_refresh_kill_count_label()
	_init_mix_shuffle_bar()

	_apply_hand_card_overlay_highlight()

	print("[combat] run_started | scene=RunScene")


## 将 **`PlayerSpawn`** 与已生成玩家的 **X** 对齐到 **`DungeonStripEnvironment.get_spawn_anchor_world_x`**（单条条图水平中点），避免出生在横向接缝处
func _apply_strip_spawn_anchor_world_x() -> void:
	var strip: Node = get_node_or_null(dungeon_strip_node)
	if strip == null or not strip.has_method("get_spawn_anchor_world_x"):
		return
	var ax: float = strip.call("get_spawn_anchor_world_x") as float
	var spawn_pt: Node2D = _battle_units.get_node_or_null("PlayerSpawn") as Node2D
	if spawn_pt != null and is_instance_valid(spawn_pt):
		spawn_pt.global_position.x = ax
	if player != null and is_instance_valid(player):
		player.global_position.x = ax


## 同步 **`GameConfig`** 地牢模式：玩家横向夹紧、地图矩形、循环背景/上下墙跟随摄像机、敌人生成用摄像机视口判定
func _configure_dungeon_playfield() -> void:
	var gg: GameGlobalConfig = GameConfig.GAME_GLOBAL
	_dungeon_horizontal_infinite = gg.dungeon_horizontal_infinite
	_map_bounds = Rect2(Vector2.ZERO, Vector2(gg.map_width, gg.map_height))
	player.set_map_bounds(_map_bounds)
	player.set_horizontal_clamp_enabled(not _dungeon_horizontal_infinite)
	var strip: Node = get_node_or_null(dungeon_strip_node)
	if strip != null and strip.has_method("setup_follow_camera"):
		strip.setup_follow_camera(camera)
	enemy_manager.spawn_viewport_camera = camera
	var _ga0: Node = _global_audio_service()
	if _ga0 != null and _ga0.has_method("play_menu_bgm"):
		_ga0.play_menu_bgm()


## 同步测试菜单全屏压暗与手牌逐张提亮：选牌或 H 菜单打开且手牌可见时提亮；`TestMenuFullDim` 在手牌之下，与选牌 FullDim 同逻辑
func _apply_hand_card_overlay_highlight() -> void:
	_run_hud.refresh_hand_card_overlay_highlight(_card_pick_flow.is_selecting_cards)


## 全局按键：H 开关测试菜单（仅 enable_test_functions 且非选卡流程中）
func _unhandled_input(event: InputEvent) -> void:
	if not enable_test_functions:
		return
	if not (event is InputEventKey):
		return
	var ek := event as InputEventKey
	if not ek.pressed or ek.echo:
		return
	if ek.keycode != KEY_H:
		return
	if _card_pick_flow.is_selecting_cards:
		return
	get_viewport().set_input_as_handled()
	if test_menu_panel.visible:
		_close_test_menu_resume()
	else:
		_open_test_menu()


## 打开测试菜单并暂停游戏
func _open_test_menu() -> void:
	if test_menu_panel == null:
		return
	var crazy: bool = enemy_manager.test_crazy_kill_respawn_enabled if enemy_manager != null else false
	test_menu_panel.show_menu(crazy)
	_hud.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_apply_hand_card_overlay_highlight()


## 关闭测试菜单并恢复游戏（未进入子流程时）
func _close_test_menu_resume() -> void:
	if test_menu_panel == null:
		return
	test_menu_panel.hide_menu()
	get_tree().paused = false
	_hud.process_mode = Node.PROCESS_MODE_INHERIT
	_apply_hand_card_overlay_highlight()


## 仅隐藏测试菜单、保持暂停（进入池抽选牌前调用）
func _hide_test_menu_keep_pause() -> void:
	if test_menu_panel != null:
		test_menu_panel.hide_menu()
	_apply_hand_card_overlay_highlight()


## 测试菜单：池抽三选一（关闭菜单 UI 后沿用原加牌流程）
## 测试菜单：疯狂模式开关写入 **`EnemyManager`**
func _on_test_menu_crazy_mode_changed(enabled: bool) -> void:
	if enemy_manager != null:
		enemy_manager.test_crazy_kill_respawn_enabled = enabled


func _on_test_menu_add_pool() -> void:
	_hide_test_menu_keep_pause()
	_start_test_add_card_from_pool()


## 测试菜单：打开排序面板
func _on_test_menu_sort() -> void:
	_hide_test_menu_keep_pause()
	_open_hand_sort_overlay()


## 测试菜单：按花色点数造牌并入手
func _on_test_menu_add_custom(suit: int, rank: int) -> void:
	if card_runtime.cards.size() >= max_hand_size:
		print("[test] add_custom failed: hand full (%d/%d)" % [card_runtime.cards.size(), max_hand_size])
		return
	var pool := get_node_or_null("/root/CardPool")
	if pool == null:
		print("[test] add_custom failed: CardPool missing")
		return
	if not pool.has_method("create_standalone_test_card"):
		print("[test] add_custom failed: CardPool API")
		return
	var card: CardResource = pool.create_standalone_test_card(suit, rank)
	card_runtime.add_card(card)
	print("[test] custom card added | %s" % card.get_full_name())
	if test_menu_panel != null:
		test_menu_panel.hide_menu()
	get_tree().paused = false
	_hud.process_mode = Node.PROCESS_MODE_INHERIT
	card_hand_ui.refresh_display()
	_apply_hand_card_overlay_highlight()


## 测试菜单：关闭按钮
func _on_test_menu_close() -> void:
	_close_test_menu_resume()


## 测试：打开手牌排序面板并暂停战斗
func _open_hand_sort_overlay() -> void:
	if card_runtime == null or card_runtime.cards.size() == 0:
		return
	if hand_sort_panel == null:
		return
	hand_sort_panel.open_panel(card_runtime)
	card_hand_ui.visible = false
	_hud.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true


## 排序保存或取消后：恢复暂停、显示手牌
func _on_hand_sort_overlay_closed() -> void:
	get_tree().paused = false
	_hud.process_mode = Node.PROCESS_MODE_INHERIT
	card_hand_ui.visible = true


## 重置开局选牌状态与 UI 标题
func _reset_selection_state() -> void:
	_card_pick_flow.selected_cards = []
	_card_pick_flow.current_selection_count = 0
	_card_pick_flow.card_pick_mode = CardPickFlow.PickMode.OPENING
	card_select_ui.set_title("选择卡牌 (%d/%d)" % [_card_pick_flow.current_selection_count, _card_pick_flow.total_selection_count])
	if card_select_ui.has_method("set_skip_offer_visible"):
		card_select_ui.set_skip_offer_visible(false)


## 来自选卡 UI 的选中：按当前模式分发给开局或加牌
func _on_card_pick_from_ui(card: CardResource) -> void:
	match _card_pick_flow.card_pick_mode:
		CardPickFlow.PickMode.ADD_ONE:
			_complete_add_one_card(card)
		CardPickFlow.PickMode.LEVEL_UP:
			_complete_level_up_card(card)
		CardPickFlow.PickMode.OPENING:
			_on_opening_pick(card)
		_:
			pass


## 升级选卡界面「跳过」：本轮不拿牌，归还展示牌；待选次数减一，仍有则再抽三张，否则恢复战斗
func _on_card_select_offer_skipped() -> void:
	if _card_pick_flow.card_pick_mode != CardPickFlow.PickMode.LEVEL_UP:
		return
	if not card_select_ui.has_method("finalize_skip_current_offer"):
		return
	card_select_ui.finalize_skip_current_offer()
	_card_pick_flow.pending_level_up_card_picks = maxi(0, _card_pick_flow.pending_level_up_card_picks - 1)
	print("[combat] level_up_card_skipped | pending_after=%d" % _card_pick_flow.pending_level_up_card_picks)
	if _card_pick_flow.pending_level_up_card_picks > 0:
		if card_runtime.cards.size() >= max_hand_size:
			push_warning("[combat] 升级选牌中断：手牌已满，丢弃剩余待选")
			_card_pick_flow.pending_level_up_card_picks = 0
			_resume_after_level_up_card_flow()
			return
		var card_pool := get_node_or_null("/root/CardPool")
		var random_cards: Array = _draw_three_from_pool_weighted(card_pool)
		if random_cards.size() == 0:
			_card_pick_flow.pending_level_up_card_picks = 0
			_resume_after_level_up_card_flow()
			return
		card_select_ui.set_title("升级！请选择一张卡牌（剩余 %d 次）" % _card_pick_flow.pending_level_up_card_picks)
		card_select_ui.show_cards(random_cards)
		return
	_resume_after_level_up_card_flow()


## 开局选牌：写入列表、推进轮次或结束开局
func _on_opening_pick(card: CardResource) -> void:
	card_select_ui.finalize_pick_from_current_offer(card)
	_card_pick_flow.selected_cards.append(card)
	_card_pick_flow.current_selection_count += 1

	print("[ui] card_selected | selection=%d card=%s damage=%d" % [_card_pick_flow.current_selection_count, card.get_full_name(), card.damage])
	var _ga1: Node = _global_audio_service()
	if _ga1 != null and _ga1.has_method("play_card_pick_confirm"):
		_ga1.play_card_pick_confirm()

	if _card_pick_flow.current_selection_count >= _card_pick_flow.total_selection_count:
		_finish_selection()
	else:
		card_select_ui.set_title("选择卡牌 (%d/%d)" % [_card_pick_flow.current_selection_count, _card_pick_flow.total_selection_count])
		card_select_ui.next_round()


## 开局选满：解除暂停、启动 CardRuntime 与自动战斗
func _finish_selection() -> void:
	_card_pick_flow.is_selecting_cards = false
	get_tree().paused = false
	_hud.process_mode = Node.PROCESS_MODE_INHERIT
	var _ga2: Node = _global_audio_service()
	if _ga2 != null and _ga2.has_method("play_default_level_bgm"):
		_ga2.play_default_level_bgm()

	card_select_ui.visible = false
	card_select_ui.disable_selection()
	card_hand_ui.visible = true
	_apply_hand_card_overlay_highlight()

	print("[ui] finish_selection: selected cards count = %d" % _card_pick_flow.selected_cards.size())
	for card in _card_pick_flow.selected_cards:
		print("[ui] finish_selection: card = %s damage=%d" % [card.get_full_name(), card.damage])

	card_runtime.cards = _card_pick_flow.selected_cards
	print("[ui] finish_selection: card_runtime.cards size = %d" % card_runtime.cards.size())

	if enemy_manager != null:
		enemy_manager.reset_run_kill_count()

	card_runtime.process_mode = Node.PROCESS_MODE_INHERIT
	card_runtime.start_new_run()

	_match_display_seconds = _MATCH_CLOCK_START_SECONDS
	_refresh_match_clock_label()
	_sync_enemy_manager_match_time()

	enemy_manager.set_active(true)
	auto_attack_system.process_mode = Node.PROCESS_MODE_INHERIT
	auto_attack_system.start_card_system()

	card_hand_ui.refresh_display()

	_card_pick_flow.card_pick_mode = CardPickFlow.PickMode.IDLE
	card_select_ui.z_index = 0
	if card_select_ui.has_method("set_skip_offer_visible"):
		card_select_ui.set_skip_offer_visible(false)

	print("[ui] selection_complete | total=%d cards=%s" % [_card_pick_flow.selected_cards.size(), _card_pick_flow.selected_cards_text()])

	enemy_manager.apply_spawn_interval_for_player_level(player.combat_level)
	if _card_pick_flow.pending_level_up_card_picks > 0:
		call_deferred("_deferred_try_begin_level_up_pick")


## 供 BOSS 击杀奖励、三选一等调用：永久全局弹道枚数 +1（与 `GlobalAugmentState` 对齐）
func grant_global_permanent_volley_bonus() -> void:
	if is_instance_valid(auto_attack_system):
		auto_attack_system.grant_permanent_volley_plus_one()


## 升级选卡：若当前不在其它选卡流程中则开启暂停与三选一
func _deferred_try_begin_level_up_pick() -> void:
	if _card_pick_flow.pending_level_up_card_picks <= 0:
		return
	if _card_pick_flow.is_selecting_cards:
		return
	_begin_level_up_card_selection()


## 进入升级选牌：暂停战斗与卡时序，从池抽三张展示
func _begin_level_up_card_selection() -> void:
	if _card_pick_flow.pending_level_up_card_picks <= 0:
		return
	if card_runtime.cards.size() >= max_hand_size:
		push_warning("[combat] 升级选牌跳过：手牌已满，清空待选队列")
		_card_pick_flow.pending_level_up_card_picks = 0
		return

	_card_pick_flow.card_pick_mode = CardPickFlow.PickMode.LEVEL_UP
	enemy_manager.set_active(false)
	auto_attack_system.process_mode = Node.PROCESS_MODE_DISABLED
	card_runtime.process_mode = Node.PROCESS_MODE_DISABLED

	var card_pool := get_node_or_null("/root/CardPool")
	var random_cards: Array = _draw_three_from_pool_weighted(card_pool)
	if random_cards.size() == 0:
		push_warning("[combat] 升级选牌失败：卡池为空，清空待选队列")
		_card_pick_flow.pending_level_up_card_picks = 0
		_resume_after_level_up_card_flow()
		return

	card_select_ui.set_title("升级！请选择一张卡牌（剩余 %d 次）" % _card_pick_flow.pending_level_up_card_picks)
	card_select_ui.z_index = _CARD_SELECT_Z_ABOVE_HAND
	card_select_ui.show_cards(random_cards)
	if card_select_ui.has_method("set_skip_offer_visible"):
		card_select_ui.set_skip_offer_visible(true)
	card_select_ui.visible = true
	card_hand_ui.visible = true
	_card_pick_flow.is_selecting_cards = true
	_hud.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_apply_hand_card_overlay_highlight()


## 升级选牌点选后：归还池、加牌；若仍有待选则 `next_round`，否则恢复战斗
func _complete_level_up_card(card: CardResource) -> void:
	if _card_pick_flow.card_pick_mode != CardPickFlow.PickMode.LEVEL_UP:
		return

	card_select_ui.finalize_pick_from_current_offer(card)
	card_runtime.add_card(card)
	print("[combat] level_up_card | card=%s pending_before=%d" % [card.get_full_name(), _card_pick_flow.pending_level_up_card_picks])
	var _ga3: Node = _global_audio_service()
	if _ga3 != null and _ga3.has_method("play_card_pick_confirm"):
		_ga3.play_card_pick_confirm()

	_card_pick_flow.pending_level_up_card_picks = maxi(0, _card_pick_flow.pending_level_up_card_picks - 1)

	if _card_pick_flow.pending_level_up_card_picks > 0:
		if card_runtime.cards.size() >= max_hand_size:
			push_warning("[combat] 升级选牌中断：手牌已满，丢弃剩余待选")
			_card_pick_flow.pending_level_up_card_picks = 0
			_resume_after_level_up_card_flow()
			return
		var card_pool := get_node_or_null("/root/CardPool")
		var random_cards: Array = _draw_three_from_pool_weighted(card_pool)
		if random_cards.size() == 0:
			_card_pick_flow.pending_level_up_card_picks = 0
			_resume_after_level_up_card_flow()
			return
		card_select_ui.set_title("升级！请选择一张卡牌（剩余 %d 次）" % _card_pick_flow.pending_level_up_card_picks)
		card_select_ui.show_cards(random_cards)
		return

	_resume_after_level_up_card_flow()


## 关闭升级选牌 UI 并恢复生成与自动出牌（与测试加牌收尾对称）
func _resume_after_level_up_card_flow() -> void:
	_card_pick_flow.card_pick_mode = CardPickFlow.PickMode.IDLE
	card_select_ui.z_index = 0
	if card_select_ui.has_method("set_skip_offer_visible"):
		card_select_ui.set_skip_offer_visible(false)
	card_select_ui.disable_selection()
	get_tree().paused = false
	_hud.process_mode = Node.PROCESS_MODE_INHERIT
	card_select_ui.visible = false
	card_hand_ui.visible = true
	_card_pick_flow.is_selecting_cards = false
	card_runtime.process_mode = Node.PROCESS_MODE_INHERIT
	auto_attack_system.process_mode = Node.PROCESS_MODE_INHERIT
	enemy_manager.set_active(true)
	card_hand_ui.refresh_display()
	_apply_hand_card_overlay_highlight()


## 经验条与等级文字刷新
func _refresh_progression_ui(level: int, xp_in_segment: int, xp_needed: int) -> void:
	_run_hud.refresh_progression(level, xp_in_segment, xp_needed)


## 玩家经验状态变化（含升级后段长变化）
func _on_player_experience_state_changed(level: int, xp_in_segment: int, xp_needed_this_segment: int) -> void:
	_refresh_progression_ui(level, xp_in_segment, xp_needed_this_segment)


## 玩家升级：刷新刷怪节奏并入队选卡；若正处开局或其它选卡流程则仅排队，结束后由 `_deferred_try_begin_level_up_pick` 接续
func _on_player_leveled_up(levels_gained: int) -> void:
	if levels_gained <= 0:
		return
	_card_pick_flow.pending_level_up_card_picks += levels_gained
	enemy_manager.apply_spawn_interval_for_player_level(player.combat_level)
	if not _card_pick_flow.is_selecting_cards:
		_begin_level_up_card_selection()


## 从卡池抽三张供三选一：使用全局「抽卡概率配置」下的等级段 + 幸运加权
func _draw_three_from_pool_weighted(card_pool: Node) -> Array:
	if card_pool == null:
		return []
	var lk: float = 0.0
	if player.combat_stats != null:
		lk = player.combat_stats.luck
	if card_pool.has_method("draw_cards_for_weighted_offer"):
		return card_pool.draw_cards_for_weighted_offer(3, player.combat_level, lk)
	if card_pool.has_method("draw_cards"):
		return card_pool.draw_cards(3)
	return []


## 每帧：刷新顶部倒计时与洗牌条；选卡阶段不跟摄像机，否则跟随玩家
func _process(delta: float) -> void:
	_update_hud_match_clock(delta)
	_update_hud_mix_shuffle_bar()
	if _card_pick_flow.is_selecting_cards:
		return

	_update_camera_follow()


## 非暂停且非选卡 UI 时递减 **`_match_display_seconds`** 并刷新 **`Label_WaveTimer`**（仅展示）
func _update_hud_match_clock(delta: float) -> void:
	if label_wave_timer == null:
		return
	if get_tree().paused:
		return
	if _card_pick_flow.is_selecting_cards:
		return
	_match_display_seconds = maxf(0.0, _match_display_seconds - delta)
	_refresh_match_clock_label()
	_sync_enemy_manager_match_time()


## 将剩余秒数格式化为 **`MM:SS`**
func _refresh_match_clock_label() -> void:
	_run_hud.refresh_match_clock(_match_display_seconds)


## 将 HUD 倒计时换算成局内已进行秒数，供刷怪时间轴选择当前阶段。
func _sync_enemy_manager_match_time() -> void:
	if enemy_manager == null:
		return
	enemy_manager.set_match_elapsed_seconds(maxf(0.0, _MATCH_CLOCK_START_SECONDS - _match_display_seconds))


## **`MixCardBar`**：与 **`CardRuntime`** 装配阶段 **`assembly_interval`** 对齐
func _init_mix_shuffle_bar() -> void:
	_run_hud.init_mix_shuffle_bar()


## 每帧用 **`CardRuntime.get_shuffle_wait_fill_ratio`** 驱动洗牌条
func _update_hud_mix_shuffle_bar() -> void:
	if card_runtime == null:
		return
	if not card_runtime.has_method("get_shuffle_wait_fill_ratio"):
		return
	var r: float = float(card_runtime.call("get_shuffle_wait_fill_ratio"))
	_run_hud.refresh_mix_shuffle_bar(r)


## 击杀数文案刷新
func _refresh_kill_count_label() -> void:
	if enemy_manager == null:
		return
	_run_hud.refresh_kill_count(enemy_manager.run_kill_count)


## **`EnemyManager.run_kill_count_changed`** 槽
func _on_enemy_run_kill_count_changed(_new_total: int) -> void:
	_refresh_kill_count_label()


## 右上角暂停键：与 **H** 相同条件切换测试菜单
func _on_hud_pause_button_pressed() -> void:
	if not enable_test_functions:
		return
	if _card_pick_flow.is_selecting_cards:
		return
	if test_menu_panel == null:
		return
	if test_menu_panel.visible:
		_close_test_menu_resume()
	else:
		_open_test_menu()


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
	var gg := GameConfig.GAME_GLOBAL
	if absf(delta.x) > gg.camera_follow_margin_x:
		next_camera_position.x = player.global_position.x - signf(delta.x) * gg.camera_follow_margin_x
	if absf(delta.y) > gg.camera_follow_margin_y:
		next_camera_position.y = player.global_position.y - signf(delta.y) * gg.camera_follow_margin_y

	var viewport_size := get_viewport_rect().size
	var half_viewport := viewport_size * 0.5
	if _dungeon_horizontal_infinite:
		next_camera_position.y = clampf(next_camera_position.y, _map_bounds.position.y + half_viewport.y, _map_bounds.end.y - half_viewport.y)
	else:
		next_camera_position.x = clampf(next_camera_position.x, _map_bounds.position.x + half_viewport.x, _map_bounds.end.x - half_viewport.x)
		next_camera_position.y = clampf(next_camera_position.y, _map_bounds.position.y + half_viewport.y, _map_bounds.end.y - half_viewport.y)
	camera.global_position = next_camera_position


## 将 Camera2D 硬边界设为地图矩形；地牢横向无限时仅放开左右 **`limit`**
func _apply_camera_limits() -> void:
	if _dungeon_horizontal_infinite:
		camera.limit_left = -10_000_000
		camera.limit_right = 10_000_000
	else:
		camera.limit_left = int(_map_bounds.position.x)
		camera.limit_right = int(_map_bounds.end.x)
	camera.limit_top = int(_map_bounds.position.y)
	camera.limit_bottom = int(_map_bounds.end.y)


## 更新血条数值与文字（着色由场景中 **`TextureProgressBar`** 的 **`tint_progress`** 等自行配置）
func _refresh_health_ui(current_health: int, max_health: int) -> void:
	_run_hud.refresh_health(current_health, max_health)


## 供 UI 查询场景内 CardRuntime 节点
func get_card_runtime():
	return card_runtime


## 测试：从卡池抽三张进入选卡，加入手牌（可由测试菜单调用）
func _start_test_add_card_from_pool() -> void:
	if card_runtime.cards.size() >= max_hand_size:
		print("[test] add_card failed: hand is full (%d/%d)" % [card_runtime.cards.size(), max_hand_size])
		get_tree().paused = false
		_hud.process_mode = Node.PROCESS_MODE_INHERIT
		return

	var card_pool = get_node("/root/CardPool")
	var random_cards: Array = _draw_three_from_pool_weighted(card_pool)
	if random_cards.size() == 0:
		print("[test] add_card failed: card pool is empty")
		get_tree().paused = false
		_hud.process_mode = Node.PROCESS_MODE_INHERIT
		return

	_card_pick_flow.card_pick_mode = CardPickFlow.PickMode.ADD_ONE
	if card_select_ui.has_method("set_skip_offer_visible"):
		card_select_ui.set_skip_offer_visible(false)

	card_select_ui.set_title("选择添加的卡牌")
	card_select_ui.show_cards(random_cards)
	card_select_ui.visible = true

	card_hand_ui.visible = true
	_card_pick_flow.is_selecting_cards = true

	_hud.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_apply_hand_card_overlay_highlight()


## 测试加牌流程结束：池结算、加牌、恢复战斗
func _complete_add_one_card(card: CardResource) -> void:
	if _card_pick_flow.card_pick_mode != CardPickFlow.PickMode.ADD_ONE:
		return
	_card_pick_flow.card_pick_mode = CardPickFlow.PickMode.IDLE

	card_select_ui.finalize_pick_from_current_offer(card)
	card_runtime.add_card(card)
	print("[test] card added | %s" % card.get_full_name())
	var _ga4: Node = _global_audio_service()
	if _ga4 != null and _ga4.has_method("play_card_pick_confirm"):
		_ga4.play_card_pick_confirm()

	get_tree().paused = false
	_hud.process_mode = Node.PROCESS_MODE_INHERIT

	card_select_ui.visible = false
	card_select_ui.z_index = 0
	card_hand_ui.visible = true
	_card_pick_flow.is_selecting_cards = false

	card_hand_ui.refresh_display()
	_apply_hand_card_overlay_highlight()

	if _card_pick_flow.pending_level_up_card_picks > 0:
		call_deferred("_deferred_try_begin_level_up_pick")
