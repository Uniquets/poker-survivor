extends Control
## 测试菜单 UI：由 RunScene 在 `enable_test_functions` 且按 H 时显示；暂停游戏期间仍响应输入（process_mode=ALWAYS）

## 请求从牌池抽三张选一加入手牌（与旧「添加卡牌」一致）
signal add_pool_requested()
## 请求打开手牌排序面板
signal sort_requested()
## 请求将当前下拉框所选花色、点数生成牌并加入手牌
signal add_custom_requested(suit: int, rank: int)
## 请求关闭菜单（不发起子流程时由 RunScene 解除暂停）
signal close_requested()
## 测试「疯狂模式」勾选变化（由 RunScene 写入 **`EnemyManager.test_crazy_kill_respawn_enabled`**）
signal crazy_mode_changed(enabled: bool)

@onready var _crazy_check: CheckBox = $Center/Panel/VBox/RowCrazy/CrazyModeCheck
@onready var _btn_pool: Button = $Center/Panel/VBox/RowPoolSort/BtnAddPool
@onready var _btn_sort: Button = $Center/Panel/VBox/RowPoolSort/BtnSort
@onready var _suit_option: OptionButton = $Center/Panel/VBox/RowSuit/SuitOption
@onready var _rank_option: OptionButton = $Center/Panel/VBox/RowRank/RankOption
@onready var _btn_custom: Button = $Center/Panel/VBox/BtnAddCustom
@onready var _btn_close: Button = $Center/Panel/VBox/BtnClose


## 填充花色、点数下拉项并联信号
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_fill_suit_options()
	_fill_rank_options()
	_btn_pool.pressed.connect(func () -> void: emit_signal("add_pool_requested"))
	_btn_sort.pressed.connect(func () -> void: emit_signal("sort_requested"))
	_btn_custom.pressed.connect(_on_add_custom_pressed)
	_btn_close.pressed.connect(func () -> void: emit_signal("close_requested"))
	_crazy_check.toggled.connect(_on_crazy_mode_toggled)


## 写入四种花色显示名（下标 0–3 即 CardResource.suit）
func _fill_suit_options() -> void:
	_suit_option.clear()
	_suit_option.add_item("黑桃 ♠")
	_suit_option.add_item("红心 ♥")
	_suit_option.add_item("方块 ♦")
	_suit_option.add_item("梅花 ♣")
	_suit_option.select(0)


## 写入 A—K 十三种点数；选中下标 i 对应 rank = i + 1（CardResource.rank）
func _fill_rank_options() -> void:
	_rank_option.clear()
	var names: PackedStringArray = PackedStringArray(["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"])
	for i in range(names.size()):
		_rank_option.add_item(names[i])
	_rank_option.select(1)


## 读取当前下拉选中：花色下标 0–3、点数 rank 1–13
func _on_add_custom_pressed() -> void:
	var suit_idx: int = clampi(_suit_option.get_selected(), 0, 3)
	var rank_id: int = clampi(_rank_option.get_selected() + 1, 1, 13)
	emit_signal("add_custom_requested", suit_idx, rank_id)


## 疯狂模式勾选：转发给 RunScene 同步 **`EnemyManager`**
func _on_crazy_mode_toggled(pressed: bool) -> void:
	emit_signal("crazy_mode_changed", pressed)


## 由 RunScene 调用：显示全屏菜单（不改变本节点 pause 行为，由场景树 paused 控制世界）；**`crazy_mode_current`** 与 **`EnemyManager`** 勾选状态对齐
func show_menu(crazy_mode_current: bool = false) -> void:
	visible = true
	_crazy_check.set_pressed_no_signal(crazy_mode_current)


## 由 RunScene 调用：隐藏菜单
func hide_menu() -> void:
	visible = false
