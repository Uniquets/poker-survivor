extends "res://scripts/upgrades/upgrade_effect.gd"
class_name RemoveCardUpgradeEffect
## 删牌强化效果：删除当前牌组中指定下标的牌。

## UI 二级选择写入的牌组下标。
var selected_index: int = -1


## 初始化展示信息和二级目标需求。
func _init() -> void:
	title = "删除一张"
	description = "从当前牌组中移除一张牌"
	requires_deck_target = true


## 删除选中的牌。
func apply_to_run(card_runtime: CardRuntime, _run_scene: Object, _card_pool: Object) -> void:
	if card_runtime == null:
		return
	card_runtime.remove_card_at(selected_index)
