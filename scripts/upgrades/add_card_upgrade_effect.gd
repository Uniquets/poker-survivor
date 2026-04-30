extends "res://scripts/upgrades/upgrade_effect.gd"
class_name AddCardUpgradeEffect
## 加牌强化效果：把配置的卡加入当前牌组。

## 要加入的卡牌；为空时不会生效。
@export var card: CardResource = null


## 初始化默认展示文本，运行时可被具体卡牌名称覆盖。
func _init() -> void:
	title = "拾取卡牌"
	description = "加入当前牌组"


## 返回需要用原卡牌样式展示的卡牌。
func get_display_card() -> CardResource:
	return card


## 将配置卡加入当前 CardRuntime，并可选通知 CardPool 消耗该卡。
func apply_to_run(card_runtime: CardRuntime, _run_scene: Node, card_pool: Node) -> void:
	if card_runtime == null or card == null:
		return
	card_runtime.add_card(card)
	if card_pool != null and card_pool.has_method("consume_card"):
		card_pool.call("consume_card", card)
