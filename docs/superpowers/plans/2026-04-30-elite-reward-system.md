# Elite Reward And Upgrade Effect System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add elite enemy spawning and elite reward drops while refactoring the existing three-choice card selection into a reusable three-choice upgrade-effect system.

**Architecture:** Elite enemies are spawned by `EnemyManager` using configured elite events, but elite death does not directly call `RunScene` reward code. Elite rewards use the same drop-entry path as normal enemies: an elite drops a visible card-like pickup that cannot be magnet-absorbed, and picking it opens a configurable three-choice upgrade-effect offer. Existing card-pick behavior becomes one upgrade-effect type (`add_card`) instead of a special UI-only path.

**Tech Stack:** Godot 4.6, GDScript, existing `EnemyManager`, `CombatEnemy`, `BattlePickup`, `PickupCollector`, `RunScene`, `CardRuntime`, `CardSelectUI`, `.tres` resources, Godot MCP Pro/headless test harness.

---

## Current Baseline

- `EnemyManager` already reads `config/run_spawn_timeline_config.tres`.
- `RunSpawnTimelineConfig.elite_event_seconds` currently defines deterministic elite event times.
- At an elite event, `EnemyManager` currently only has an event hook.
- `CombatEnemy._die()` already calls `_spawn_death_drops()`, which uses `death_drop_entries`.
- `BattlePickup` already displays a pickup and exposes an `effect` resource.
- `PickupCollector` automatically magnet-pulls all `battle_pickups` and calls `effect.apply(player)`.
- `RunScene` has a working level-up three-card offer, but the choices are hard-coded as cards.
- `CardRuntime` already supports `add_card`, `remove_card_at`, `set_cards_order`, `insert_card`, and `swap_cards`.

## Required Behavior Changes

- Elite spawn should not suppress ordinary enemy spawning in this slice.
- Elite rewards should use drop-entry configuration, just like ordinary enemy drops.
- Elite reward pickup should look like a card and should not be magnet-absorbed.
- Picking the elite reward opens a three-choice offer.
- The three choices are upgrade effects, not always cards.
- Supported first-pass upgrade effect kinds:
  - `add_card`: choose or receive a card.
  - `remove_card`: remove one owned deck card.
  - `reorder_deck`: open one deck ordering action.
  - `replace_card`: remove one owned card and add one card from an offered pool.
  - `grant_augment`: apply a direct combat upgrade, such as global projectile +1.
- Elite enemy visual distinction first pass:
  - Reuse existing skeleton scene/model.
  - Scale up.
  - Apply color tint.
  - Optionally multiply health, speed, and touch damage.

## File Structure

- Create `scripts/combat/elite_spawn_event.gd`
  - Defines when to spawn an elite, which enemy scene to reuse, visual multipliers, stat multipliers, and drop entries.
- Modify `scripts/combat/run_spawn_timeline_config.gd`
  - Adds `elite_events: Array` and helper to return the next pending event.
- Modify `scripts/combat/enemy_manager.gd`
  - Spawns elite enemy from event, applies metadata, and continues normal spawning.
- Modify `scripts/combat/enemy.gd`
  - Adds `configure_as_elite()` to tint/scale/stat-multiply the reused skeleton and assign elite drop entries.
- Create `scripts/upgrades/upgrade_effect.gd`
  - Base resource for three-choice effects.
- Create `scripts/upgrades/add_card_upgrade_effect.gd`
- Create `scripts/upgrades/remove_card_upgrade_effect.gd`
- Create `scripts/upgrades/reorder_deck_upgrade_effect.gd`
- Create `scripts/upgrades/replace_card_upgrade_effect.gd`
- Create `scripts/upgrades/grant_augment_upgrade_effect.gd`
- Create `scripts/upgrades/upgrade_offer_pool.gd`
  - Weighted pool of upgrade effects; rolls three choices.
- Create `scripts/combat/upgrade_offer_pickup_effect.gd`
  - Pickup effect that opens a `RunScene` upgrade offer.
- Modify `scripts/combat/battle_pickup.gd`
  - Adds magnet behavior control, so elite reward pickup can opt out of absorption.
- Modify `scripts/combat/pickup_collector.gd`
  - Honors `BattlePickup.can_be_magnetized()`.
- Create `scenes/combat/EliteRewardCardPickup.tscn`
  - A card-like pickup that is not magnetized.
- Modify `scripts/ui/card_select_ui.gd`
  - Generalize display from card-only to option resources with title/description.
- Modify `scripts/combat/run_scene.gd`
  - Refactor level-up three-choice into upgrade-effect offer flow.
  - Apply selected upgrade effect.
- Modify `config/run_spawn_timeline_config.tres`
  - Add first elite event.
- Create `config/upgrade_offer_pool_level_up.tres`
  - Contains add-card effects matching current level-up behavior.
- Create `config/upgrade_offer_pool_elite.tres`
  - Contains remove/reorder/replace/grant effects.
- Add tests:
  - `tests/combat/test_spawn_director.gd`
  - `tests/combat/test_pickup_magnet_rules.gd`
  - `tests/upgrades/test_upgrade_effects.gd`
  - `tests/ui/test_upgrade_offer_flow.gd`

