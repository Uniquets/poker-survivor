extends RefCounted
class_name GameRules
## 玩法常量与枚举（与 RULES 文档对齐；`RefCounted` + `class_name` 便于全项目静态访问，非场景节点）

const INITIAL_HAND_SIZE: int = 3 ## 默认初始手牌张数
const BASE_PLAY_INTERVAL: float = 0.5 ## 默认出牌间隔（秒）
const ASSEMBLY_INTERVAL: float = 2.0 ## 默认装配/重排间隔（秒）

const STRAIGHT_MIN_LENGTH: int = 3 ## 顺子最少张数
const STRAIGHT_ALLOW_QKA: bool = true ## 是否允许 Q-K-A 作顺子顶端
const ACE_AS_ONE: bool = false ## A 是否可作 1（本规则为否）

const SUIT_THRESHOLD_1: int = 3 ## 全局花色累计阈值档 1
const SUIT_THRESHOLD_2: int = 6 ## 全局花色累计阈值档 2
const SUIT_THRESHOLD_3: int = 9 ## 全局花色累计阈值档 3
const SUIT_THRESHOLD_4: int = 12 ## 全局花色累计阈值档 4

const WIN_TIME_MINUTES: int = 20 ## 胜利相关时间常量占位（分钟）

## 花色枚举（与脚本里 0-3 整数并存的设计占位）
enum Suit {
	SPADES,
	HEARTS,
	DIAMONDS,
	CLUBS
}

## 点数枚举（A=1 与 CardResource.rank 对齐）
enum Rank {
	ACE = 1,
	TWO,
	THREE,
	FOUR,
	FIVE,
	SIX,
	SEVEN,
	EIGHT,
	NINE,
	TEN,
	JACK,
	QUEEN,
	KING
}


## 与 `GroupDetector.get_group_type` 返回值字符串一一对应（`EffectResolver` 等分支用）
enum GroupType {
	NONE,               ## 无组型
	SINGLE,             ## 单张
	PAIR,               ## 对子
	THREE_OF_A_KIND,    ## 三条
	FOUR_OF_A_KIND,     ## 四条
	STRAIGHT,           ## 顺子
	CONSECUTIVE_PAIRS,  ## 连对
	CONSECUTIVE_TRIPS,  ## 连三
	INVALID,            ## 非法组型
	OTHER,              ## 未在检测器协议中的字符串，走默认乘区
}


## 将组类型字符串转为 `GroupType`；未知则 `OTHER`
static func group_type_from_detector_string(s: String) -> int:
	match s:
		"NONE":
			return GroupType.NONE
		"SINGLE":
			return GroupType.SINGLE
		"PAIR":
			return GroupType.PAIR
		"THREE_OF_A_KIND":
			return GroupType.THREE_OF_A_KIND
		"FOUR_OF_A_KIND":
			return GroupType.FOUR_OF_A_KIND
		"STRAIGHT":
			return GroupType.STRAIGHT
		"CONSECUTIVE_PAIRS":
			return GroupType.CONSECUTIVE_PAIRS
		"CONSECUTIVE_TRIPS":
			return GroupType.CONSECUTIVE_TRIPS
		"INVALID":
			return GroupType.INVALID
		_:
			return GroupType.OTHER


## 将 Rank 枚举转为比较用数值（A=14）
static func get_rank_value(rank: Rank) -> int:
	match rank:
		Rank.ACE:
			return 14
		Rank.TWO:
			return 2
		Rank.THREE:
			return 3
		Rank.FOUR:
			return 4
		Rank.FIVE:
			return 5
		Rank.SIX:
			return 6
		Rank.SEVEN:
			return 7
		Rank.EIGHT:
			return 8
		Rank.NINE:
			return 9
		Rank.TEN:
			return 10
		Rank.JACK:
			return 11
		Rank.QUEEN:
			return 12
		Rank.KING:
			return 13
	return 0


## 将 Rank 枚举转为显示用短字符串
static func get_rank_name(rank: Rank) -> String:
	match rank:
		Rank.ACE:
			return "A"
		Rank.TWO:
			return "2"
		Rank.THREE:
			return "3"
		Rank.FOUR:
			return "4"
		Rank.FIVE:
			return "5"
		Rank.SIX:
			return "6"
		Rank.SEVEN:
			return "7"
		Rank.EIGHT:
			return "8"
		Rank.NINE:
			return "9"
		Rank.TEN:
			return "10"
		Rank.JACK:
			return "J"
		Rank.QUEEN:
			return "Q"
		Rank.KING:
			return "K"
	return "?"


## 将 Suit 枚举转为显示用花色符号
static func get_suit_name(suit: Suit) -> String:
	match suit:
		Suit.SPADES:
			return "♠"
		Suit.HEARTS:
			return "♥"
		Suit.DIAMONDS:
			return "♦"
		Suit.CLUBS:
			return "♣"
	return "?"
