extends Resource
class_name UpgradeEffect
## 三选一强化效果基类：提供统一展示字段、抽取权重和应用入口。

## 选项标题，显示在统一卡面中。
@export var title: String = ""
## 选项说明，显示在标题下方。
@export var description: String = ""
## 抽取权重，数值越高越容易进入候选。
@export_range(0.0, 1000.0, 0.1) var weight: float = 1.0
## 是否需要先从当前牌组中选择一张目标牌。
@export var requires_deck_target: bool = false


## 返回该效果是否可以参与奖励池抽取。
func is_valid_effect() -> bool:
	return weight > 0.0 and not title.strip_edges().is_empty()


## 返回需要按普通卡牌样式展示的卡；非卡牌效果返回 null。
func get_display_card() -> CardResource:
	return null


## 应用强化效果；子类覆盖这个方法执行实际逻辑。
func apply_to_run(_card_runtime: CardRuntime, _run_scene: Node, _card_pool: Node) -> void:
	pass