---

## Task 1: Add Upgrade Effect Resource Model

**Files:**
- Create: `scripts/upgrades/upgrade_effect.gd`
- Create: `scripts/upgrades/add_card_upgrade_effect.gd`
- Create: `scripts/upgrades/remove_card_upgrade_effect.gd`
- Create: `scripts/upgrades/reorder_deck_upgrade_effect.gd`
- Create: `scripts/upgrades/replace_card_upgrade_effect.gd`
- Create: `scripts/upgrades/grant_augment_upgrade_effect.gd`
- Create: `tests/upgrades/test_upgrade_effects.gd`
- Modify: `tests/run_all_tests.gd`

- [ ] **Step 1: Write failing tests for upgrade effect metadata and simple application**

Create `tests/upgrades/test_upgrade_effects.gd`:

```gdscript
extends RefCounted

const TestSupport = preload("res://tests/test_support.gd")
const AddCardUpgradeEffectScript = preload("res://scripts/upgrades/add_card_upgrade_effect.gd")
const RemoveCardUpgradeEffectScript = preload("res://scripts/upgrades/remove_card_upgrade_effect.gd")
const GrantAugmentUpgradeEffectScript = preload("res://scripts/upgrades/grant_augment_upgrade_effect.gd")


## 验证加牌强化效果能向 `CardRuntime` 添加指定牌。
static func test_add_card_upgrade_effect_adds_configured_card() -> void:
	var runtime := CardRuntime.new()
	var card := CardResource.new(0, 7)
	var effect := AddCardUpgradeEffectScript.new()
	effect.card = card

	effect.apply_to_run(runtime, null, null)

	TestSupport.assert_eq(runtime.cards.size(), 1, "add-card effect adds one card")
	TestSupport.assert_eq(runtime.cards[0], card, "add-card effect inserts configured card")


## 验证删牌强化效果使用预选下标删除一张牌。
static func test_remove_card_upgrade_effect_removes_selected_index() -> void:
	var runtime := CardRuntime.new()
	runtime.cards = [CardResource.new(0, 2), CardResource.new(1, 3), CardResource.new(2, 4)]
	var effect := RemoveCardUpgradeEffectScript.new()
	effect.selected_index = 1

	effect.apply_to_run(runtime, null, null)

	TestSupport.assert_eq(runtime.cards.size(), 2, "remove-card effect removes one card")
	TestSupport.assert_eq((runtime.cards[1] as CardResource).rank, 4, "remove-card effect removes selected slot")


## 验证直接强化效果能调用 RunScene 已有的全局弹道奖励入口。
static func test_grant_augment_upgrade_effect_calls_run_scene_method() -> void:
	var effect := GrantAugmentUpgradeEffectScript.new()
	effect.method_name = "grant_global_permanent_volley_bonus"
	var receiver := _FakeRunScene.new()

	effect.apply_to_run(null, receiver, null)

	TestSupport.assert_eq(receiver.called_method, "grant_global_permanent_volley_bonus", "grant augment calls configured method")


class _FakeRunScene:
	extends RefCounted
	var called_method: String = ""

	func grant_global_permanent_volley_bonus() -> void:
		called_method = "grant_global_permanent_volley_bonus"
```

Add to `tests/run_all_tests.gd`:

```gdscript
"res://tests/upgrades/test_upgrade_effects.gd",
```

- [ ] **Step 2: Run test and verify failure**

Run:

```powershell
& 'F:\Godot_v4.6.2-stable_win64\Godot_v4.6.2-stable_win64.exe' --headless --path . --script tests/run_all_tests.gd
```

Expected:
- New test script fails to load because upgrade effect scripts do not exist.

- [ ] **Step 3: Implement base `UpgradeEffect`**

Create `scripts/upgrades/upgrade_effect.gd`:

```gdscript
extends Resource
class_name UpgradeEffect
## 三选一强化效果基类：只定义展示信息与统一应用入口。

## 选项标题，显示在三选一按钮上。
@export var title: String = ""
## 选项说明，显示在标题下方。
@export var description: String = ""
## 权重，用于奖励池抽取。
@export_range(0.0, 1000.0, 0.1) var weight: float = 1.0
## 是否需要额外选择牌组内目标，例如删牌、置换、调序。
@export var requires_deck_target: bool = false


## 返回该效果是否可进入奖励池。
func is_valid_effect() -> bool:
	return weight > 0.0 and not title.strip_edges().is_empty()


## 应用效果；子类覆盖，参数允许访问手牌、RunScene 与 CardPool。
func apply_to_run(_card_runtime: CardRuntime, _run_scene: Node, _card_pool: Node) -> void:
	pass
```

- [ ] **Step 4: Implement add-card effect**

Create `scripts/upgrades/add_card_upgrade_effect.gd`:

```gdscript
extends UpgradeEffect
class_name AddCardUpgradeEffect
## 加牌强化效果：把配置的卡加入当前牌组。

## 要加入的卡；为空时不生效。
@export var card: CardResource = null


## 将配置卡加入当前 `CardRuntime`。
func apply_to_run(card_runtime: CardRuntime, _run_scene: Node, _card_pool: Node) -> void:
	if card_runtime == null or card == null:
		return
	card_runtime.add_card(card)
```

