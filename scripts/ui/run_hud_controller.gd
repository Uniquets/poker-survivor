extends RefCounted
class_name RunHudController

var health_bar: TextureProgressBar = null
var health_label: Label = null
var level_label: Label = null
var exp_bar: TextureProgressBar = null
var mix_card_bar: TextureProgressBar = null
var match_clock_label: Label = null
var kill_count_label: Label = null
var test_menu_full_dim: ColorRect = null
var card_select_ui: Control = null
var card_hand_ui = null
var test_menu_panel: Control = null


static func format_match_clock(seconds_left: float) -> String:
	var s: int = maxi(0, ceili(seconds_left))
	var m: int = int(floor(float(s) / 60.0))
	var sec: int = s % 60
	return "%02d:%02d" % [m, sec]


func bind_health(bar: TextureProgressBar, label: Label) -> void:
	health_bar = bar
	health_label = label


func bind_progression(label: Label, bar: TextureProgressBar) -> void:
	level_label = label
	exp_bar = bar


func bind_mix_card_bar(bar: TextureProgressBar) -> void:
	mix_card_bar = bar


func bind_match_clock(label: Label) -> void:
	match_clock_label = label


func bind_kill_count(label: Label) -> void:
	kill_count_label = label


func bind_hand_overlay(
	full_dim: ColorRect,
	select_ui: Control,
	hand_ui,
	menu_panel: Control
) -> void:
	test_menu_full_dim = full_dim
	card_select_ui = select_ui
	card_hand_ui = hand_ui
	test_menu_panel = menu_panel


func refresh_health(current_health: int, max_health: int) -> void:
	if health_bar != null:
		health_bar.max_value = max_health
		health_bar.value = current_health
	if health_label != null:
		health_label.text = "%d / %d" % [current_health, max_health]


func refresh_progression(level: int, xp_in_segment: int, xp_needed: int) -> void:
	if level_label != null:
		level_label.text = "LV.%d" % level
	if exp_bar != null:
		exp_bar.max_value = maxf(float(xp_needed), 1.0)
		exp_bar.value = float(xp_in_segment)


func refresh_match_clock(seconds_left: float) -> void:
	if match_clock_label != null:
		match_clock_label.text = format_match_clock(seconds_left)


func init_mix_shuffle_bar() -> void:
	if mix_card_bar == null:
		return
	mix_card_bar.min_value = 0.0
	mix_card_bar.max_value = 100.0
	mix_card_bar.value = 0.0


func refresh_mix_shuffle_bar(fill_ratio: float) -> void:
	if mix_card_bar != null:
		mix_card_bar.value = clampf(fill_ratio, 0.0, 1.0) * 100.0


func refresh_kill_count(kill_count: int) -> void:
	if kill_count_label != null:
		kill_count_label.text = str(kill_count)


func refresh_hand_card_overlay_highlight(is_selecting_cards: bool) -> void:
	if test_menu_full_dim != null and test_menu_panel != null:
		test_menu_full_dim.visible = test_menu_panel.visible
	if card_hand_ui == null:
		return
	var select_glow: bool = (
		card_select_ui != null
		and card_select_ui.visible
		and card_hand_ui.visible
		and is_selecting_cards
	)
	var test_menu_glow: bool = (
		test_menu_panel != null
		and test_menu_panel.visible
		and card_hand_ui.visible
	)
	var glow_on: bool = select_glow or test_menu_glow
	if card_hand_ui.has_method("set_hand_card_overlay_glow"):
		card_hand_ui.set_hand_card_overlay_glow(glow_on)
