extends RefCounted

const TestSupport = preload("res://tests/test_support.gd")
const GrantAugmentUpgradeEffectScript = preload("res://scripts/upgrades/grant_augment_upgrade_effect.gd")


## 验证强化效果选中后可以通过统一入口应用到 RunScene。
static func test_upgrade_effect_choice_applies_selected_effect() -> void:
	var effect := GrantAugmentUpgradeEffectScript.new()
	effect.method_name = "grant_global_permanent_volley_bonus"
	var receiver := _FakeRunScene.new()

	effect.apply_to_run(null, receiver, null)

	TestSupport.assert_eq(receiver.called, 1, "selected effect applied once")


class _FakeRunScene:
	extends RefCounted
	var called: int = 0

	func grant_global_permanent_volley_bonus() -> void:
		called += 1