- [ ] **Step 5: Implement remove-card effect**

Create `scripts/upgrades/remove_card_upgrade_effect.gd`:

```gdscript
extends UpgradeEffect
class_name RemoveCardUpgradeEffect
## 删牌强化效果：删除当前牌组中指定下标的牌。

## UI 选中的牌组下标；应用前由 RunScene 写入。
var selected_index: int = -1


## 初始化展示信息与目标选择要求。
func _init() -> void:
	title = "删除一张"
	description = "从当前牌组中移除一张牌"
	requires_deck_target = true


## 删除选中的牌。
func apply_to_run(card_runtime: CardRuntime, _run_scene: Node, _card_pool: Node) -> void:
	if card_runtime == null:
		return
	card_runtime.remove_card_at(selected_index)
```

- [ ] **Step 6: Implement reorder and replace placeholders as real effect shells**

Create `scripts/upgrades/reorder_deck_upgrade_effect.gd`:

```gdscript
extends UpgradeEffect
class_name ReorderDeckUpgradeEffect
## 调序强化效果：请求 RunScene 打开现有手牌调序面板。


## 初始化展示信息。
func _init() -> void:
	title = "调序一次"
	description = "重新调整当前牌组顺序"


## 调用 RunScene 的调序入口。
func apply_to_run(_card_runtime: CardRuntime, run_scene: Node, _card_pool: Node) -> void:
	if run_scene != null and run_scene.has_method("open_hand_sort_reward"):
		run_scene.call("open_hand_sort_reward")
```

Create `scripts/upgrades/replace_card_upgrade_effect.gd`:

```gdscript
extends UpgradeEffect
class_name ReplaceCardUpgradeEffect
## 置换强化效果：先删除一张牌，再从配置卡或卡池中加入一张牌。

@export var replacement_card: CardResource = null
var selected_index: int = -1


## 初始化展示信息与目标选择要求。
func _init() -> void:
	title = "置换一次"
	description = "移除一张牌并加入一张新牌"
	requires_deck_target = true


## 执行置换；第一版要求 `replacement_card` 非空。
func apply_to_run(card_runtime: CardRuntime, _run_scene: Node, _card_pool: Node) -> void:
	if card_runtime == null or replacement_card == null:
		return
	card_runtime.remove_card_at(selected_index)
	card_runtime.add_card(replacement_card)
```

- [ ] **Step 7: Implement direct augment effect**

Create `scripts/upgrades/grant_augment_upgrade_effect.gd`:

```gdscript
extends UpgradeEffect
class_name GrantAugmentUpgradeEffect
## 直接强化效果：调用 RunScene 上的白名单强化方法。

## RunScene 方法名；第一版用于 `grant_global_permanent_volley_bonus`。
@export var method_name: String = ""


## 调用 RunScene 的强化方法。
func apply_to_run(_card_runtime: CardRuntime, run_scene: Node, _card_pool: Node) -> void:
	if run_scene == null or method_name.strip_edges().is_empty():
		return
	if run_scene.has_method(method_name):
		run_scene.call(method_name)
```

- [ ] **Step 8: Run tests and commit**

Expected:
- `tests/upgrades/test_upgrade_effects.gd` passes.
- Existing tests pass.

Commit:

```powershell
git add scripts/upgrades tests/upgrades tests/run_all_tests.gd
git commit -m "feat: add upgrade effect resources"
```

---

## Task 2: Add Upgrade Offer Pool and Refactor Three-Choice Data

**Files:**
- Create: `scripts/upgrades/upgrade_offer_pool.gd`
- Create: `config/upgrade_offer_pool_level_up.tres`
- Create: `config/upgrade_offer_pool_elite.tres`
- Modify: `scripts/combat/run_scene.gd`
- Modify: `tests/upgrades/test_upgrade_effects.gd`

- [ ] **Step 1: Add failing test for rolling three effects**

Append to `tests/upgrades/test_upgrade_effects.gd`:

```gdscript
const UpgradeOfferPoolScript = preload("res://scripts/upgrades/upgrade_offer_pool.gd")


## 验证奖励池能从有效效果中取出三个选项。
static func test_upgrade_offer_pool_rolls_three_effects() -> void:
	var e1 := RemoveCardUpgradeEffectScript.new()
	var e2 := RemoveCardUpgradeEffectScript.new()
	var e3 := RemoveCardUpgradeEffectScript.new()
	e1.title = "删除 A"
	e2.title = "删除 B"
	e3.title = "删除 C"
	var pool := UpgradeOfferPoolScript.new()
	pool.effects = [e1, e2, e3]

	var offer: Array = pool.roll_offer(3)

	TestSupport.assert_eq(offer.size(), 3, "offer contains three effects")
	TestSupport.assert_true(offer.has(e1), "offer includes first effect")
	TestSupport.assert_true(offer.has(e2), "offer includes second effect")
	TestSupport.assert_true(offer.has(e3), "offer includes third effect")
```

