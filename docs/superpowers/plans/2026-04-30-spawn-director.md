# Spawn Director Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current fixed-interval enemy spawning with a configurable spawn director that controls normal enemy pacing, elite events, and boss entry points.

**Architecture:** Keep `EnemyManager` responsible for instantiating enemies and choosing legal spawn positions. Add resource-backed spawn timeline data and a small director layer that decides when to request normal batches, elite spawns, or boss events. Land the system incrementally so each task keeps the main scene playable.

**Tech Stack:** Godot 4.6, GDScript, `.tres` Resource configs, Godot MCP Pro, existing `RunScene`, `EnemyManager`, and test harness under `tests/`.

---

## File Structure

- Create `scripts/combat/spawn_enemy_entry.gd`
  - One weighted enemy entry in a spawn pool.
  - Holds `enemy_scene`, `weight`, `pressure_cost`, and optional per-entry batch bounds.
- Create `scripts/combat/spawn_timeline_segment.gd`
  - One time-window configuration.
  - Holds time range, spawn interval, batch size, pressure budget, hard alive cap, and enemy pool.
- Create `scripts/combat/run_spawn_timeline_config.gd`
  - Root Resource used by `EnemyManager`.
  - Holds ordered segments, elite event times, and boss time.
- Create `config/run_spawn_timeline_config.tres`
  - Default first-chapter timeline.
- Modify `scripts/combat/enemy_manager.gd`
  - Keep spawn position and instantiation logic.
  - Add director methods for current segment, pressure calculation, weighted enemy selection, and event triggering.
- Modify `scripts/combat/run_scene.gd`
  - Pass match time to `EnemyManager`.
  - Keep pause/selection/death activation behavior unchanged.
- Create `tests/combat/test_spawn_director.gd`
  - Unit-level checks for segment selection, weighted entries, pressure cap, and event timing.
- Modify `tests/run_all_tests.gd`
  - Include the new combat spawn tests.
- Modify `docs/测试与进度.md`
  - Document the new configurable spawn timeline and MCP validation expectation.

---

## Task 1: Add Spawn Timeline Resource Types

**Files:**
- Create: `scripts/combat/spawn_enemy_entry.gd`
- Create: `scripts/combat/spawn_timeline_segment.gd`
- Create: `scripts/combat/run_spawn_timeline_config.gd`
- Create: `tests/combat/test_spawn_director.gd`
- Modify: `tests/run_all_tests.gd`

- [ ] **Step 1: Write failing resource validation tests**

Add `tests/combat/test_spawn_director.gd`:

```gdscript
extends RefCounted

const TestSupport = preload("res://tests/test_support.gd")


static func test_spawn_segment_accepts_time_inside_range() -> void:
	var segment := SpawnTimelineSegment.new()
	segment.start_seconds = 30.0
	segment.end_seconds = 90.0

	TestSupport.assert_true(segment.contains_time(30.0), "segment includes start")
	TestSupport.assert_true(segment.contains_time(60.0), "segment includes middle")
	TestSupport.assert_true(not segment.contains_time(90.0), "segment excludes end")


static func test_spawn_config_returns_active_segment() -> void:
	var early := SpawnTimelineSegment.new()
	early.start_seconds = 0.0
	early.end_seconds = 60.0
	var mid := SpawnTimelineSegment.new()
	mid.start_seconds = 60.0
	mid.end_seconds = 180.0
	var config := RunSpawnTimelineConfig.new()
	config.segments = [early, mid]

	TestSupport.assert_eq(config.segment_for_time(15.0), early, "early segment selected")
	TestSupport.assert_eq(config.segment_for_time(90.0), mid, "mid segment selected")
```

Add the script path to `tests/run_all_tests.gd`:

```gdscript
"res://tests/combat/test_spawn_director.gd",
```

- [ ] **Step 2: Run the new test and verify it fails**

Run through Godot MCP Pro with the existing editor-script runner pattern.

Expected:
- The new combat test script fails to load because `SpawnTimelineSegment` and `RunSpawnTimelineConfig` do not exist.

- [ ] **Step 3: Implement `SpawnEnemyEntry`**

Create `scripts/combat/spawn_enemy_entry.gd`:

```gdscript
extends Resource
class_name SpawnEnemyEntry
## 单个刷怪池条目：配置敌人场景、权重、压力成本与单次生成数量边界。

@export var enemy_scene: PackedScene = null
@export_range(0.0, 1000.0, 0.1) var weight: float = 1.0
@export_range(0.1, 100.0, 0.1) var pressure_cost: float = 1.0
@export_range(1, 64, 1) var min_batch_count: int = 1
@export_range(1, 64, 1) var max_batch_count: int = 1


## 返回该条目是否可参与普通刷怪抽取。
func is_valid_for_spawn() -> bool:
	return enemy_scene != null and weight > 0.0 and pressure_cost > 0.0 and max_batch_count >= min_batch_count
```

- [ ] **Step 4: Implement `SpawnTimelineSegment`**

Create `scripts/combat/spawn_timeline_segment.gd`:

```gdscript
extends Resource
class_name SpawnTimelineSegment
## 一段局内刷怪时间窗：控制普通刷怪间隔、批量、压力预算、硬上限与敌人池。

@export var start_seconds: float = 0.0
@export var end_seconds: float = 60.0
@export_range(0.05, 60.0, 0.05) var spawn_interval_seconds: float = 1.5
@export_range(1, 64, 1) var min_batch_count: int = 1
@export_range(1, 64, 1) var max_batch_count: int = 1
@export_range(1.0, 1000.0, 1.0) var pressure_budget: float = 12.0
@export_range(1, 1000, 1) var hard_alive_cap: int = 24
@export var enemy_pool: Array = []


## 判断局内秒数是否落在本段 `[start_seconds, end_seconds)`。
func contains_time(match_seconds: float) -> bool:
	return match_seconds >= start_seconds and match_seconds < end_seconds


## 返回本段单次普通刷怪数量。
func roll_batch_count() -> int:
	var lo: int = maxi(1, min_batch_count)
	var hi: int = maxi(lo, max_batch_count)
	return randi_range(lo, hi)
```

- [ ] **Step 5: Implement `RunSpawnTimelineConfig`**

Create `scripts/combat/run_spawn_timeline_config.gd`:

```gdscript
extends Resource
class_name RunSpawnTimelineConfig
## 单局刷怪时间轴：普通时间段 + 精英事件时间 + Boss 入场时间。

@export var segments: Array = []
@export var elite_event_seconds: Array[float] = [150.0, 330.0, 510.0]
@export var boss_event_seconds: float = 480.0


## 按局内秒数返回当前普通刷怪段；超出所有段时返回最后一段。
func segment_for_time(match_seconds: float) -> SpawnTimelineSegment:
	var last_valid: SpawnTimelineSegment = null
	for raw in segments:
		var segment: SpawnTimelineSegment = raw as SpawnTimelineSegment
		if segment == null:
			continue
		last_valid = segment
		if segment.contains_time(match_seconds):
			return segment
	return last_valid
```

- [ ] **Step 6: Run resource tests**

Expected:
- `test_spawn_segment_accepts_time_inside_range` passes.
- `test_spawn_config_returns_active_segment` passes.

- [ ] **Step 7: Commit**

```powershell
git add scripts/combat/spawn_enemy_entry.gd scripts/combat/spawn_timeline_segment.gd scripts/combat/run_spawn_timeline_config.gd tests/combat/test_spawn_director.gd tests/run_all_tests.gd
git commit -m "feat: add spawn timeline resources"
```

---

## Task 2: Move Current Fixed Spawning Behind Timeline Config

**Files:**
- Create: `config/run_spawn_timeline_config.tres`
- Modify: `scripts/combat/enemy_manager.gd`
- Modify: `scenes/main/RunScene.tscn`
- Test: `tests/combat/test_spawn_director.gd`

- [ ] **Step 1: Add failing tests for segment pacing values**

Append to `tests/combat/test_spawn_director.gd`:

```gdscript
static func test_enemy_manager_applies_segment_pacing() -> void:
	var segment := SpawnTimelineSegment.new()
	segment.spawn_interval_seconds = 0.75
	segment.pressure_budget = 40.0
	segment.hard_alive_cap = 50
	var manager := EnemyManager.new()

	manager.apply_spawn_segment(segment)

	TestSupport.assert_eq(manager.spawn_interval_seconds, 0.75, "manager interval from segment")
	TestSupport.assert_eq(manager.max_alive_enemies, 50, "manager alive cap from segment")
	TestSupport.assert_eq(manager.current_pressure_budget, 40.0, "manager pressure budget from segment")
```

