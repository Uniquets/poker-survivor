extends RefCounted
class_name GroupDetector
## 从左到右在给定起点上取「最长合法组」：与 RULES 优先级一致

## 顺子最少张数
const STRAIGHT_MIN_LENGTH: int = 3
## 是否允许 Q-K-A 作为顺子尾部
const STRAIGHT_ALLOW_QKA: bool = true
## 连对至少包含的对子数
const CONSECUTIVE_PAIRS_MIN: int = 2
## 飞机至少包含的三条组数
const CONSECUTIVE_TRIPS_MIN: int = 2


## 从 start_index 起在候选类型中取最长组，同长比优先级
func find_longest_group(cards: Array, start_index: int) -> Array:
	if start_index >= cards.size():
		return []

	var candidates: Array = []
	
	# 按优先级从高到低检测各种组牌类型
	var four_group = _find_four_of_a_kind(cards, start_index)
	if four_group.size() > 0:
		candidates.append(four_group)
	
	var consecutive_trips = _find_consecutive_trips(cards, start_index)
	if consecutive_trips.size() >= CONSECUTIVE_TRIPS_MIN * 3:
		candidates.append(consecutive_trips)
	
	var three_group = _find_three_of_a_kind(cards, start_index)
	if three_group.size() > 0:
		candidates.append(three_group)
	
	var consecutive_pairs = _find_consecutive_pairs(cards, start_index)
	if consecutive_pairs.size() >= CONSECUTIVE_PAIRS_MIN * 2:
		candidates.append(consecutive_pairs)
	
	var straight_group = _find_longest_straight(cards, start_index)
	if straight_group.size() >= STRAIGHT_MIN_LENGTH:
		candidates.append(straight_group)
	
	var pair_group = _find_pair(cards, start_index)
	if pair_group.size() > 0:
		candidates.append(pair_group)
	
	# 如果没有找到任何组牌，返回单张牌
	if candidates.size() == 0:
		return [cards[start_index]]
	
	# 选择最长的组牌，如果长度相同则按优先级选择
	var longest = candidates[0]
	for candidate in candidates:
		if candidate.size() > longest.size():
			longest = candidate
		elif candidate.size() == longest.size():
			if _get_group_priority(get_group_type(candidate)) > _get_group_priority(get_group_type(longest)):
				longest = candidate
	
	return longest

## 自起点向右取四张同点；不足四张则返回空
func _find_four_of_a_kind(cards: Array, start_index: int) -> Array:
	if start_index + 3 >= cards.size():
		return []
	
	var target_rank = cards[start_index].get_rank_value()
	var group: Array = []
	
	for i in range(start_index, min(start_index + 4, cards.size())):
		if cards[i].get_rank_value() == target_rank:
			group.append(cards[i])
		else:
			break
	
	if group.size() == 4:
		return group
	return []

## 自起点向右取三张同点；不足则空
func _find_three_of_a_kind(cards: Array, start_index: int) -> Array:
	if start_index + 2 >= cards.size():
		return []
	
	var target_rank = cards[start_index].get_rank_value()
	var group: Array = []
	
	for i in range(start_index, min(start_index + 3, cards.size())):
		if cards[i].get_rank_value() == target_rank:
			group.append(cards[i])
		else:
			break
	
	if group.size() == 3:
		return group
	return []

## 起点与下一张是否成对
func _find_pair(cards: Array, start_index: int) -> Array:
	if start_index + 1 >= cards.size():
		return []
	
	var target_rank = cards[start_index].get_rank_value()
	
	if cards[start_index + 1].get_rank_value() == target_rank:
		return [cards[start_index], cards[start_index + 1]]
	return []

## 自起点向右延伸最长连续比较值（含 Q-K-A 特例）
func _find_longest_straight(cards: Array, start_index: int) -> Array:
	if start_index >= cards.size():
		return []
	
	var group: Array = [cards[start_index]]
	var current_value = cards[start_index].get_rank_value()
	var i = start_index + 1
	
	while i < cards.size():
		var next_value = cards[i].get_rank_value()
		
		# 正常连续点数
		if next_value == current_value + 1:
			group.append(cards[i])
			current_value = next_value
			i += 1
		# 特殊处理 Q-K-A 顺子
		elif STRAIGHT_ALLOW_QKA and current_value == 13 and next_value == 14:
			group.append(cards[i])
			current_value = next_value
			i += 1
		else:
			break
	
	return group

## 自起点取连续对子串，长度不足最小要求则空
func _find_consecutive_pairs(cards: Array, start_index: int) -> Array:
	if start_index + 3 >= cards.size():
		return []
	
	var group: Array = []
	var i = start_index
	
	while i < cards.size():
		if i + 1 >= cards.size():
			break
		
		var rank1 = cards[i].get_rank_value()
		var rank2 = cards[i + 1].get_rank_value()
		
		# 不是对子则退出
		if rank1 != rank2:
			break
		
		# 检查是否与前一对连续
		if group.size() > 0:
			var last_rank = group[group.size() - 1].get_rank_value()
			if rank1 != last_rank + 1:
				break
		
		group.append(cards[i])
		group.append(cards[i + 1])
		i += 2
	
	if group.size() >= CONSECUTIVE_PAIRS_MIN * 2:
		return group
	return []

