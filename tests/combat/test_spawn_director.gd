extends RefCounted

const TestSupport = preload("res://tests/test_support.gd")
const SpawnTimelineSegmentScript = preload("res://scripts/combat/spawn_timeline_segment.gd")
const RunSpawnTimelineConfigScript = preload("res://scripts/combat/run_spawn_timeline_config.gd")


## 验证时间段采用左闭右开区间，避免相邻段边界重复命中。
static func test_spawn_segment_accepts_time_inside_range() -> void:
	var segment := SpawnTimelineSegmentScript.new()
	segment.start_seconds = 30.0
	segment.end_seconds = 90.0

	TestSupport.assert_true(segment.contains_time(30.0), "segment includes start")
	TestSupport.assert_true(segment.contains_time(60.0), "segment includes middle")
	TestSupport.assert_true(not segment.contains_time(90.0), "segment excludes end")


## 验证时间轴按局内秒数选中正确段落。
static func test_spawn_config_returns_active_segment() -> void:
	var early := SpawnTimelineSegmentScript.new()
	early.start_seconds = 0.0
	early.end_seconds = 60.0
	var mid := SpawnTimelineSegmentScript.new()
	mid.start_seconds = 60.0
	mid.end_seconds = 180.0
	var config := RunSpawnTimelineConfigScript.new()
	config.segments = [early, mid]

	TestSupport.assert_eq(config.segment_for_time(15.0), early, "early segment selected")
	TestSupport.assert_eq(config.segment_for_time(90.0), mid, "mid segment selected")


## 验证敌人管理器能把当前时间段参数应用到运行时刷怪字段。
static func test_enemy_manager_applies_segment_pacing() -> void:
	var segment := SpawnTimelineSegmentScript.new()
	segment.spawn_interval_seconds = 0.75
	segment.pressure_budget = 40.0
	segment.hard_alive_cap = 50
	var manager := EnemyManager.new()

	manager.apply_spawn_segment(segment)

	TestSupport.assert_eq(manager.spawn_interval_seconds, 0.75, "manager interval from segment")
	TestSupport.assert_eq(manager.max_alive_enemies, 50, "manager alive cap from segment")
	TestSupport.assert_eq(manager.current_pressure_budget, 40.0, "manager pressure budget from segment")


## 验证压力预算会阻止超过预算的新刷怪。
static func test_pressure_budget_blocks_spawn_when_full() -> void:
	var manager := EnemyManager.new()
	manager.current_pressure_budget = 3.0

	TestSupport.assert_true(manager.can_spawn_with_pressure(2.0), "pressure below budget can spawn")
	TestSupport.assert_true(not manager.can_spawn_with_pressure(4.0), "pressure above budget blocks spawn")


## 验证精英事件到点触发且同一时间点只触发一次。
static func test_elite_event_triggers_once_after_time() -> void:
	var config := RunSpawnTimelineConfigScript.new()
	config.elite_event_seconds = [10.0]
	var manager := EnemyManager.new()
	manager.spawn_timeline_config = config

	TestSupport.assert_true(not manager.should_trigger_elite_event(9.9), "elite not before time")
	TestSupport.assert_true(manager.should_trigger_elite_event(10.0), "elite triggers at time")
	manager.mark_elite_event_triggered(10.0)
	TestSupport.assert_true(not manager.should_trigger_elite_event(12.0), "elite does not repeat")


## 验证 Boss 到点进入 Boss 模式且不会重复开始。
static func test_boss_event_enters_boss_mode_once() -> void:
	var config := RunSpawnTimelineConfigScript.new()
	config.boss_event_seconds = 30.0
	var manager := EnemyManager.new()
	manager.spawn_timeline_config = config

	TestSupport.assert_true(not manager.should_enter_boss_mode(29.0), "boss not before time")
	TestSupport.assert_true(manager.should_enter_boss_mode(30.0), "boss starts at time")
	manager.mark_boss_mode_started()
	TestSupport.assert_true(not manager.should_enter_boss_mode(60.0), "boss does not restart")
	TestSupport.assert_true(manager.is_boss_mode_active(), "boss mode active")


## 验证未手动配置 target 时，敌人管理器会从玩家单例自动解析目标。
static func test_enemy_manager_auto_resolves_player_target() -> void:
	var root: Node = Engine.get_main_loop().root
	var manager := EnemyManager.new()
	var player := Node2D.new()
	player.add_to_group("combat_player")
	root.add_child(manager)
	root.add_child(player)

	var resolved := manager.resolve_spawn_target()

	TestSupport.assert_eq(resolved, player, "manager resolves singleton player")
	TestSupport.assert_eq(manager.target, player, "manager stores resolved player")
	manager.queue_free()
	player.queue_free()