- [ ] **Step 2: Run the test and verify it fails**

Expected:
- Failure because `EnemyManager.apply_spawn_segment` and `current_pressure_budget` do not exist.

- [ ] **Step 3: Add timeline fields to `EnemyManager`**

In `scripts/combat/enemy_manager.gd`, add exports near existing spawn fields:

```gdscript
## 刷怪时间轴配置；为空时沿用本脚本旧字段，保持旧场景可运行。
@export var spawn_timeline_config: RunSpawnTimelineConfig = null
## 当前普通刷怪压力预算；由时间段写入，未配置时间轴时等同 `max_alive_enemies`。
var current_pressure_budget: float = 12.0
## 当前局内秒数；由 `RunScene` 每帧写入。
var _match_elapsed_seconds: float = 0.0
```

- [ ] **Step 4: Implement `apply_spawn_segment`**

Add to `EnemyManager`:

```gdscript
## 应用当前时间段的普通刷怪节奏；只改生成参数，不直接生成敌人。
func apply_spawn_segment(segment: SpawnTimelineSegment) -> void:
	if segment == null:
		return
	spawn_interval_seconds = segment.spawn_interval_seconds
	max_alive_enemies = segment.hard_alive_cap
	current_pressure_budget = segment.pressure_budget
```

- [ ] **Step 5: Apply current segment before spawning**

At the start of `_process(delta)` after active/target checks:

```gdscript
if spawn_timeline_config != null:
	apply_spawn_segment(spawn_timeline_config.segment_for_time(_match_elapsed_seconds))
```

Add:

```gdscript
## 由 RunScene 写入局内战斗秒数，用于时间轴选段。
func set_match_elapsed_seconds(seconds: float) -> void:
	_match_elapsed_seconds = maxf(0.0, seconds)
```

- [ ] **Step 6: Create default timeline config**

Create `config/run_spawn_timeline_config.tres` in the Godot editor or by Resource save path with three segments:

```text
0-60s: interval 1.5, batch 1-1, pressure 12, hard cap 24
60-180s: interval 1.2, batch 1-2, pressure 18, hard cap 36
180s+: interval 0.9, batch 2-3, pressure 28, hard cap 56
```

Use the existing `scenes/enemies/skelen.tscn` as the only entry in each segment with weight `1.0` and pressure cost `1.0`.

- [ ] **Step 7: Wire config into `RunScene.tscn`**

Set `EnemyManager.spawn_timeline_config = ExtResource("config/run_spawn_timeline_config.tres")`.

- [ ] **Step 8: Commit**

```powershell
git add scripts/combat/enemy_manager.gd scenes/main/RunScene.tscn config/run_spawn_timeline_config.tres tests/combat/test_spawn_director.gd
git commit -m "feat: drive enemy pacing from timeline config"
```

---

## Task 3: Add Pressure Budget and Weighted Enemy Selection

**Files:**
- Modify: `scripts/combat/enemy_manager.gd`
- Modify: `tests/combat/test_spawn_director.gd`

- [ ] **Step 1: Add failing tests for pressure cap**

Append:

```gdscript
static func test_pressure_budget_blocks_spawn_when_full() -> void:
	var manager := EnemyManager.new()
	manager.current_pressure_budget = 3.0

	TestSupport.assert_true(manager.can_spawn_with_pressure(2.0), "pressure below budget can spawn")
	TestSupport.assert_true(not manager.can_spawn_with_pressure(4.0), "pressure above budget blocks spawn")
```

- [ ] **Step 2: Implement pressure helpers**

Add to `EnemyManager`:

```gdscript
## 判断加入指定压力后是否仍在当前预算内。
func can_spawn_with_pressure(extra_pressure: float) -> bool:
	return _alive_enemy_pressure() + maxf(0.0, extra_pressure) <= current_pressure_budget


## 当前场上敌人压力；初版按每只普通怪 1 计，后续可由敌实例或生成条目写入。
func _alive_enemy_pressure() -> float:
	var total: float = 0.0
	for c in get_units_root().get_children():
		var ce := c as CombatEnemy
		if ce == null or ce.is_dead():
			continue
		total += 1.0
	return total
```