## 自起点取连续三条串，长度不足则空
func _find_consecutive_trips(cards: Array, start_index: int) -> Array:
	if start_index + 5 >= cards.size():
		return []
	
	var group: Array = []
	var i = start_index
	
	while i < cards.size():
		if i + 2 >= cards.size():
			break
		
		var rank1 = cards[i].get_rank_value()
		var rank2 = cards[i + 1].get_rank_value()
		var rank3 = cards[i + 2].get_rank_value()
		
		# 不是三条则退出
		if rank1 != rank2 or rank2 != rank3:
			break
		
		# 检查是否与前三张连续
		if group.size() > 0:
			var last_rank = group[group.size() - 1].get_rank_value()
			if rank1 != last_rank + 1:
				break
		
		group.append(cards[i])
		group.append(cards[i + 1])
		group.append(cards[i + 2])
		i += 3
	
	if group.size() >= CONSECUTIVE_TRIPS_MIN * 3:
		return group
	return []

## 根据已排序 rank 列表判定组类型字符串
func get_group_type(cards: Array) -> String:
	if cards.size() == 0:
		return "NONE"
	
	if cards.size() == 1:
		return "SINGLE"
	
	var ranks: Array = []
	for card in cards:
		ranks.append(card.get_rank_value())
	
	ranks.sort()
	
	if _is_four_of_a_kind(ranks):
		return "FOUR_OF_A_KIND"
	
	if _is_consecutive_trips(ranks):
		return "CONSECUTIVE_TRIPS"
	
	if _is_three_of_a_kind(ranks):
		return "THREE_OF_A_KIND"
	
	if _is_consecutive_pairs(ranks):
		return "CONSECUTIVE_PAIRS"
	
	if _is_pair(ranks):
		return "PAIR"
	
	if _is_straight(ranks):
		return "STRAIGHT"
	
	return "INVALID"

## ranks 是否四张同点
func _is_four_of_a_kind(ranks: Array) -> bool:
	if ranks.size() != 4:
		return false
	return ranks[0] == ranks[1] && ranks[1] == ranks[2] && ranks[2] == ranks[3]

## ranks 是否三张同点
func _is_three_of_a_kind(ranks: Array) -> bool:
	if ranks.size() != 3:
		return false
	return ranks[0] == ranks[1] && ranks[1] == ranks[2]

## ranks 是否对子
func _is_pair(ranks: Array) -> bool:
	if ranks.size() != 2:
		return false
	return ranks[0] == ranks[1]

## ranks 是否合法连对（已排序）
func _is_consecutive_pairs(ranks: Array) -> bool:
	if ranks.size() < CONSECUTIVE_PAIRS_MIN * 2:
		return false
	if ranks.size() % 2 != 0:
		return false
	
	for i in range(0, ranks.size(), 2):
		if i + 1 >= ranks.size():
			return false
		if ranks[i] != ranks[i + 1]:
			return false
		
		if i > 0:
			if ranks[i] != ranks[i - 2] + 1:
				return false
	
	return true

## ranks 是否合法飞机（已排序）
func _is_consecutive_trips(ranks: Array) -> bool:
	if ranks.size() < CONSECUTIVE_TRIPS_MIN * 3:
		return false
	if ranks.size() % 3 != 0:
		return false
	
	for i in range(0, ranks.size(), 3):
		if i + 2 >= ranks.size():
			return false
		if ranks[i] != ranks[i + 1] or ranks[i + 1] != ranks[i + 2]:
			return false
		
		if i > 0:
			if ranks[i] != ranks[i - 3] + 1:
				return false
	
	return true

## ranks 是否顺子（已排序）
func _is_straight(ranks: Array) -> bool:
	if ranks.size() < STRAIGHT_MIN_LENGTH:
		return false
	
	for i in range(1, ranks.size()):
		if ranks[i] != ranks[i-1] + 1:
			# 特殊处理 Q-K-A
			if STRAIGHT_ALLOW_QKA and ranks[i-1] == 13 and ranks[i] == 14:
				continue
			return false
	return true

## 组类型字符串转数字优先级，越大越优先
func _get_group_priority(group_type: String) -> int:
	var priorities = {
		"FOUR_OF_A_KIND": 10,      # 炸弹
		"CONSECUTIVE_TRIPS": 9,    # 飞机
		"THREE_OF_A_KIND": 8,      # 三条
		"CONSECUTIVE_PAIRS": 7,    # 连对
		"STRAIGHT": 6,             # 顺子
		"PAIR": 5,                 # 对子
		"SINGLE": 1,               # 单牌
		"NONE": 0,
		"INVALID": -1
	}
	return priorities.get(group_type, 0)

## 非空且类型非 NONE/INVALID 则有效
func is_valid_group(cards: Array) -> bool:
	if cards.size() == 0:
		return false
	if cards.size() == 1:
		return true
	
	var group_type = get_group_type(cards)
	return group_type != "NONE" && group_type != "INVALID"

## 至少两张且花色全相同
func has_same_suit(cards: Array) -> bool:
	if cards.size() < 2:
		return false
	
	var target_suit = cards[0].suit
	for card in cards:
		if card.suit != target_suit:
			return false
	return true

## 统计 cards 中某花色张数
func get_suit_count(cards: Array, suit: int) -> int:
	var count: int = 0
	for card in cards:
		if card.suit == suit:
			count += 1
	return count

## 组类型字符串转中文展示名
func get_group_type_description(group_type: String) -> String:
	var descriptions = {
		"FOUR_OF_A_KIND": "炸弹",
		"CONSECUTIVE_TRIPS": "飞机",
		"THREE_OF_A_KIND": "三条",
		"CONSECUTIVE_PAIRS": "连对",
		"STRAIGHT": "顺子",
		"PAIR": "对子",
		"SINGLE": "单牌",
		"NONE": "无",
		"INVALID": "无效"
	}
	return descriptions.get(group_type, "未知")