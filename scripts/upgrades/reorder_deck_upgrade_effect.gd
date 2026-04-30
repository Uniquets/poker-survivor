extends "res://scripts/upgrades/upgrade_effect.gd"
class_name ReorderDeckUpgradeEffect
## 调序强化效果：请求 RunScene 打开已有的牌组调序界面。


## 初始化展示信息。
func _init() -> void:
	title = "调序一次"
	description = "重新调整当前牌组顺序"


## 调用 RunScene 的调序入口。
func apply_to_run(_card_runtime: CardRuntime, run_scene: Object, _card_pool: Object) -> void:
	if run_scene != null and run_scene.has_method("open_hand_sort_reward"):
		run_scene.call("open_hand_sort_reward")
