extends RefCounted

const TestSupport = preload("res://tests/test_support.gd")
const RunHudControllerScript = preload("res://scripts/ui/run_hud_controller.gd")


static func test_format_match_clock_uses_minutes_and_seconds() -> void:
	TestSupport.assert_eq(RunHudControllerScript.format_match_clock(0.0), "00:00", "zero clock")
	TestSupport.assert_eq(RunHudControllerScript.format_match_clock(61.0), "01:01", "minute clock")
	TestSupport.assert_eq(RunHudControllerScript.format_match_clock(1199.1), "20:00", "ceil clock")


static func test_refresh_health_updates_bar_and_text() -> void:
	var controller = RunHudControllerScript.new()
	var bar := TextureProgressBar.new()
	var label := Label.new()
	controller.bind_health(bar, label)
	controller.refresh_health(7, 12)
	TestSupport.assert_eq(bar.max_value, 12.0, "health max")
	TestSupport.assert_eq(bar.value, 7.0, "health value")
	TestSupport.assert_eq(label.text, "7 / 12", "health text")


static func test_refresh_progression_updates_level_and_exp() -> void:
	var controller = RunHudControllerScript.new()
	var level := Label.new()
	var exp := TextureProgressBar.new()
	controller.bind_progression(level, exp)
	controller.refresh_progression(3, 4, 9)
	TestSupport.assert_eq(level.text, "LV.3", "level text")
	TestSupport.assert_eq(exp.max_value, 9.0, "exp max")
	TestSupport.assert_eq(exp.value, 4.0, "exp value")


static func test_refresh_kill_count_and_mix_bar() -> void:
	var controller = RunHudControllerScript.new()
	var kills := Label.new()
	var mix := TextureProgressBar.new()
	controller.bind_kill_count(kills)
	controller.bind_mix_card_bar(mix)
	controller.init_mix_shuffle_bar()
	controller.refresh_kill_count(5)
	controller.refresh_mix_shuffle_bar(0.42)
	TestSupport.assert_eq(kills.text, "5", "kill count text")
	TestSupport.assert_eq(mix.min_value, 0.0, "mix min")
	TestSupport.assert_eq(mix.max_value, 100.0, "mix max")
	TestSupport.assert_eq(mix.value, 42.0, "mix value")