- [ ] **Step 2: Implement `UpgradeOfferPool`**

Create `scripts/upgrades/upgrade_offer_pool.gd`:

```gdscript
extends Resource
class_name UpgradeOfferPool
## 三选一奖励池：从配置的强化效果中按权重抽取若干个不重复选项。

const _UpgradeEffectScript: GDScript = preload("res://scripts/upgrades/upgrade_effect.gd")

## 候选强化效果数组，元素应继承 `UpgradeEffect`。
@export var effects: Array = []


## 按权重抽取 `count` 个不重复强化效果。
func roll_offer(count: int = 3) -> Array:
	var source: Array = _valid_effects()
	var result: Array = []
	while result.size() < count and not source.is_empty():
		var picked: Resource = _pick_weighted(source)
		if picked == null:
			break
		result.append(picked)
		source.erase(picked)
	return result


## 收集可用强化效果。
func _valid_effects() -> Array:
	var valid: Array = []
	for raw in effects:
		var effect: Resource = raw as Resource
		if effect == null:
			continue
		if effect is UpgradeEffect and effect.call("is_valid_effect"):
			valid.append(effect)
	return valid


## 从数组中按权重抽一个效果。
func _pick_weighted(valid: Array) -> Resource:
	var total: float = 0.0
	for effect in valid:
		total += maxf(0.0, float(effect.get("weight")))
	if total <= 0.0:
		return null
	var roll: float = randf() * total
	for effect in valid:
		roll -= maxf(0.0, float(effect.get("weight")))
		if roll <= 0.0:
			return effect
	return valid.back() as Resource
```

- [ ] **Step 3: Add RunScene offer pool exports**

In `scripts/combat/run_scene.gd`, add:

```gdscript
## 升级时使用的三选一强化效果池；第一版主要生成加牌效果。
@export var level_up_upgrade_pool: UpgradeOfferPool = null
## 精英奖励拾取时使用的三选一强化效果池。
@export var elite_upgrade_pool: UpgradeOfferPool = null
```

Use script preloads if headless class-name indexing requires the project pattern.

- [ ] **Step 4: Create first config resources**

Create `config/upgrade_offer_pool_elite.tres` with three initial effect subresources:

```text
RemoveCardUpgradeEffect title="删除一张"
ReorderDeckUpgradeEffect title="调序一次"
GrantAugmentUpgradeEffect title="弹道 +1" method_name="grant_global_permanent_volley_bonus"
```

Create `config/upgrade_offer_pool_level_up.tres` as a placeholder pool for later add-card generation:

```text
GrantAugmentUpgradeEffect title="弹道 +1" method_name="grant_global_permanent_volley_bonus"
RemoveCardUpgradeEffect title="删除一张"
ReorderDeckUpgradeEffect title="调序一次"
```

This keeps the resource valid while Task 3 refactors add-card generation.

- [ ] **Step 5: Run tests and commit**

Expected:
- Upgrade offer pool tests pass.
- Full harness passes.

Commit:

```powershell
git add scripts/upgrades/upgrade_offer_pool.gd config/upgrade_offer_pool_level_up.tres config/upgrade_offer_pool_elite.tres scripts/combat/run_scene.gd tests/upgrades/test_upgrade_effects.gd
git commit -m "feat: add upgrade offer pools"
```

---

## Task 3: Refactor Three-Choice UI From Cards To Upgrade Effects

**Files:**
- Modify: `scripts/ui/card_select_ui.gd`
- Modify: `scripts/combat/run_scene.gd`
- Modify: `tests/ui/test_upgrade_offer_flow.gd`
- Modify: `tests/run_all_tests.gd`

- [ ] **Step 1: Add failing UI flow test for effect choice dispatch**

Create `tests/ui/test_upgrade_offer_flow.gd`:

```gdscript
extends RefCounted

const TestSupport = preload("res://tests/test_support.gd")
const GrantAugmentUpgradeEffectScript = preload("res://scripts/upgrades/grant_augment_upgrade_effect.gd")


## 验证强化效果选中后会调用配置方法。
static func test_upgrade_effect_choice_applies_selected_effect() -> void:
	var effect := GrantAugmentUpgradeEffectScript.new()
	effect.title = "弹道 +1"
	effect.method_name = "grant_global_permanent_volley_bonus"
	var receiver := _FakeRunScene.new()

	effect.apply_to_run(null, receiver, null)

	TestSupport.assert_eq(receiver.called, 1, "selected effect applied once")


class _FakeRunScene:
	extends RefCounted
	var called: int = 0

	func grant_global_permanent_volley_bonus() -> void:
		called += 1
```

Add path to `tests/run_all_tests.gd`.

- [ ] **Step 2: Extend `CardSelectUI` with generic effect offers**

Add signal:

```gdscript
signal upgrade_effect_selected(effect: Resource)
```

Add method:

```gdscript
## 展示强化效果三选一；按钮数据不再要求是 `CardResource`。
func show_upgrade_effects(effects: Array) -> void:
	visible = true
	disable_selection()
	_current_offer_cards = []
	for i in range(min(3, effects.size())):
		var effect: Resource = effects[i] as Resource
		var btn: Button = _card_buttons[i] if i < _card_buttons.size() else null
		if btn == null:
			continue
		btn.visible = true
		btn.disabled = false
		btn.text = "%s\n%s" % [str(effect.get("title")), str(effect.get("description"))]
		btn.pressed.connect(func () -> void:
			emit_signal("upgrade_effect_selected", effect)
		, CONNECT_ONE_SHOT)
```

Adjust exact button fields to match current `card_select_ui.gd` implementation; do not remove existing card-offer methods in this task.

- [ ] **Step 3: Add `RunScene` generic upgrade offer state**

Add:

```gdscript
var _current_upgrade_offer: Array = []
```

Add:

```gdscript
## 打开强化效果三选一，复用现有选卡暂停层。
func _begin_upgrade_effect_offer(pool: UpgradeOfferPool, title: String) -> void:
	if pool == null:
		return
	_current_upgrade_offer = pool.roll_offer(3)
	if _current_upgrade_offer.is_empty():
		return
	_card_pick_flow.is_selecting_cards = true
	enemy_manager.set_active(false)
	auto_attack_system.process_mode = Node.PROCESS_MODE_DISABLED
	card_runtime.process_mode = Node.PROCESS_MODE_DISABLED
	card_select_ui.set_title(title)
	card_select_ui.show_upgrade_effects(_current_upgrade_offer)
	card_select_ui.visible = true
	card_hand_ui.visible = true
	_hud.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
```

Add selection handler:

```gdscript
## 强化效果选中后按效果类型执行，必要时进入二级选择。
func _on_upgrade_effect_selected(effect: Resource) -> void:
	if effect == null:
		return
	if bool(effect.get("requires_deck_target")):
		_begin_upgrade_effect_deck_target_selection(effect)
		return
	_apply_upgrade_effect_and_resume(effect)
```

Add:

```gdscript
## 应用无需二级目标的强化效果并恢复战斗。
func _apply_upgrade_effect_and_resume(effect: Resource) -> void:
	var card_pool := get_node_or_null("/root/CardPool")
	effect.call("apply_to_run", card_runtime, self, card_pool)
	_resume_after_upgrade_effect_offer()
```

Add:

```gdscript
## 关闭强化效果 UI 并恢复战斗。
func _resume_after_upgrade_effect_offer() -> void:
	_current_upgrade_offer = []
	card_select_ui.disable_selection()
	get_tree().paused = false
	_hud.process_mode = Node.PROCESS_MODE_INHERIT
	card_select_ui.visible = false
	card_hand_ui.visible = true
	_card_pick_flow.is_selecting_cards = false
	card_runtime.process_mode = Node.PROCESS_MODE_INHERIT
	auto_attack_system.process_mode = Node.PROCESS_MODE_INHERIT
	enemy_manager.set_active(true)
	card_hand_ui.refresh_display()
	_apply_hand_card_overlay_highlight()
```

- [ ] **Step 4: Connect UI signal**

In `_ready()`:

```gdscript
if card_select_ui.has_signal("upgrade_effect_selected"):
	var upgrade_cb := Callable(self, "_on_upgrade_effect_selected")
	if not card_select_ui.upgrade_effect_selected.is_connected(upgrade_cb):
		card_select_ui.upgrade_effect_selected.connect(upgrade_cb)
```

- [ ] **Step 5: Run tests and commit**

Expected:
- UI test passes.
- Existing card selection tests still pass.

Commit:

```powershell
git add scripts/ui/card_select_ui.gd scripts/combat/run_scene.gd tests/ui/test_upgrade_offer_flow.gd tests/run_all_tests.gd
git commit -m "refactor: support upgrade effect offers"
```

---

## Task 4: Preserve Level-Up As Add-Card Upgrade Effects

**Files:**
- Modify: `scripts/combat/run_scene.gd`
- Modify: `scripts/upgrades/add_card_upgrade_effect.gd`
- Modify: `tests/ui/test_upgrade_offer_flow.gd`

- [ ] **Step 1: Add helper to convert drawn cards into add-card effects**

In `RunScene`, add:

```gdscript
const _AddCardUpgradeEffectScript: GDScript = preload("res://scripts/upgrades/add_card_upgrade_effect.gd")


## 将抽出的候选卡转换为加牌强化效果，使升级三选一不再直接依赖卡牌 UI。
func _cards_to_add_card_effects(cards: Array) -> Array:
	var effects: Array = []
	for card in cards:
		if not card is CardResource:
			continue
		var effect: Resource = _AddCardUpgradeEffectScript.new()
		effect.set("card", card)
		effect.set("title", "拾取 %s" % (card as CardResource).get_full_name())
		effect.set("description", "加入当前牌组")
		effects.append(effect)
	return effects
```

- [ ] **Step 2: Replace level-up card display with upgrade effects**

In `_begin_level_up_card_selection()`, after drawing `random_cards`, replace:

```gdscript
card_select_ui.show_cards(random_cards)
```

with:

```gdscript
_current_upgrade_offer = _cards_to_add_card_effects(random_cards)
card_select_ui.show_upgrade_effects(_current_upgrade_offer)
```

