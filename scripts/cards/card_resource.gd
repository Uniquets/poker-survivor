extends Resource
class_name CardResource
## 单张扑克牌数据资源：花色、点数、伤害与可选纹理

## 花色 0-3：黑桃、红心、方块、梅花
@export var suit: int = 0
## 点数 1-13：A-K
@export var rank: int = 1
## 用于战斗结算的伤害值
@export var damage: int = 1
## 速度系数（预留）
@export var speed: float = 1.0
## 卡牌描述文案
@export var description: String = ""

## 卡面正面纹理
@export var front_texture: Texture2D
## 卡背纹理
@export var back_texture: Texture2D


## 构造：指定花色与点数
func _init(suit_value: int = 0, rank_value: int = 1) -> void:
	self.suit = suit_value
	self.rank = rank_value


## 花色缩写字母（S/H/D/C）
func get_suit_name() -> String:
	match suit:
		0:
			return "S"
		1:
			return "H"
		2:
			return "D"
		3:
			return "C"
	return "?"


## 点数显示字符（A、2…K）
func get_rank_name() -> String:
	match rank:
		1:
			return "A"
		2:
			return "2"
		3:
			return "3"
		4:
			return "4"
		5:
			return "5"
		6:
			return "6"
		7:
			return "7"
		8:
			return "8"
		9:
			return "9"
		10:
			return "10"
		11:
			return "J"
		12:
			return "Q"
		13:
			return "K"
	return "?"


## 花色缩写 + 点数，用于日志
func get_full_name() -> String:
	return get_suit_name() + get_rank_name()


## 比较用点数：A 视为 14
func get_rank_value() -> int:
	if rank == 1:
		return 14
	return rank


## 浅拷贝主要字段（非 Resource.duplicate 语义时可用）
func clone() -> CardResource:
	var copy: CardResource = CardResource.new()
	copy.suit = suit
	copy.rank = rank
	copy.damage = damage
	copy.speed = speed
	copy.description = description
	return copy
