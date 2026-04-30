extends "res://scripts/upgrades/upgrade_effect.gd"
class_name GrantAugmentUpgradeEffect
## 直接强化效果：调用 RunScene 上允许的强化方法。

## RunScene 方法名；第一版只允许白名单内的方法。
@export var method_name: String = ""

const _ALLOWED_METHODS := {
	"grant_global_permanent_volley_bonus": true,
}


## 初始化展示信息。
func _init() -> void:
	title = "强化一次"
	description = "获得一项战斗强化"


## 调用 RunScene 上配置的白名单方法。
func apply_to_run(_card_runtime: CardRuntime, run_scene: Object, _card_pool: Object) -> void:
	if run_scene == null or method_name.strip_edges().is_empty():
		return
	if not _ALLOWED_METHODS.has(method_name):
		return
	if run_scene.has_method(method_name):
		run_scene.call(method_name)