Keep card-pool finalize behavior by adding to `AddCardUpgradeEffect.apply_to_run()`:

```gdscript
if _card_pool != null and _card_pool.has_method("consume_card"):
	_card_pool.consume_card(card)
```

Before applying add-card selection, call `card_select_ui.finalize_pick_from_current_offer(card)` only if the old card-offer list is still active. If not active, consume through card pool as above.

- [ ] **Step 3: Simplify `_complete_level_up_card` path**

Leave `_complete_level_up_card(card)` in place for compatibility with existing tests and direct card UI paths, but route the new level-up flow through `_on_upgrade_effect_selected`.

When an `AddCardUpgradeEffect` is selected:

```gdscript
effect.call("apply_to_run", card_runtime, self, get_node_or_null("/root/CardPool"))
_card_pick_flow.pending_level_up_card_picks = maxi(0, _card_pick_flow.pending_level_up_card_picks - 1)
```

If more pending picks remain, draw next three and show effects again; otherwise resume.

- [ ] **Step 4: Run tests and commit**

Expected:
- Existing level-up/card-pick tests pass.
- New upgrade effect offer tests pass.

Commit:

```powershell
git add scripts/combat/run_scene.gd scripts/upgrades/add_card_upgrade_effect.gd tests/ui/test_upgrade_offer_flow.gd
git commit -m "refactor: express level-up choices as upgrade effects"
```

---

## Task 5: Add Card-Like Non-Magnet Elite Reward Pickup

**Files:**
- Modify: `scripts/combat/battle_pickup.gd`
- Modify: `scripts/combat/pickup_collector.gd`
- Create: `scripts/combat/upgrade_offer_pickup_effect.gd`
- Create: `scenes/combat/EliteRewardCardPickup.tscn`
- Create: `tests/combat/test_pickup_magnet_rules.gd`
- Modify: `tests/run_all_tests.gd`

- [ ] **Step 1: Add failing test for non-magnet pickup**

Create `tests/combat/test_pickup_magnet_rules.gd`:

```gdscript
extends RefCounted

const TestSupport = preload("res://tests/test_support.gd")


## 验证不可吸附拾取物会明确返回 false。
static func test_battle_pickup_can_disable_magnet() -> void:
	var pickup := BattlePickup.new()
	pickup.magnet_enabled = false

	TestSupport.assert_true(not pickup.can_be_magnetized(), "pickup magnet disabled")
```

Add path to `tests/run_all_tests.gd`.

- [ ] **Step 2: Add magnet toggle to `BattlePickup`**

In `scripts/combat/battle_pickup.gd`, add:

```gdscript
## 是否允许被 `PickupCollector` 磁力吸附；精英奖励卡牌为 false。
@export var magnet_enabled: bool = true


## 返回本拾取物是否允许磁力吸附。
func can_be_magnetized() -> bool:
	return magnet_enabled
```

- [ ] **Step 3: Honor magnet toggle in `PickupCollector`**

In `PickupCollector._physics_process`, before distance-based movement:

```gdscript
var can_magnet: bool = true
if pu.has_method("can_be_magnetized"):
	can_magnet = bool(pu.call("can_be_magnetized"))
if not can_magnet and d > collect_d:
	continue
```

This keeps manual pickup possible at collect distance, but disables long-range attraction.

- [ ] **Step 4: Add pickup effect that opens upgrade offer**

Create `scripts/combat/upgrade_offer_pickup_effect.gd`:

```gdscript
extends PickupEffectConfig
class_name UpgradeOfferPickupEffect
## 拾取后打开强化效果三选一的拾取效果。

## 奖励池；为空时不生效。
@export var offer_pool: UpgradeOfferPool = null
## 展示标题。
@export var offer_title: String = "选择奖励"


## 拾取时请求当前 RunScene 打开奖励三选一。
func apply(player: CombatPlayer) -> void:
	if player == null:
		return
	var scene: Node = player.get_tree().current_scene
	if scene != null and scene.has_method("begin_pickup_upgrade_offer"):
		scene.call("begin_pickup_upgrade_offer", offer_pool, offer_title)
```

- [ ] **Step 5: Expose RunScene pickup offer method**

Add:

```gdscript
## 拾取物入口：打开指定奖励池的强化效果三选一。
func begin_pickup_upgrade_offer(pool: UpgradeOfferPool, title: String) -> void:
	_begin_upgrade_effect_offer(pool, title)
```

- [ ] **Step 6: Create elite reward pickup scene**

Create `scenes/combat/EliteRewardCardPickup.tscn`:

```text
BattlePickup root
- script = battle_pickup.gd
- magnet_enabled = false
- effect = UpgradeOfferPickupEffect subresource using config/upgrade_offer_pool_elite.tres
- visible child can reuse Label/IconLabel with text "奖励牌"
```

- [ ] **Step 7: Run tests and commit**

Expected:
- Magnet rule test passes.
- Full harness passes.

Commit:

```powershell
git add scripts/combat/battle_pickup.gd scripts/combat/pickup_collector.gd scripts/combat/upgrade_offer_pickup_effect.gd scenes/combat/EliteRewardCardPickup.tscn tests/combat/test_pickup_magnet_rules.gd tests/run_all_tests.gd
git commit -m "feat: add elite reward pickup"
```