- [ ] **Step 3: Add weighted entry selection**

Add:

```gdscript
## 从当前段敌人池按权重抽一个有效条目。
func pick_enemy_entry(segment: SpawnTimelineSegment) -> SpawnEnemyEntry:
	if segment == null:
		return null
	var total: float = 0.0
	var valid: Array[SpawnEnemyEntry] = []
	for raw in segment.enemy_pool:
		var entry: SpawnEnemyEntry = raw as SpawnEnemyEntry
		if entry == null or not entry.is_valid_for_spawn():
			continue
		valid.append(entry)
		total += entry.weight
	if total <= 0.0:
		return null
	var roll: float = randf() * total
	for entry in valid:
		roll -= entry.weight
		if roll <= 0.0:
			return entry
	return valid.back()
```

- [ ] **Step 4: Use entry selection in ordinary spawning**

Replace the single `_spawn_enemy()` call path so when a segment exists:

```gdscript
var segment := spawn_timeline_config.segment_for_time(_match_elapsed_seconds)
var entry := pick_enemy_entry(segment)
if entry == null:
	return
var count := min(segment.roll_batch_count(), randi_range(entry.min_batch_count, entry.max_batch_count))
for _i in range(count):
	if _alive_enemy_count() >= max_alive_enemies:
		break
	if not can_spawn_with_pressure(entry.pressure_cost):
		break
	_spawn_enemy_from_scene(entry.enemy_scene, _pick_spawn_world_position())
```

Keep the old `_spawn_enemy()` path when `spawn_timeline_config == null`.

- [ ] **Step 5: Run all tests**

Expected:
- All existing card tests pass.
- New combat spawn tests pass.

- [ ] **Step 6: Commit**

```powershell
git add scripts/combat/enemy_manager.gd tests/combat/test_spawn_director.gd
git commit -m "feat: add spawn pressure budget"
```

---

## Task 4: Add Deterministic Elite Event Hooks

**Files:**
- Modify: `scripts/combat/run_spawn_timeline_config.gd`
- Modify: `scripts/combat/enemy_manager.gd`
- Modify: `tests/combat/test_spawn_director.gd`

- [ ] **Step 1: Add failing elite event test**

Append:

```gdscript
static func test_elite_event_triggers_once_after_time() -> void:
	var config := RunSpawnTimelineConfig.new()
	config.elite_event_seconds = [10.0]
	var manager := EnemyManager.new()
	manager.spawn_timeline_config = config

	TestSupport.assert_true(not manager.should_trigger_elite_event(9.9), "elite not before time")
	TestSupport.assert_true(manager.should_trigger_elite_event(10.0), "elite triggers at time")
	manager.mark_elite_event_triggered(10.0)
	TestSupport.assert_true(not manager.should_trigger_elite_event(12.0), "elite does not repeat")
```

- [ ] **Step 2: Implement elite event state**

Add to `EnemyManager`:

```gdscript
## 已触发的精英事件时间，避免同一事件重复刷。
var _triggered_elite_event_seconds: Dictionary = {}


## 判断当前时间是否应该触发某个尚未触发的精英事件。
func should_trigger_elite_event(match_seconds: float) -> bool:
	if spawn_timeline_config == null:
		return false
	for t in spawn_timeline_config.elite_event_seconds:
		if match_seconds >= t and not _triggered_elite_event_seconds.has(t):
			return true
	return false


## 标记不大于当前时间的第一个精英事件已触发。
func mark_elite_event_triggered(match_seconds: float) -> void:
	if spawn_timeline_config == null:
		return
	for t in spawn_timeline_config.elite_event_seconds:
		if match_seconds >= t and not _triggered_elite_event_seconds.has(t):
			_triggered_elite_event_seconds[t] = true
			return
```

- [ ] **Step 3: Wire event hook without full reward system**

In `_process(delta)`, before normal spawn timer:

```gdscript
if should_trigger_elite_event(_match_elapsed_seconds):
	mark_elite_event_triggered(_match_elapsed_seconds)
	print("[spawn] elite_event_ready | time=%.1f" % _match_elapsed_seconds)
```

This task only creates deterministic event hooks; actual elite enemy template and reward entry are next work.

- [ ] **Step 4: Commit**

