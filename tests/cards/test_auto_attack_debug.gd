extends RefCounted

const TestSupport = preload("res://tests/test_support.gd")


static func test_effect_plan_debug_logging_defaults_off() -> void:
	var previous_config := GameConfig.GAME_GLOBAL
	var cfg := GameGlobalConfig.new()
	cfg.debug_effect_plan_logging = false
	GameConfig.GAME_GLOBAL = cfg
	var system := AutoAttackSystem.new()
	TestSupport.assert_true(not system._should_debug_print_play_plan(), "effect plan debug default off")
	GameConfig.GAME_GLOBAL = previous_config


static func test_effect_plan_debug_logging_can_be_enabled() -> void:
	var previous_config := GameConfig.GAME_GLOBAL
	var cfg := GameGlobalConfig.new()
	cfg.debug_effect_plan_logging = true
	GameConfig.GAME_GLOBAL = cfg
	var system := AutoAttackSystem.new()
	TestSupport.assert_true(system._should_debug_print_play_plan(), "effect plan debug enabled")
	GameConfig.GAME_GLOBAL = previous_config