---

## Task 6: Spawn Elite Skeleton With Configured Drops

**Files:**
- Create: `scripts/combat/elite_spawn_event.gd`
- Modify: `scripts/combat/run_spawn_timeline_config.gd`
- Modify: `scripts/combat/enemy_manager.gd`
- Modify: `scripts/combat/enemy.gd`
- Modify: `config/run_spawn_timeline_config.tres`
- Modify: `tests/combat/test_spawn_director.gd`

- [ ] **Step 1: Add failing elite event test**

Add to `tests/combat/test_spawn_director.gd`:

```gdscript
const EliteSpawnEventScript = preload("res://scripts/combat/elite_spawn_event.gd")


## 验证时间轴能返回未触发的精英事件资源。
static func test_spawn_config_returns_pending_elite_event() -> void:
	var event := EliteSpawnEventScript.new()
	event.trigger_seconds = 12.0
	var config := RunSpawnTimelineConfigScript.new()
	config.elite_events = [event]

	TestSupport.assert_eq(config.elite_event_for_time(11.9, {}), null, "elite event not ready")
	TestSupport.assert_eq(config.elite_event_for_time(12.0, {}), event, "elite event ready")
	TestSupport.assert_eq(config.elite_event_for_time(20.0, {12.0: true}), null, "elite event consumed")
```

- [ ] **Step 2: Implement `EliteSpawnEvent`**

Create `scripts/combat/elite_spawn_event.gd`:

```gdscript
extends Resource
class_name EliteSpawnEvent
## 精英刷怪事件：确定时间触发，生成复用敌人场景的精英版本。

## 触发时间（局内已进行秒数）。
@export var trigger_seconds: float = 150.0
## 精英敌人场景；为空时回落到 `EnemyManager.enemy_scene`。
@export var elite_scene: PackedScene = null
## 死亡掉落条目，沿用普通敌人的 `EnemyDropEntry` 机制。
@export var death_drop_entries: Array = []
## 精英视觉缩放倍率。
@export_range(1.0, 5.0, 0.05) var visual_scale_multiplier: float = 1.35
## 精英颜色调制。
@export var elite_modulate: Color = Color(1.45, 0.65, 0.25, 1.0)
## 精英生命倍率。
@export_range(1.0, 20.0, 0.1) var health_multiplier: float = 4.0
## 精英速度倍率。
@export_range(0.1, 5.0, 0.1) var move_speed_multiplier: float = 1.1
## 精英触碰伤害倍率。
@export_range(0.1, 10.0, 0.1) var touch_damage_multiplier: float = 1.5


## 返回事件是否可参与触发。
func is_valid_event() -> bool:
	return trigger_seconds >= 0.0
```

- [ ] **Step 3: Extend timeline config**

In `run_spawn_timeline_config.gd`, add `elite_events` and `elite_event_for_time()` as in Task 1, but do not include reward_kind.

- [ ] **Step 4: Spawn elite from `EnemyManager` without suppressing normal spawns**

In `_update_timeline_state()`:

```gdscript
var elite_event: Resource = pending_elite_event_for_time(_match_elapsed_seconds)
if elite_event != null:
	mark_elite_event_triggered_from_event(elite_event)
	_spawn_elite_from_event(elite_event)
```

Add:

```gdscript
## 返回当前时间可触发的精英事件资源。
func pending_elite_event_for_time(match_seconds: float) -> Resource:
	if not _has_valid_spawn_timeline():
		return null
	if not spawn_timeline_config.has_method("elite_event_for_time"):
		return null
	return spawn_timeline_config.call("elite_event_for_time", match_seconds, _triggered_elite_event_seconds) as Resource


## 标记精英事件已触发。
func mark_elite_event_triggered_from_event(event: Resource) -> void:
	if event == null:
		return
	_triggered_elite_event_seconds[float(event.get("trigger_seconds"))] = true


## 生成精英敌人；不压制普通刷怪。
func _spawn_elite_from_event(event: Resource) -> void:
	var ps: PackedScene = event.get("elite_scene") as PackedScene
	if ps == null:
		ps = enemy_scene
	if ps == null:
		return
	var enemy: Node = ps.instantiate()
	if enemy == null:
		return
	enemy.global_position = _pick_spawn_world_position()
	if enemy is CombatEnemy:
		var ce: CombatEnemy = enemy as CombatEnemy
		ce.target = resolve_spawn_target()
		ce.configure_as_elite(
			float(event.get("visual_scale_multiplier")),
			event.get("elite_modulate") as Color,
			float(event.get("health_multiplier")),
			float(event.get("move_speed_multiplier")),
			float(event.get("touch_damage_multiplier")),
			event.get("death_drop_entries") as Array
		)
	get_units_root().add_child(enemy)
```

- [ ] **Step 5: Configure elite enemy visual and drops**

In `CombatEnemy`, add:

