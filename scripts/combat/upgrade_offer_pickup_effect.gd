extends "res://scripts/combat/pickup_effect_config.gd"
class_name UpgradeOfferPickupEffect
## 拾取后打开强化效果三选一的拾取物效果。

## 奖励池；为空时不打开选择界面。
@export var offer_pool: Resource = null
## 三选一标题。
@export var offer_title: String = "选择奖励"


## 拾取时请求当前 RunScene 打开奖励三选一。
func apply(player: CombatPlayer) -> void:
	if player == null or not is_instance_valid(player):
		return
	var tree := player.get_tree()
	if tree == null:
		return
	var scene: Node = tree.current_scene
	if scene != null and scene.has_method("begin_pickup_upgrade_offer"):
		scene.call("begin_pickup_upgrade_offer", offer_pool, offer_title)
