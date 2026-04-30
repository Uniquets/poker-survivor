extends RefCounted
class_name CardPickFlow

enum PickMode { OPENING, ADD_ONE, LEVEL_UP, IDLE }

var is_selecting_cards: bool = false
var total_selection_count: int = 3
var current_selection_count: int = 0
var selected_cards: Array = []
var card_pick_mode: PickMode = PickMode.IDLE
var pending_level_up_card_picks: int = 0


func start_opening(total_count: int = 3) -> void:
	total_selection_count = maxi(1, total_count)
	current_selection_count = 0
	selected_cards = []
	card_pick_mode = PickMode.OPENING
	is_selecting_cards = true


func complete_opening_pick(card: CardResource) -> bool:
	if card_pick_mode != PickMode.OPENING or card == null:
		return false
	selected_cards.append(card)
	current_selection_count += 1
	return current_selection_count >= total_selection_count


func finish_opening() -> void:
	card_pick_mode = PickMode.IDLE
	is_selecting_cards = false


func begin_add_one_pick() -> void:
	card_pick_mode = PickMode.ADD_ONE
	is_selecting_cards = true


func complete_add_one_pick() -> void:
	card_pick_mode = PickMode.IDLE
	is_selecting_cards = false


func queue_level_up_picks(count: int) -> void:
	pending_level_up_card_picks += maxi(0, count)


func can_begin_pending_level_up_pick() -> bool:
	return pending_level_up_card_picks > 0 and not is_selecting_cards


func begin_level_up_pick() -> bool:
	if pending_level_up_card_picks <= 0:
		return false
	card_pick_mode = PickMode.LEVEL_UP
	is_selecting_cards = true
	return true


func complete_level_up_pick() -> bool:
	if card_pick_mode != PickMode.LEVEL_UP:
		return pending_level_up_card_picks > 0
	pending_level_up_card_picks = maxi(0, pending_level_up_card_picks - 1)
	return pending_level_up_card_picks > 0


func skip_level_up_offer() -> bool:
	if card_pick_mode != PickMode.LEVEL_UP:
		return pending_level_up_card_picks > 0
	pending_level_up_card_picks = maxi(0, pending_level_up_card_picks - 1)
	return pending_level_up_card_picks > 0


func clear_level_up_picks() -> void:
	pending_level_up_card_picks = 0


func resume_after_level_up() -> void:
	card_pick_mode = PickMode.IDLE
	is_selecting_cards = false


func selected_cards_text() -> String:
	var names := []
	for card in selected_cards:
		if card != null and card.has_method("get_full_name"):
			names.append(card.get_full_name())
	return ", ".join(names)