```gdscript
## 是否为精英敌人；精英只改变外观、数值与死亡掉落，不直接发奖励信号。
@export var is_elite: bool = false
var _elite_visual_scale_multiplier: float = 1.0
var _elite_modulate: Color = Color.WHITE
var _elite_health_multiplier: float = 1.0
var _elite_move_speed_multiplier: float = 1.0
var _elite_touch_damage_multiplier: float = 1.0
var _elite_death_drop_entries: Array = []


## 标记本敌人为精英，并保存外观、数值和掉落配置。
func configure_as_elite(visual_scale_multiplier: float, elite_modulate: Color, health_multiplier: float, move_speed_multiplier: float, touch_damage_multiplier: float, p_death_drop_entries: Array) -> void:
	is_elite = true
	_elite_visual_scale_multiplier = maxf(1.0, visual_scale_multiplier)
	_elite_modulate = elite_modulate
	_elite_health_multiplier = maxf(1.0, health_multiplier)
	_elite_move_speed_multiplier = maxf(0.1, move_speed_multiplier)
	_elite_touch_damage_multiplier = maxf(0.1, touch_damage_multiplier)
	_elite_death_drop_entries = p_death_drop_entries.duplicate()
```

In `_ready()` after base setup:

```gdscript
if is_elite:
	scale *= _elite_visual_scale_multiplier
	modulate = _elite_modulate
	move_speed *= _elite_move_speed_multiplier
	touch_damage = int(round(float(touch_damage) * _elite_touch_damage_multiplier))
	death_drop_entries = _elite_death_drop_entries
```

Health multiplier can be added by changing `max_health` before health component initialization. If current `CombatHealthComponent` owns health independently, add a setter there in this same task:

```gdscript
## 覆盖敌人最大生命并可选回满当前生命。
func set_enemy_max_health(value: int, refill: bool) -> void:
	max_health = maxi(1, value)
	if refill:
		current_health = max_health
```

- [ ] **Step 6: Configure first elite event**

In `config/run_spawn_timeline_config.tres`, add:

```text
EliteSpawnEvent trigger_seconds=150.0
elite_scene=skelen.tscn
death_drop_entries=[EnemyDropEntry pickup_scene=EliteRewardCardPickup.tscn drop_probability=1.0]
visual_scale_multiplier=1.35
elite_modulate=orange/gold tint
health_multiplier=4.0
move_speed_multiplier=1.1
touch_damage_multiplier=1.5
```

- [ ] **Step 7: Run tests and commit**

Expected:
- Spawn director tests pass.
- Full harness passes.

Commit:

```powershell
git add scripts/combat/elite_spawn_event.gd scripts/combat/run_spawn_timeline_config.gd scripts/combat/enemy_manager.gd scripts/combat/enemy.gd config/run_spawn_timeline_config.tres tests/combat/test_spawn_director.gd
git commit -m "feat: spawn elite skeleton drops"
```

---

## Task 7: Document And Verify T009 First Slice

**Files:**
- Modify: `docs/测试与进度.md`
- Modify: `docs/superpowers/plans/2026-04-30-elite-reward-system.md`

- [ ] **Step 1: Update T009 status**

Change the T009 line to:

```markdown
- [ ] T009 精英奖励：删牌/调序等（第一阶段目标：时间轴精英 + 卡牌外观奖励掉落 + 强化效果三选一；精英词缀、遗物碎片、Boss 奖励待办）
```

- [ ] **Step 2: Add elite reward quick-test note**

Add:

```markdown
### 精英奖励快测

精英事件由 `config/run_spawn_timeline_config.tres` 的 `elite_events` 控制。第一阶段精英复用骷髅模型，通过放大与调色区分；死亡后通过 `death_drop_entries` 掉落一张不可吸附的卡牌外观奖励物。拾取后打开强化效果三选一，选项来自配置的奖励池。
```

- [ ] **Step 3: Run verification**

Run:

```powershell
git diff --check
& 'F:\Godot_v4.6.2-stable_win64\Godot_v4.6.2-stable_win64.exe' --headless --path . --script tests/run_all_tests.gd
```

If MCP is connected:
- `reload_project`
- run main scene
- trigger elite time
- kill elite through script
- verify card-like reward pickup appears
- inspect editor errors

- [ ] **Step 4: Commit**

```powershell
git add docs/测试与进度.md docs/superpowers/plans/2026-04-30-elite-reward-system.md
git commit -m "docs: document elite reward flow"
```

---

## Expected Final Behavior

- Elite timing is configured in `config/run_spawn_timeline_config.tres`.
- Elite spawn does not suppress ordinary spawns.
- Elite reuses the current skeleton scene, with larger scale and color tint.
- Elite death uses normal `death_drop_entries`; no direct `elite_defeated(reward_kind)` signal is needed.
- Elite reward pickup looks like a card and is not magnet-absorbed.
- Picking the reward opens a configurable three-choice upgrade-effect offer.
- Level-up choices are also represented as upgrade effects, so card pickup, remove, reorder, replace, and direct augment share one choice model.

## Deferred Work

- Elite affixes from `详细设计.md` §19.
- Multiple elite enemy scenes.
- Relic reward table.
- Boss entity and boss reward flow.
- Gold/meta economy.
