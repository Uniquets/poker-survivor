# Elite Reward System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn current elite time hooks into a playable loop: spawn an elite enemy, detect its death, pause combat, grant a concrete deck reward, and resume the run.

**Architecture:** Keep `EnemyManager` responsible for spawn timing and enemy instantiation. Mark elite enemies with a small component/config so death can be routed back to `RunScene`. Reuse the existing pause/resume pattern from level-up card selection and start with one concrete reward: remove one card from the current deck.

**Tech Stack:** Godot 4.6, GDScript, existing `EnemyManager`, `CombatEnemy`, `RunScene`, `CardRuntime`, `CardSelectUI`, `.tres` spawn timeline config, Godot MCP Pro/headless test harness.

---

## Current Baseline

- `EnemyManager` already reads `config/run_spawn_timeline_config.tres`.
- `RunSpawnTimelineConfig.elite_event_seconds` defines deterministic elite event times.
- At an elite event, `EnemyManager` currently only prints `[spawn] elite_event_ready`.
- `CombatEnemy._die()` already calls `EnemyManager.register_enemy_kill(self)` before queue-free.
- `CardRuntime.remove_card_at(index)` and `remove_card(index)` already remove a card and return it to the pool.
- `RunScene` already has working pause/resume flow for level-up card selection.

## File Structure

- Create `scripts/combat/elite_spawn_event.gd`
  - A resource describing one elite event: trigger time, elite scene, reward kind, and normal-spawn suppression time.
- Modify `scripts/combat/run_spawn_timeline_config.gd`
  - Replace or supplement `elite_event_seconds` with `elite_events: Array`.
  - Keep `elite_event_seconds` compatibility during migration.
- Modify `scripts/combat/enemy_manager.gd`
  - Spawn elite scene at event time.
  - Track active elite count.
  - Emit `elite_defeated(reward_kind)` when an elite dies.
- Modify `scripts/combat/enemy.gd`
  - Add elite metadata fields and route elite death to `EnemyManager`.
- Modify `config/run_spawn_timeline_config.tres`
  - Add the first elite event using existing enemy scene with elite stats/scale metadata.
- Modify `scripts/combat/run_scene.gd`
  - Listen for elite reward signal.
  - Pause combat.
  - Open remove-card reward flow.
  - Resume after reward.
- Create `scripts/ui/deck_remove_reward_panel.gd`
  - Minimal UI controller if existing `CardSelectUI` is not suitable for selecting from owned deck.
- Create `scenes/ui/DeckRemoveRewardPanel.tscn`
  - Shows current deck cards and emits selected index.
- Create or modify tests:
  - `tests/combat/test_spawn_director.gd`
  - `tests/cards/test_card_pick_flow.gd` or new `tests/combat/test_elite_reward_flow.gd`
- Modify `docs/测试与进度.md`
  - Mark T009 first slice as implemented and describe elite reward validation.

---

## Task 1: Add Elite Event Resource and Backward-Compatible Event Selection

**Files:**
- Create: `scripts/combat/elite_spawn_event.gd`
- Modify: `scripts/combat/run_spawn_timeline_config.gd`
- Modify: `tests/combat/test_spawn_director.gd`

- [ ] **Step 1: Write failing test for elite event resource selection**

Add to `tests/combat/test_spawn_director.gd`:

```gdscript
const EliteSpawnEventScript = preload("res://scripts/combat/elite_spawn_event.gd")


## 验证时间轴优先返回未触发的精英事件资源。
static func test_spawn_config_returns_pending_elite_event() -> void:
	var event := EliteSpawnEventScript.new()
	event.trigger_seconds = 12.0
	event.reward_kind = "remove_card"
	var config := RunSpawnTimelineConfigScript.new()
	config.elite_events = [event]

	TestSupport.assert_eq(config.elite_event_for_time(11.9, {}), null, "elite event not ready")
	TestSupport.assert_eq(config.elite_event_for_time(12.0, {}), event, "elite event ready")
	TestSupport.assert_eq(config.elite_event_for_time(20.0, {12.0: true}), null, "elite event consumed")
```

