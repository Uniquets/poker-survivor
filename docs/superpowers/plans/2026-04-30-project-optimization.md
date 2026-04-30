# Project Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stabilize the current Poker Survivor codebase by adding regression checks around card rules and effect generation, then reduce coupling in the combat flow without changing gameplay behavior.

**Architecture:** Keep the existing pipeline: `CardRuntime` emits groups, `AutoAttackSystem` builds `PlayContext`, card-side resolvers produce `PlayPlan`, and `CombatEffectRunner` consumes commands. The first optimization pass adds verification around this pipeline before any refactor, then extracts only narrow responsibilities from `RunScene`.

**Tech Stack:** Godot 4.6, GDScript, Godot MCP Pro, existing `.tres` resources, repository docs under `docs/`.

---

## Current Baseline

- Last checkpoint commit: `5e549a9 chore: checkpoint current project changes`.
- Working tree should start clean before implementation.
- Current critical path:
  - `scripts/cards/group_detector.gd`
  - `scripts/cards/card_runtime.gd`
  - `scripts/combat/auto_attack_system.gd`
  - `scripts/cards/play_shape_table_resolver.gd`
  - `scripts/cards/play_shape_effect_assembler.gd`
  - `scripts/combat/combat_effect_runner.gd`
  - `scripts/combat/run_scene.gd`

## Task 1: Establish A Minimal Regression Harness

**Files:**
- Create: `tests/cards/test_group_detector.gd`
- Create: `tests/cards/test_effect_pipeline.gd`
- Create: `tests/run_all_tests.gd`
- Modify: `docs/测试与进度.md`

- [x] Step 1: Create `tests/cards/test_group_detector.gd` with direct checks for group detection.

Required cases:
- `Q, K, A` returns `STRAIGHT` with length 3.
- `A, 2, 3` does not become a straight and falls back to `SINGLE`.
- `7, 7` returns `PAIR`.
- `7, 7, 7` returns `THREE_OF_A_KIND`.
- `7, 7, 7, 7` returns `FOUR_OF_A_KIND`.
- `5, 5, 6, 7, 8` documents and locks the current longest-group behavior.

- [x] Step 2: Create `tests/cards/test_effect_pipeline.gd` with command-level checks.

Required cases:
- A single rank 2 group generates a presentational projectile or waypoint command.
- Pair/triple/four rank 2 groups increase command count or command fields according to `config/card_shape_config.tres`.
- Rank 3 pair and triple generate the currently intended meteor command variants.
- Rank 10 generates logical heal/invulnerable commands where configured.
- A non-special fallback hand still produces a default projectile plan.

- [x] Step 3: Create `tests/run_all_tests.gd` as the single entry point.

Behavior:
- Loads each test script.
- Runs each exported or static test function.
- Prints `[test] PASS` or `[test] FAIL` per case.
- Exits with failure if any assertion fails when run headless.

- [x] Step 4: Run the test harness.

Run one of these, depending on local Godot availability:

```powershell
godot --headless --path . --script tests/run_all_tests.gd
```

If local `godot` is unavailable, use Godot MCP Pro to execute the equivalent script in the editor.

Expected:
- All new group detector tests pass.
- Any current mismatch in effect pipeline is captured as a failing test before implementation changes.

- [x] Step 5: Update `docs/测试与进度.md`.

Add a short section named `自动化回归入口` documenting:
- Test entry script: `tests/run_all_tests.gd`
- When to run it: after changes under `scripts/cards/`, `scripts/combat/`, or `config/card_shape_config.tres`
- MCP fallback: use Godot MCP Pro if command-line Godot is unavailable

## Task 2: Normalize Effect Pipeline Fallbacks

**Files:**
- Modify: `scripts/cards/play_shape_table_resolver.gd`
- Modify: `scripts/cards/play_shape_effect_assembler.gd`
- Modify: `scripts/combat/combat_effect_runner.gd`
- Test: `tests/cards/test_auto_attack_debug.gd`

- [x] Step 1: Add failing tests for missing or partial effect specs.

Required cases:
- Missing per-entry projectile scene falls back to catalog default.
- Missing fire/hit audio falls back to catalog default.
- Unknown `effect_spec` script produces a warning and no command, not a crash.

- [x] Step 2: Centralize fallback behavior inside `PlayShapeEffectAssembler`.

Rules to preserve:
- Entry-level spec wins.
- Matching fallback spec from default entries is second.
- Catalog default is third.
- If still missing, command is skipped with a clear warning only when execution would otherwise fail.

- [x] Step 3: Keep `CombatEffectRunner` execution defensive but thin.

Expected behavior:
- Runner does not know card rules.
- Runner validates required scene/method fields before spawning.
- Runner warning messages include command kind and missing resource path when available.

- [x] Step 4: Run regression harness.

Run:

```powershell
godot --headless --path . --script tests/run_all_tests.gd
```

Expected:
- Group detector tests still pass.
- Effect pipeline fallback tests pass.

- [x] Step 5: Run Godot MCP smoke for one combat path.

Required MCP coverage:
- `play_scene` main scene.
- Complete opening selection or inject test cards through script.
- Trigger at least one rank 2 or rank 3 group.
- Check editor errors.
- Stop scene.

