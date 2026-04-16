extends Node
class_name CardRuntime
## 手牌与自动出牌时序：从左扫描、最长组、组间间隔与装配间隔

## Autoload CardPool 引用（抽牌/还牌/消耗）
var _card_pool: Node = null

## 开局若手牌为空则从池抽的张数
@export var initial_hand_size: int = 3
## 相邻两组牌打出之间的间隔（秒）
@export var base_play_interval: float = 0.5
## 一轮打完最后一组后进入装配/重排的等待时间（秒）
@export var assembly_interval: float = 2.0

## 当前手牌 CardResource 数组（内部存储）
var _cards: Array = []

## 当前从左向右扫描时的起始下标
var current_index: int = 0
## 是否处于「本轮已打完，等待 assembly_interval」阶段
var is_assembling: bool = false
## 用于 base_play_interval / assembly_interval 的累计秒数
var play_timer: float = 0.0

## 单张牌被逻辑打出时发出（与组内遍历相关）
# signal card_played(card, index)
## 一整组牌被识别并打出时发出（含组类型字符串）
signal group_played(cards, group_type)
## 装配阶段结束、指针将回到起点时发出
signal round_ended()
## 手牌数组或顺序变化时发出（UI 刷新）
signal hand_updated()


## 绑定 CardPool 节点引用
func _ready() -> void:
	_card_pool = get_node("/root/CardPool")


## 返回内部手牌数组引用（只读用途请自行勿改写）
func get_cards() -> Array:
	return _cards


## 整体替换手牌并发 hand_updated
func set_cards(new_cards: Array) -> void:
	_cards = new_cards
	emit_signal("hand_updated")
	print("[cards] cards set | count=%d" % _cards.size())


## 手牌数组属性：读写均触发 hand_updated
var cards: Array:
	get:
		return _cards
	set(value):
		_cards = value
		emit_signal("hand_updated")
		print("[cards] cards property set | count=%d" % _cards.size())


## 在末尾加一张牌并重置遍历指针
func add_card(card: CardResource) -> void:
	_cards.append(card)
	_reset_deck_pointer()
	emit_signal("hand_updated")
	print("[cards] card added | total=%d" % _cards.size())


## 按新顺序替换手牌（duplicate 防外部共享引用）并重置指针
func set_cards_order(new_order: Array) -> void:
	_cards = new_order.duplicate()
	_reset_deck_pointer()
	emit_signal("hand_updated")
	print("[cards] cards order updated | count=%d" % _cards.size())


## 手牌顺序变化或加牌后：指针归零并退出装配等待
func _reset_deck_pointer() -> void:
	current_index = 0
	is_assembling = false
	play_timer = 0.0


## 读取指定下标的牌，越界返回 null
func get_card_at(index: int) -> CardResource:
	if index >= 0 and index < _cards.size():
		return _cards[index]
	return null


## 移除指定下标牌并尝试还入卡池
func remove_card_at(index: int) -> void:
	if index >= 0 and index < _cards.size():
		var removed_card = _cards[index]
		_cards.remove_at(index)
		if _card_pool != null:
			_card_pool.return_card(removed_card)
		if current_index >= _cards.size():
			current_index = max(0, _cards.size() - 1)
		emit_signal("hand_updated")


## 初始化内部数组与指针
func _init() -> void:
	cards = []
	current_index = 0


## 开始新一局扫描：指针清零；若无手牌则发初始牌
func start_new_run() -> void:
	current_index = 0
	is_assembling = false
	play_timer = 0.0
	
	if cards.size() == 0:
		_deal_initial_hand()
	else:
		emit_signal("hand_updated")


## 从卡池抽 initial_hand_size 张并 consume 追踪
func _deal_initial_hand() -> void:
	for i in range(initial_hand_size):
		if _card_pool != null:
			var card = _card_pool.draw_card()
			if card != null:
				cards.append(card)
	# 从池抽出的牌在 drawn 中；入手后应消耗追踪，避免与「展示后退回」状态混淆
	if _card_pool != null:
		for c in cards:
			if c is CardResource:
				_card_pool.consume_card(c)
	emit_signal("hand_updated")
	print("[cards] initial hand dealt | count=%d" % cards.size())


## 按规则表计算单张基础伤害（当前与资源 damage 可能并存）
func _calculate_base_damage(card: CardResource) -> int:
	var base: int = card.get_rank_value() - 1
	if card.suit == 1:
		return base + 2
	return base


## 移除指定下标并还池（与 remove_card_at 类似 API）
func remove_card(index: int) -> void:
	if index >= 0 and index < cards.size():
		var removed_card = cards[index]
		cards.remove_at(index)
		if _card_pool != null:
			_card_pool.return_card(removed_card)
		if current_index >= cards.size():
			current_index = max(0, cards.size() - 1)
		emit_signal("hand_updated")


## 在手牌中插入一张牌
func insert_card(card: CardResource, index: int) -> void:
	if index < 0:
		index = 0
	if index > cards.size():
		index = cards.size()
	cards.insert(index, card)
	emit_signal("hand_updated")


## 交换两张牌的位置
func swap_cards(index1: int, index2: int) -> void:
	if index1 >= 0 and index1 < cards.size() and index2 >= 0 and index2 < cards.size():
		var temp = cards[index1]
		cards[index1] = cards[index2]
		cards[index2] = temp
		emit_signal("hand_updated")


## 每帧：装配等待或按间隔打出下一组
func _process(delta: float) -> void:
	if cards.size() == 0:
		return

	if is_assembling:
		play_timer += delta
		if play_timer >= assembly_interval:
			is_assembling = false
			current_index = 0
			play_timer = 0.0
			emit_signal("round_ended")
		return

	play_timer += delta
	if play_timer >= base_play_interval:
		play_timer = 0.0
		_play_current_group()


## 用 GroupDetector 取当前指针最长组并推进指针、发信号
func _play_current_group() -> void:
	if current_index >= cards.size():
		is_assembling = true
		play_timer = 0.0
		return

	var group: Array = GroupDetector.find_longest_group(cards, current_index)
	if group.size() > 0:
		var group_type: String = GroupDetector.get_group_type(group)
		emit_signal("group_played", group, group_type)
		
		# for card in group:
		# 	emit_signal("card_played", card, current_index)
		
		current_index += group.size()
		print("[cards] group_played | type=%s count=%d index=%d" % [group_type, group.size(), current_index])


## 返回当前指针处的牌（未打出前）
func get_current_card() -> CardResource:
	if current_index < cards.size():
		return cards[current_index]
	return null


## 手牌张数
func get_hand_size() -> int:
	return cards.size()


## 是否仍在「尚有未打出组且非装配等待」阶段
func is_round_active() -> bool:
	return not is_assembling and current_index < cards.size()