- [ ] **Step 2: Run test and verify failure**

Run:

```powershell
& 'F:\Godot_v4.6.2-stable_win64\Godot_v4.6.2-stable_win64.exe' --headless --path . --script tests/run_all_tests.gd
```

Expected:
- New test fails because `elite_spawn_event.gd`, `elite_events`, and `elite_event_for_time` do not exist.

- [ ] **Step 3: Implement `EliteSpawnEvent`**

Create `scripts/combat/elite_spawn_event.gd`:

```gdscript
extends Resource
class_name EliteSpawnEvent
## 精英刷怪事件：确定时间触发，生成指定精英场景并携带奖励类型。

## 触发时间（局内已进行秒数）。
@export var trigger_seconds: float = 150.0
## 精英敌人场景；为空时可回落到 `EnemyManager.enemy_scene`。
@export var elite_scene: PackedScene = null
## 击败后奖励类型；第一阶段使用 `remove_card`。
@export var reward_kind: String = "remove_card"
## 精英在场或事件触发后暂停普通刷怪的秒数。
@export var suppress_normal_spawn_seconds: float = 8.0
## 精英生命倍率；第一阶段由 `CombatEnemy` 接收后放大生命组件。
@export_range(1.0, 20.0, 0.1) var health_multiplier: float = 4.0
## 精英速度倍率。
@export_range(0.1, 5.0, 0.1) var move_speed_multiplier: float = 1.15
## 精英触碰伤害倍率。
@export_range(0.1, 10.0, 0.1) var touch_damage_multiplier: float = 1.5


## 返回事件是否可参与触发。
func is_valid_event() -> bool:
	return trigger_seconds >= 0.0 and not reward_kind.strip_edges().is_empty()
```

- [ ] **Step 4: Extend `RunSpawnTimelineConfig`**

Add:

```gdscript
const _EliteSpawnEventScript: GDScript = preload("res://scripts/combat/elite_spawn_event.gd")

@export var elite_events: Array = []


## 按当前时间返回第一个尚未触发的精英事件；兼容旧 `elite_event_seconds`。
func elite_event_for_time(match_seconds: float, triggered: Dictionary) -> Resource:
	for raw in elite_events:
		var event: Resource = raw as Resource
		if event == null or event.get_script() != _EliteSpawnEventScript:
			continue
		var trigger_seconds: float = float(event.get("trigger_seconds"))
		if match_seconds >= trigger_seconds and not triggered.has(trigger_seconds):
			return event
	for raw_t in elite_event_seconds:
		var t: float = float(raw_t)
		if match_seconds >= t and not triggered.has(t):
			var fallback := _EliteSpawnEventScript.new()
			fallback.trigger_seconds = t
			return fallback
	return null
```

- [ ] **Step 5: Run tests**

Expected:
- New elite event selection test passes.
- Existing spawn director tests pass.

- [ ] **Step 6: Commit**

```powershell
git add scripts/combat/elite_spawn_event.gd scripts/combat/run_spawn_timeline_config.gd tests/combat/test_spawn_director.gd
git commit -m "feat: add elite spawn event config"
```

---

## Task 2: Spawn Elite Enemy and Route Elite Death

**Files:**
- Modify: `scripts/combat/enemy_manager.gd`
- Modify: `scripts/combat/enemy.gd`
- Modify: `tests/combat/test_spawn_director.gd`

- [ ] **Step 1: Add failing test for elite event consumption**

Add:

```gdscript
## 验证 EnemyManager 能标记精英事件并记录奖励类型。
static func test_enemy_manager_marks_elite_event_and_reward() -> void:
	var event := EliteSpawnEventScript.new()
	event.trigger_seconds = 20.0
	event.reward_kind = "remove_card"
	var config := RunSpawnTimelineConfigScript.new()
	config.elite_events = [event]
	var manager := EnemyManager.new()
	manager.spawn_timeline_config = config

	var ready_event: Resource = manager.pending_elite_event_for_time(20.0)
	manager.mark_elite_event_triggered_from_event(ready_event)

	TestSupport.assert_eq(manager.last_elite_reward_kind, "remove_card", "elite reward kind stored")
	TestSupport.assert_true(not manager.should_trigger_elite_event(20.0), "elite event consumed")
```

- [ ] **Step 2: Implement elite event state helpers**

In `EnemyManager`, add:

```gdscript
signal elite_defeated(reward_kind: String)

var last_elite_reward_kind: String = ""
var _active_elite_count: int = 0


## 返回当前时间可触发的精英事件资源。
func pending_elite_event_for_time(match_seconds: float) -> Resource:
	if not _has_valid_spawn_timeline():
		return null
	if not spawn_timeline_config.has_method("elite_event_for_time"):
		return null
	return spawn_timeline_config.call("elite_event_for_time", match_seconds, _triggered_elite_event_seconds) as Resource


## 标记精英事件已触发，并记录本次奖励类型。
func mark_elite_event_triggered_from_event(event: Resource) -> void:
	if event == null:
		return
	var trigger_seconds: float = float(event.get("trigger_seconds"))
	_triggered_elite_event_seconds[trigger_seconds] = true
	last_elite_reward_kind = str(event.get("reward_kind"))
```

- [ ] **Step 3: Spawn elite at event time**

Replace current elite print block in `_update_timeline_state()`:

```gdscript
var elite_event: Resource = pending_elite_event_for_time(_match_elapsed_seconds)
if elite_event != null:
	mark_elite_event_triggered_from_event(elite_event)
	_spawn_elite_from_event(elite_event)
	print("[spawn] elite_spawned | time=%.1f reward=%s" % [_match_elapsed_seconds, last_elite_reward_kind])
```

Add:

```gdscript
## 按精英事件生成精英敌人，并写入奖励和倍率元数据。
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
			str(event.get("reward_kind")),
			float(event.get("health_multiplier")),
			float(event.get("move_speed_multiplier")),
			float(event.get("touch_damage_multiplier"))
		)
	_active_elite_count += 1
	get_units_root().add_child(enemy)
```

- [ ] **Step 4: Add elite metadata to `CombatEnemy`**

Add fields:

```gdscript
@export var is_elite: bool = false
var elite_reward_kind: String = ""
var _elite_health_multiplier: float = 1.0
var _elite_move_speed_multiplier: float = 1.0
var _elite_touch_damage_multiplier: float = 1.0
```

Add method:

```gdscript
## 标记本敌人为精英，并保存奖励类型和倍率，实际倍率在 `_ready` 中应用。
func configure_as_elite(reward_kind: String, health_multiplier: float, move_speed_multiplier: float, touch_damage_multiplier: float) -> void:
	is_elite = true
	elite_reward_kind = reward_kind
	_elite_health_multiplier = maxf(1.0, health_multiplier)
	_elite_move_speed_multiplier = maxf(0.1, move_speed_multiplier)
	_elite_touch_damage_multiplier = maxf(0.1, touch_damage_multiplier)
```

In `_ready()`, after health component lookup:

```gdscript
if is_elite:
	move_speed *= _elite_move_speed_multiplier
	touch_damage = int(round(float(touch_damage) * _elite_touch_damage_multiplier))
	if hc != null and hc.has_method("set_max_health"):
		hc.call("set_max_health", int(round(float(max_health) * _elite_health_multiplier)), true)
```

If `CombatHealthComponent` has no setter, add one in the same task with test or set exported fields before signal connection.

- [ ] **Step 5: Route elite death**

In `CombatEnemy._die()` after `em.register_enemy_kill(self)`:

