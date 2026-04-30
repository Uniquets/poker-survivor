extends RefCounted

const TestSupport = preload("res://tests/test_support.gd")


static func _card(rank: int) -> CardResource:
	var c := CardResource.new(0, rank)
	c.damage = rank
	return c


static func test_opening_flow_finishes_after_required_picks() -> void:
	var flow := CardPickFlow.new()
	flow.start_opening(3)
	TestSupport.assert_true(flow.is_selecting_cards, "opening selecting")
	TestSupport.assert_eq(flow.card_pick_mode, CardPickFlow.PickMode.OPENING, "opening mode")
	TestSupport.assert_true(not flow.complete_opening_pick(_card(2)), "opening pick one not complete")
	TestSupport.assert_true(not flow.complete_opening_pick(_card(3)), "opening pick two not complete")
	TestSupport.assert_true(flow.complete_opening_pick(_card(4)), "opening pick three complete")
	TestSupport.assert_eq(flow.current_selection_count, 3, "opening pick count")
	TestSupport.assert_eq(flow.selected_cards.size(), 3, "opening selected cards")


static func test_level_up_pending_pick_decrements_and_resumes() -> void:
	var flow := CardPickFlow.new()
	flow.queue_level_up_picks(2)
	TestSupport.assert_true(flow.begin_level_up_pick(), "level up begins")
	TestSupport.assert_eq(flow.card_pick_mode, CardPickFlow.PickMode.LEVEL_UP, "level up mode")
	TestSupport.assert_true(flow.complete_level_up_pick(), "first level up has more")
	TestSupport.assert_eq(flow.pending_level_up_card_picks, 1, "pending after first")
	TestSupport.assert_true(not flow.complete_level_up_pick(), "second level up done")
	flow.resume_after_level_up()
	TestSupport.assert_true(not flow.is_selecting_cards, "level up resumed")
	TestSupport.assert_eq(flow.card_pick_mode, CardPickFlow.PickMode.IDLE, "level up idle")


static func test_skip_level_up_offer_decrements_pending() -> void:
	var flow := CardPickFlow.new()
	flow.queue_level_up_picks(1)
	flow.begin_level_up_pick()
	TestSupport.assert_true(not flow.skip_level_up_offer(), "skip leaves no pending")
	TestSupport.assert_eq(flow.pending_level_up_card_picks, 0, "pending after skip")
