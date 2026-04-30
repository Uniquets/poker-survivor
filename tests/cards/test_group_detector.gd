extends RefCounted

const TestSupport = preload("res://tests/test_support.gd")


## 创建一张测试牌；花色默认为黑桃，伤害固定为点数值，便于失败输出排查。
static func _card(rank: int, suit: int = 0) -> CardResource:
	var c := CardResource.new(suit, rank)
	c.damage = rank
	return c


## 断言从指定起点识别出的组牌类型与长度。
static func _assert_group(cards: Array, expected_type: String, expected_size: int, label: String) -> void:
	var group: Array = GroupDetector.find_longest_group(cards, 0)
	TestSupport.assert_eq(group.size(), expected_size, "%s size" % label)
	TestSupport.assert_eq(GroupDetector.get_group_type(group), expected_type, "%s type" % label)


## Q-K-A 应作为合法顶端顺子。
static func test_qka_is_valid_straight() -> void:
	_assert_group([_card(12), _card(13), _card(1)], "STRAIGHT", 3, "QKA")


## A-2-3 不允许把 A 当 1，必须退化为单张。
static func test_a23_falls_back_to_single() -> void:
	_assert_group([_card(1), _card(2), _card(3)], "SINGLE", 1, "A23")


## 两张同点数应识别为对子。
static func test_pair_detected() -> void:
	_assert_group([_card(7), _card(7)], "PAIR", 2, "pair")


## 三张同点数应识别为三条。
static func test_three_of_a_kind_detected() -> void:
	_assert_group([_card(7), _card(7), _card(7)], "THREE_OF_A_KIND", 3, "triple")


## 四张同点数应识别为四条。
static func test_four_of_a_kind_detected() -> void:
	_assert_group([_card(7), _card(7), _card(7), _card(7)], "FOUR_OF_A_KIND", 4, "four")


## 当前规则锁定起点连续扫描行为：5,5,6,7,8 从起点先形成对子，后续 6-8 不跨过对子重组。
static func test_longest_group_wins_over_pair() -> void:
	_assert_group([_card(5), _card(5), _card(6), _card(7), _card(8)], "PAIR", 2, "left anchored pair")
