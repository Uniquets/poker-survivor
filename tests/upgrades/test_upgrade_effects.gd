extends RefCounted

const TestSupport = preload("res://tests/test_support.gd")
const AddCardUpgradeEffectScript = preload("res://scripts/upgrades/add_card_upgrade_effect.gd")
const RemoveCardUpgradeEffectScript = preload("res://scripts/upgrades/remove_card_upgrade_effect.gd")
const ReorderDeckUpgradeEffectScript = preload("res://scripts/upgrades/reorder_deck_upgrade_effect.gd")
const ReplaceCardUpgradeEffectScript = preload("res://scripts/upgrades/replace_card_upgrade_effect.gd")
const GrantAugmentUpgradeEffectScript = preload("res://scripts/upgrades/grant_augment_upgrade_effect.gd")
const UpgradeOfferPoolScript = preload("res://scripts/upgrades/upgrade_offer_pool.gd")


## 验证加牌强化效果会向 CardRuntime 加入指定卡牌。
static func test_add_card_upgrade_effect_adds_configured_card() -> void:
	var runtime := CardRuntime.new()
	var card := CardResource.new(0, 7)
	var effect := AddCardUpgradeEffectScript.new()
	effect.card = card

	effect.apply_to_run(runtime, null, null)

	TestSupport.assert_eq(runtime.cards.size(), 1, "add-card effect adds one card")
	TestSupport.assert_eq(runtime.cards[0], card, "add-card effect inserts configured card")


## 验证删牌强化效果会删除预先写入的牌组下标。
static func test_remove_card_upgrade_effect_removes_selected_index() -> void:
	var runtime := CardRuntime.new()
	runtime.cards = [CardResource.new(0, 2), CardResource.new(1, 3), CardResource.new(2, 4)]
	var effect := RemoveCardUpgradeEffectScript.new()
	effect.selected_index = 1

	effect.apply_to_run(runtime, null, null)

	TestSupport.assert_eq(runtime.cards.size(), 2, "remove-card effect removes one card")
	TestSupport.assert_eq((runtime.cards[1] as CardResource).rank, 4, "remove-card effect removes selected slot")


## 验证调序强化效果会调用 RunScene 的调序入口。
static func test_reorder_deck_upgrade_effect_calls_run_scene_method() -> void:
	var effect := ReorderDeckUpgradeEffectScript.new()
	var receiver := _FakeRunScene.new()

	effect.apply_to_run(null, receiver, null)

	TestSupport.assert_eq(receiver.called_method, "open_hand_sort_reward", "reorder calls configured method")


## 验证置换强化效果会先删牌再加入新牌。
static func test_replace_card_upgrade_effect_replaces_selected_card() -> void:
	var runtime := CardRuntime.new()
	var replacement := CardResource.new(3, 12)
	runtime.cards = [CardResource.new(0, 2), CardResource.new(1, 3)]
	var effect := ReplaceCardUpgradeEffectScript.new()
	effect.selected_index = 0
	effect.replacement_card = replacement

	effect.apply_to_run(runtime, null, null)

	TestSupport.assert_eq(runtime.cards.size(), 2, "replace keeps deck size")
	TestSupport.assert_eq(runtime.cards[1], replacement, "replace adds replacement card")


## 验证直接强化效果只调用白名单内的 RunScene 方法。
static func test_grant_augment_upgrade_effect_calls_allowed_run_scene_method() -> void:
	var effect := GrantAugmentUpgradeEffectScript.new()
	effect.method_name = "grant_global_permanent_volley_bonus"
	var receiver := _FakeRunScene.new()

	effect.apply_to_run(null, receiver, null)

	TestSupport.assert_eq(receiver.called_method, "grant_global_permanent_volley_bonus", "grant augment calls configured method")


## 验证奖励池能从有效效果中取出三个不重复选项。
static func test_upgrade_offer_pool_rolls_three_unique_effects() -> void:
	var e1 := RemoveCardUpgradeEffectScript.new()
	var e2 := ReorderDeckUpgradeEffectScript.new()
	var e3 := GrantAugmentUpgradeEffectScript.new()
	e3.method_name = "grant_global_permanent_volley_bonus"
	var pool := UpgradeOfferPoolScript.new()
	pool.effects = [e1, e2, e3]

	var offer: Array = pool.roll_offer(3)

	TestSupport.assert_eq(offer.size(), 3, "offer contains three effects")
	TestSupport.assert_true(offer.has(e1), "offer includes remove")
	TestSupport.assert_true(offer.has(e2), "offer includes reorder")
	TestSupport.assert_true(offer.has(e3), "offer includes augment")


class _FakeRunScene:
	extends RefCounted
	var called_method: String = ""

	func open_hand_sort_reward() -> void:
		called_method = "open_hand_sort_reward"

	func grant_global_permanent_volley_bonus() -> void:
		called_method = "grant_global_permanent_volley_bonus"
