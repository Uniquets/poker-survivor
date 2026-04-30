extends RefCounted
class_name CardPickFlow

# 卡牌拾取模式：OPENING（初始拾取），ADD_ONE（添加单张卡牌），LEVEL_UP（升级卡牌），IDLE（无拾取）
enum PickMode { OPENING, ADD_ONE, LEVEL_UP, IDLE }

# 卡牌选择的标志和计数器
var is_selecting_cards: bool = false  # 当前是否处于选择模式
var total_selection_count: int = 3  # 当前模式下要选择的总卡牌数
var current_selection_count: int = 0  # 目前已选择的卡牌数
var selected_cards: Array = []  # 已选择的卡牌资源列表
var card_pick_mode: PickMode = PickMode.IDLE  # 当前拾取模式
var pending_level_up_card_picks: int = 0  # 排队中的升级拾取数


# 开始初始拾取
func start_opening(total_count: int = 3) -> void:
	total_selection_count = maxi(1, total_count)
	current_selection_count = 0
	selected_cards = []
	card_pick_mode = PickMode.OPENING
	is_selecting_cards = true


# 完成初始卡牌拾取
func complete_opening_pick(card: CardResource) -> bool:
	if card_pick_mode != PickMode.OPENING or card == null:
		return false
	selected_cards.append(card)
	current_selection_count += 1
	return current_selection_count >= total_selection_count


# 结束初始拾取
func finish_opening() -> void:
	card_pick_mode = PickMode.IDLE
	is_selecting_cards = false


# 开始添加单张卡牌拾取
func begin_add_one_pick() -> void:
	card_pick_mode = PickMode.ADD_ONE
	is_selecting_cards = true


# 完成添加单张卡牌拾取
func complete_add_one_pick() -> void:
	card_pick_mode = PickMode.IDLE
	is_selecting_cards = false


# 排队升级卡牌拾取
func queue_level_up_picks(count: int) -> void:
	pending_level_up_card_picks += maxi(0, count)


# 检查是否可以开始待处理的升级拾取
func can_begin_pending_level_up_pick() -> bool:
	return pending_level_up_card_picks > 0 and not is_selecting_cards


# 开始升级卡牌拾取
func begin_level_up_pick() -> bool:
	if pending_level_up_card_picks <= 0:
		return false
	card_pick_mode = PickMode.LEVEL_UP
	is_selecting_cards = true
	return true


# 完成升级卡牌拾取
func complete_level_up_pick() -> bool:
	if card_pick_mode != PickMode.LEVEL_UP:
		return pending_level_up_card_picks > 0
	pending_level_up_card_picks = maxi(0, pending_level_up_card_picks - 1)
	return pending_level_up_card_picks > 0


# 跳过升级卡牌
func skip_level_up_offer() -> bool:
	if card_pick_mode != PickMode.LEVEL_UP:
		return pending_level_up_card_picks > 0
	pending_level_up_card_picks = maxi(0, pending_level_up_card_picks - 1)
	return pending_level_up_card_picks > 0


# 清除升级卡牌拾取队列
func clear_level_up_picks() -> void:
	pending_level_up_card_picks = 0


# 升级后继续
func resume_after_level_up() -> void:
	card_pick_mode = PickMode.IDLE
	is_selecting_cards = false


# 获取已选择卡牌的文本
func selected_cards_text() -> String:
	var names := []
	for card in selected_cards:
		if card != null and card.has_method("get_full_name"):
			names.append(card.get_full_name())
	return ", ".join(names)
