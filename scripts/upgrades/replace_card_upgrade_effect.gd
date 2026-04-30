extends "res://scripts/upgrades/upgrade_effect.gd"
class_name ReplaceCardUpgradeEffect
## 置换强化效果：先删除一张牌，再加入一张配置的新牌。

## 置换后加入的卡牌；第一版使用固定配置。
@export var replacement_card: CardResource = null
## UI 二级选择写入的牌组下标。
var selected_index: int = -1


## 初始化展示信息和二级目标需求。
func _init() -> void:
	title = "置换一次"
	description = "移除一张牌并获得一张新牌"
	requires_deck_target = true


## 执行置换；没有新牌配置时不改变牌组。
func apply_to_run(card_runtime: CardRuntime, _run_scene: Node, _card_pool: Node) -> void:
	if card_runtime == null or replacement_card == null:
		return
	card_runtime.remove_card_at(selected_index)
	card_runtime.add_card(replacement_card)
