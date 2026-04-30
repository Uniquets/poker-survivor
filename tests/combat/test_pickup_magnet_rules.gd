extends RefCounted

const TestSupport = preload("res://tests/test_support.gd")


## 验证拾取物可以关闭磁吸，但仍保留直接拾取能力给收集器处理。
static func test_battle_pickup_can_disable_magnet() -> void:
	var pickup := BattlePickup.new()
	pickup.magnet_enabled = false

	TestSupport.assert_true(not pickup.can_be_magnetized(), "pickup magnet disabled")