```gdscript
if is_elite and em != null and is_instance_valid(em):
	em.register_elite_defeated(elite_reward_kind)
```

Add to `EnemyManager`:

```gdscript
## 精英死亡后广播奖励类型给 RunScene。
func register_elite_defeated(reward_kind: String) -> void:
	_active_elite_count = maxi(0, _active_elite_count - 1)
	emit_signal("elite_defeated", reward_kind)
```

- [ ] **Step 6: Run tests and smoke**

Expected:
- Spawn director tests pass.
- Full test harness passes.
- Main scene starts without script errors.

- [ ] **Step 7: Commit**

```powershell
git add scripts/combat/enemy_manager.gd scripts/combat/enemy.gd tests/combat/test_spawn_director.gd
git commit -m "feat: spawn elite events"
```

---

## Task 3: Add Remove-Card Reward UI Flow

**Files:**
- Create: `scripts/ui/deck_remove_reward_panel.gd`
- Create: `scenes/ui/DeckRemoveRewardPanel.tscn`
- Modify: `scripts/combat/run_scene.gd`
- Modify: `tests/combat/test_elite_reward_flow.gd`
- Modify: `tests/run_all_tests.gd`

- [ ] **Step 1: Add failing logic test for removing a card reward**

Create `tests/combat/test_elite_reward_flow.gd`:

```gdscript
extends RefCounted

const TestSupport = preload("res://tests/test_support.gd")


## 验证精英删牌奖励最终会减少手牌数量并修正指针。
static func test_card_runtime_remove_reward_reduces_deck() -> void:
	var runtime := CardRuntime.new()
	runtime.cards = [CardResource.new(0, 2), CardResource.new(1, 3), CardResource.new(2, 4)]
	runtime.current_index = 2

	runtime.remove_card_at(1)

	TestSupport.assert_eq(runtime.cards.size(), 2, "deck size after remove reward")
	TestSupport.assert_true(runtime.current_index < runtime.cards.size(), "current index remains in range")
```

Add this test path to `tests/run_all_tests.gd`.

- [ ] **Step 2: Create `DeckRemoveRewardPanel` script**

Create `scripts/ui/deck_remove_reward_panel.gd`:

```gdscript
extends Control
class_name DeckRemoveRewardPanel
## 精英删牌奖励面板：展示当前手牌列表，选择一张后发出下标。

signal card_remove_selected(index: int)

@onready var _title: Label = $Panel/VBox/Title
@onready var _list: VBoxContainer = $Panel/VBox/CardList


## 展示当前牌组，按钮下标与 `CardRuntime.cards` 对齐。
func show_deck(cards: Array) -> void:
	visible = true
	_clear_list()
	for i in range(cards.size()):
		var card: CardResource = cards[i] as CardResource
		var btn := Button.new()
		btn.text = "%d. %s" % [i + 1, card.get_full_name() if card != null else "<空牌>"]
		btn.pressed.connect(func () -> void:
			emit_signal("card_remove_selected", i)
		)
		_list.add_child(btn)


## 清理旧按钮，避免多次打开重复选项。
func _clear_list() -> void:
	for child in _list.get_children():
		child.queue_free()
```

- [ ] **Step 3: Create minimal scene**

Create `scenes/ui/DeckRemoveRewardPanel.tscn` with:

```text
Control (script DeckRemoveRewardPanel)
  Panel
    VBoxContainer (name VBox)
      Label (name Title, text "选择一张牌移除")
      VBoxContainer (name CardList)
```

- [ ] **Step 4: Wire panel into `RunScene`**

Add preload and field:

```gdscript
const _DECK_REMOVE_REWARD_SCENE := preload("res://scenes/ui/DeckRemoveRewardPanel.tscn")
var deck_remove_reward_panel: DeckRemoveRewardPanel = null
```

In `_setup_transient_hud()`:

```gdscript
deck_remove_reward_panel = _DECK_REMOVE_REWARD_SCENE.instantiate() as DeckRemoveRewardPanel
deck_remove_reward_panel.visible = false
_hud.add_child(deck_remove_reward_panel)
deck_remove_reward_panel.card_remove_selected.connect(_on_elite_remove_card_selected)
```

Add:

```gdscript
## 精英奖励入口：暂停战斗并打开删牌面板。
func _begin_elite_remove_card_reward() -> void:
	_card_pick_flow.is_selecting_cards = true
	enemy_manager.set_active(false)
	auto_attack_system.process_mode = Node.PROCESS_MODE_DISABLED
	card_runtime.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().paused = true
	_hud.process_mode = Node.PROCESS_MODE_ALWAYS
	deck_remove_reward_panel.show_deck(card_runtime.cards)


## 精英删牌奖励完成：移除指定手牌并恢复战斗。
func _on_elite_remove_card_selected(index: int) -> void:
	card_runtime.remove_card_at(index)
	deck_remove_reward_panel.visible = false
	_card_pick_flow.is_selecting_cards = false
	get_tree().paused = false
	_hud.process_mode = Node.PROCESS_MODE_INHERIT
	card_runtime.process_mode = Node.PROCESS_MODE_INHERIT
	auto_attack_system.process_mode = Node.PROCESS_MODE_INHERIT
	enemy_manager.set_active(true)
	card_hand_ui.refresh_display()
	_apply_hand_card_overlay_highlight()
```

- [ ] **Step 5: Connect elite signal**

In `_ready()` after kill count connection:

```gdscript
var elite_cb := Callable(self, "_on_elite_defeated")
if not enemy_manager.elite_defeated.is_connected(elite_cb):
	enemy_manager.elite_defeated.connect(elite_cb)
```

Add:

```gdscript
## 精英死亡奖励分发；第一阶段只支持删牌。
func _on_elite_defeated(reward_kind: String) -> void:
	if reward_kind == "remove_card":
		_begin_elite_remove_card_reward()
```

- [ ] **Step 6: Run tests**

Expected:
- `test_elite_reward_flow.gd` passes.
- Full harness passes.

- [ ] **Step 7: Commit**

```powershell
git add scripts/ui/deck_remove_reward_panel.gd scenes/ui/DeckRemoveRewardPanel.tscn scripts/combat/run_scene.gd tests/combat/test_elite_reward_flow.gd tests/run_all_tests.gd
git commit -m "feat: add elite remove-card reward"
```

---

## Task 4: Configure First Elite Event and Reward

**Files:**
- Modify: `config/run_spawn_timeline_config.tres`
- Modify: `docs/测试与进度.md`

- [ ] **Step 1: Configure first elite event**

In `config/run_spawn_timeline_config.tres`, add one `EliteSpawnEvent` sub-resource:

```text
trigger_seconds = 150.0
elite_scene = existing skelen scene
reward_kind = "remove_card"
suppress_normal_spawn_seconds = 8.0
health_multiplier = 4.0
move_speed_multiplier = 1.15
touch_damage_multiplier = 1.5
```

Set:

```text
elite_events = [SubResource("elite_150_remove_card")]
```

- [ ] **Step 2: Document T009 first slice**

In `docs/测试与进度.md`, update T009 line to:

```markdown
- [ ] T009 精英奖励：删牌/调序等（第一阶段：时间轴精英 + 击败删牌奖励已接入；调序、遗物碎片待办）
```

Add validation note:

```markdown
### 精英奖励快测

精英事件由 `config/run_spawn_timeline_config.tres` 的 `elite_events` 控制。第一阶段精英击败后触发删牌奖励，战斗暂停，选择一张当前牌组内的牌删除后恢复战斗。
```

- [ ] **Step 3: Run MCP or headless smoke**

Preferred MCP:
- Start main scene.
- Use editor/game script to advance match time or call `enemy_manager.set_match_elapsed_seconds(150.0)`.
- Verify an elite spawns.
- Kill elite through script.
- Verify remove-card panel appears.