```powershell
git add scripts/combat/enemy_manager.gd tests/combat/test_spawn_director.gd
git commit -m "feat: add elite spawn event hooks"
```

---

## Task 5: Add Boss Event Hook and Stop Normal Spawning

**Files:**
- Modify: `scripts/combat/enemy_manager.gd`
- Modify: `tests/combat/test_spawn_director.gd`

- [ ] **Step 1: Add failing boss mode test**

Append:

```gdscript
static func test_boss_event_enters_boss_mode_once() -> void:
	var config := RunSpawnTimelineConfig.new()
	config.boss_event_seconds = 30.0
	var manager := EnemyManager.new()
	manager.spawn_timeline_config = config

	TestSupport.assert_true(not manager.should_enter_boss_mode(29.0), "boss not before time")
	TestSupport.assert_true(manager.should_enter_boss_mode(30.0), "boss starts at time")
	manager.mark_boss_mode_started()
	TestSupport.assert_true(not manager.should_enter_boss_mode(60.0), "boss does not restart")
	TestSupport.assert_true(manager.is_boss_mode_active(), "boss mode active")
```

- [ ] **Step 2: Implement boss mode state**

Add:

```gdscript
## Boss 模式开启后普通刷怪停止，后续由 Boss 行为或事件单独召唤小怪。
var _boss_mode_active: bool = false


## 判断是否到达 Boss 入场时间。
func should_enter_boss_mode(match_seconds: float) -> bool:
	return spawn_timeline_config != null and not _boss_mode_active and match_seconds >= spawn_timeline_config.boss_event_seconds


## 标记 Boss 模式已开始。
func mark_boss_mode_started() -> void:
	_boss_mode_active = true


## 返回当前是否处于 Boss 模式。
func is_boss_mode_active() -> bool:
	return _boss_mode_active
```

- [ ] **Step 3: Stop ordinary spawning in boss mode**

In `_process(delta)`, before normal spawn timer:

```gdscript
if should_enter_boss_mode(_match_elapsed_seconds):
	mark_boss_mode_started()
	print("[spawn] boss_event_started | time=%.1f" % _match_elapsed_seconds)
if _boss_mode_active:
	return
```

- [ ] **Step 4: Commit**

```powershell
git add scripts/combat/enemy_manager.gd tests/combat/test_spawn_director.gd
git commit -m "feat: add boss spawn event hook"
```

---

## Task 6: Connect Match Time and Verify In-Game Pacing

**Files:**
- Modify: `scripts/combat/run_scene.gd`
- Modify: `docs/测试与进度.md`

- [ ] **Step 1: Pass match time into EnemyManager**

In `RunScene`, where `_match_display_seconds` is updated, add:

```gdscript
if enemy_manager != null:
	enemy_manager.set_match_elapsed_seconds(_match_display_seconds)
```

- [ ] **Step 2: Document spawn director**

Add to `docs/测试与进度.md` under the enemy/spawn area:

```markdown
### 刷怪时间轴

敌人生成由 `EnemyManager` 读取 `config/run_spawn_timeline_config.tres` 控制。时间轴段决定普通怪生成间隔、单批数量、压力预算与硬上限；精英和 Boss 使用确定时间事件，不用随机概率控制主节奏。普通怪池内的敌种选择使用权重。
```

- [ ] **Step 3: Run full regression through Godot MCP Pro**

Expected:
- Test harness passes.
- Main scene runs for at least 5 seconds.
- `get_editor_errors` has no new script errors after clearing old logs.

- [ ] **Step 4: Commit**

```powershell
git add scripts/combat/run_scene.gd docs/测试与进度.md
git commit -m "chore: document spawn director timeline"
```

---

## Verification Summary

After every task that changes scripts:

1. Run the relevant test script through Godot MCP Pro.
2. Run the full `tests/run_all_tests.gd` equivalent through Godot MCP Pro.
3. Clear editor output, run `main` for at least 2 seconds, then inspect editor errors.
4. Run `git diff --check`.

Expected final state:
- Normal enemies are still spawned offscreen near the camera.
- Current gameplay remains playable with one existing enemy type.
- Spawn interval, batch size, pressure budget, hard cap, elite times, and boss time are configurable from `config/run_spawn_timeline_config.tres`.
- Elite and Boss are deterministic event hooks, not probability-driven main pacing.