## Task 3: Gate Debug Logging

**Files:**
- Modify: `scripts/combat/auto_attack_system.gd`
- Modify: `scripts/core/game_global_config.gd` or another existing config resource if it already owns debug switches
- Modify: matching `.tres` config if needed
- Test: `tests/cards/test_effect_pipeline.gd`

- [x] Step 1: Add a debug flag for effect-plan logging.

Preferred location:
- Existing global config if it is already loaded through `GameConfig.GAME_GLOBAL`.

Flag:
- `@export var debug_effect_plan_logging: bool = false`

- [x] Step 2: Wrap `_debug_print_play_plan(plan)` calls behind the flag.

Expected:
- Normal gameplay no longer prints command details every group.
- Developers can re-enable logging from config.

- [x] Step 3: Run the regression harness.

Expected:
- Tests pass.
- No behavior changes in generated commands.

## Task 4: Extract Card Selection Flow From RunScene

**Files:**
- Create: `scripts/combat/card_pick_flow.gd`
- Modify: `scripts/combat/run_scene.gd`
- Test: existing MCP smoke plus future flow tests

- [x] Step 1: Identify selection-state fields currently owned by `RunScene`.

Move candidates:
- `_is_selecting_cards`
- `_total_selection_count`
- `_current_selection_count`
- `_selected_cards`
- `_card_pick_mode`
- `_pending_level_up_card_picks`

- [x] Step 2: Create `CardPickFlow`.

Responsibilities:
- Track opening selection state.
- Track level-up pending pick count.
- Decide current pick mode.
- Expose methods for starting opening selection, starting level-up selection, completing a pick, and skipping a level-up offer.

Non-responsibilities:
- It must not directly spawn player/enemies.
- It must not update health/XP HUD.
- It must not execute combat effects.

- [x] Step 3: Rewire `RunScene` to delegate selection decisions.

Expected:
- `RunScene` still owns scene nodes and pause state.
- `CardPickFlow` owns selection bookkeeping.
- Existing UI signals keep their current external behavior.

- [x] Step 4: Run MCP smoke for selection paths.

Required paths:
- Opening three picks starts combat.
- Level-up queues one pick and resumes combat afterward.
- Skip during level-up resumes correctly.
- Test-menu add-card flow still works.

## Task 5: Extract HUD Refresh Responsibilities

**Files:**
- Create: `scripts/ui/run_hud_controller.gd`
- Modify: `scripts/combat/run_scene.gd`
- Modify: `scenes/main/RunScene.tscn` only if adding a node is cleaner than script-only composition

- [x] Step 1: Move pure HUD refresh methods.

Move candidates:
- `_refresh_health_ui`
- `_refresh_progression_ui`
- `_refresh_match_clock_label`
- `_refresh_kill_count_label`
- `_init_mix_shuffle_bar`
- `_update_hud_mix_shuffle_bar`
- `_apply_hand_card_overlay_highlight`

- [x] Step 2: Keep gameplay state outside the HUD controller.

Expected:
- HUD controller receives values and node references.
- HUD controller does not read `EnemyManager` or `CardRuntime` unless passed explicit values.
- `RunScene` remains responsible for when values change.

- [x] Step 3: Run MCP smoke for visible UI.

Required checks:
- Health text updates after damage or setup.
- XP bar displays level and segment.
- Kill counter updates.
- Shuffle/mix bar still fills during assembly wait.

## Task 6: Configuration Validation Pass

**Files:**
- Modify: `scripts/cards/play_shape_catalog.gd`
- Modify: `scripts/core/card_draw_probability_config.gd` if needed
- Modify: `scripts/core/combat_mechanics_tuning.gd` if needed
- Test: `tests/cards/test_effect_pipeline.gd`

- [x] Step 1: Add validation helpers for shape catalog entries.

Check:
- Every entry has a display name.
- Every entry has an `effect_spec`.
- Every command-producing spec has required scenes or known fallback scenes.

- [x] Step 2: Call validation in test harness.

Expected:
- Test fails with a readable message if a required config is missing.

- [x] Step 3: Document validation expectations.

Modify `docs/工程规范.md`:
- Add one paragraph saying config resources must fail loudly through validation tests when required fields are absent.

## Execution Order

1. Task 1
2. Task 2
3. Task 3
4. Task 4
5. Task 5
6. Task 6

Do not start Task 4 until Tasks 1 and 2 are passing. `RunScene` refactoring without tests would make selection regressions hard to isolate.

## Commit Plan

- Commit after Task 1: `test: add card rule regression harness`
- Commit after Task 2: `refactor: normalize shape effect fallbacks`
- Commit after Task 3: `chore: gate effect debug logging`
- Commit after Task 4: `refactor: extract card pick flow`
- Commit after Task 5: `refactor: extract run hud controller`
- Commit after Task 6: `test: validate shape catalog configuration`

## Verification Summary

Every task that changes scripts must run:

```powershell
godot --headless --path . --script tests/run_all_tests.gd
```

When command-line Godot is unavailable, use Godot MCP Pro and report:
- scene launched,
- action simulated or script executed,
- relevant state checked,
- editor errors checked,
- scene stopped.