Fallback headless:

```powershell
& 'F:\Godot_v4.6.2-stable_win64\Godot_v4.6.2-stable_win64.exe' --headless --path . --script tests/run_all_tests.gd
```

- [ ] **Step 4: Commit**

```powershell
git add config/run_spawn_timeline_config.tres docs/测试与进度.md
git commit -m "chore: configure first elite reward event"
```

---

## Task 5: Hardening and Follow-Up Boundaries

**Files:**
- Modify: `scripts/combat/enemy_manager.gd`
- Modify: `docs/superpowers/plans/2026-04-30-elite-reward-system.md`

- [ ] **Step 1: Ensure normal spawn suppression is honored**

Add to `EnemyManager`:

```gdscript
var _normal_spawn_suppressed_until_seconds: float = 0.0
```

When spawning elite:

```gdscript
_normal_spawn_suppressed_until_seconds = maxf(
	_normal_spawn_suppressed_until_seconds,
	_match_elapsed_seconds + float(event.get("suppress_normal_spawn_seconds"))
)
```

Before normal spawn timer:

```gdscript
if _match_elapsed_seconds < _normal_spawn_suppressed_until_seconds:
	return
```

- [ ] **Step 2: Add test for suppression**

Add to `tests/combat/test_spawn_director.gd`:

```gdscript
## 验证精英触发后普通刷怪可被短暂压制，避免精英节点不可读。
static func test_elite_event_suppresses_normal_spawn_window() -> void:
	var manager := EnemyManager.new()
	manager.suppress_normal_spawn_until(20.0)

	TestSupport.assert_true(manager.is_normal_spawn_suppressed(19.9), "normal spawn suppressed before deadline")
	TestSupport.assert_true(not manager.is_normal_spawn_suppressed(20.0), "normal spawn resumes at deadline")
```

Implement:

```gdscript
## 设置普通刷怪压制截止时间。
func suppress_normal_spawn_until(match_seconds: float) -> void:
	_normal_spawn_suppressed_until_seconds = maxf(_normal_spawn_suppressed_until_seconds, match_seconds)


## 返回当前是否仍处于普通刷怪压制窗口。
func is_normal_spawn_suppressed(match_seconds: float) -> bool:
	return match_seconds < _normal_spawn_suppressed_until_seconds
```

- [ ] **Step 3: Confirm deferred scope**

Do not implement in this pass:
- Elite affix system.
- Relic reward selection.
- Boss mechanics.
- Gold reward formulas.
- Multiple elite enemy types beyond config compatibility.

- [ ] **Step 4: Final verification**

Run:

```powershell
git diff --check
& 'F:\Godot_v4.6.2-stable_win64\Godot_v4.6.2-stable_win64.exe' --headless --path . --script tests/run_all_tests.gd
```

If MCP is connected, additionally:
- `reload_project`
- run main scene
- trigger elite event through script
- inspect editor errors

- [ ] **Step 5: Commit**

```powershell
git add scripts/combat/enemy_manager.gd tests/combat/test_spawn_director.gd docs/superpowers/plans/2026-04-30-elite-reward-system.md
git commit -m "chore: harden elite spawn suppression"
```

---

## Expected Final Behavior

- Elite timing is configured through `config/run_spawn_timeline_config.tres`.
- At the configured time, `EnemyManager` spawns an elite using existing spawn-position logic.
- Elite is visually and mechanically stronger through first-pass multipliers.
- Elite death emits a reward event.
- First reward type is `remove_card`.
- Run pauses for reward selection and resumes after deleting a card.
- Normal enemy spawn can be suppressed briefly around elite events.

## Deferred Work

- Elite affixes from `详细设计.md` §19.
- Multi-choice elite reward table.
- Relic reward system.
- Boss entity and boss reward flow.
- Gold/meta economy.
