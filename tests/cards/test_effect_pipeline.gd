extends RefCounted

const TestSupport = preload("res://tests/test_support.gd")
const CmdScript = preload("res://scripts/cards/play_effect_command.gd")


## 创建一张测试牌；花色默认黑桃，伤害使用点数，保持测试输入可读。
static func _card(rank: int, suit: int = 0) -> CardResource:
	var c := CardResource.new(suit, rank)
	c.damage = rank
	return c


## 构造效果解析上下文，模拟 AutoAttackSystem 传给牌型表解析器的最小输入。
static func _ctx(cards: Array, group_type_name: String):
	var ctx := PlayContext.new()
	ctx.cards = cards
	ctx.group_type = GameRules.group_type_from_detector_string(group_type_name)
	ctx.global_suit_counts = [0, 0, 0, 0]
	ctx.player_max_health = 100
	ctx.player_attack_damage_coefficient = 1.0
	return ctx


## 运行牌型表解析；若未命中则回落旧解析器，贴近 AutoAttackSystem 的真实路径。
static func _resolve(cards: Array, group_type_name: String):
	var resolver := PlayShapeTableResolver.new()
	var ctx = _ctx(cards, group_type_name)
	var plan = resolver.try_resolve(ctx)
	if plan == null:
		plan = PlayEffectResolver.new().resolve(ctx)
	return plan


## 返回指定 kind 的第一条命令，找不到时返回 null。
static func _first_command(plan, kind: int):
	for cmd in plan.commands:
		if cmd != null and cmd.get_script() == CmdScript and int(cmd.kind) == kind:
			return cmd
	return null


static func _entry_with_spec(spec: Resource) -> PlayShapeEntry:
	var entry := PlayShapeEntry.new()
	entry.display_name = "test"
	entry.effect_spec = spec
	return entry


static func _default_catalog_for_fallback_tests() -> PlayShapeCatalog:
	var source_cat: PlayShapeCatalog = load("res://config/card_shape_config.tres") as PlayShapeCatalog
	TestSupport.assert_true(source_cat != null, "shape catalog exists")
	TestSupport.assert_true(source_cat.default_projectile_scene != null, "catalog default projectile exists")
	TestSupport.assert_true(source_cat.default_hit_sfx_first != null, "catalog default hit sfx exists")
	var cat := PlayShapeCatalog.new()
	cat.default_projectile_scene = source_cat.default_projectile_scene
	cat.default_fire_sfx = source_cat.default_hit_sfx_first
	cat.default_hit_sfx_first = source_cat.default_hit_sfx_first
	cat.default_hit_sfx_pierce = source_cat.default_hit_sfx_first
	cat.default_hit_sfx_reroute = source_cat.default_hit_sfx_first
	return cat


static func _assemble_entry(entry: PlayShapeEntry, catalog: PlayShapeCatalog, default_entries: Array = []) -> PlayPlan:
	var plan := PlayPlan.new()
	PlayShapeEffectAssembler.append_shape_entry_effect_commands(
		plan,
		entry,
		_ctx([_card(4)], "SINGLE"),
		default_entries,
		catalog
	)
	return plan


## 单张 2 应生成表现相弹道命令。
static func test_rank2_single_generates_projectile_command() -> void:
	var plan = _resolve([_card(2)], "SINGLE")
	var cmd = _first_command(plan, CmdScript.CmdKind.PROJECTILE_VOLLEY)
	TestSupport.assert_true(cmd != null, "rank2 single projectile command exists")
	TestSupport.assert_true(cmd.count >= 1, "rank2 single projectile count")
	TestSupport.assert_eq(cmd.phase, CmdScript.PHASE_PRESENTATIONAL, "rank2 single phase")


## 对子 2 的弹道数应不小于单张 2。
static func test_rank2_pair_has_at_least_single_projectile_count() -> void:
	var single = _first_command(_resolve([_card(2)], "SINGLE"), CmdScript.CmdKind.PROJECTILE_VOLLEY)
	var pair = _first_command(_resolve([_card(2), _card(2)], "PAIR"), CmdScript.CmdKind.PROJECTILE_VOLLEY)
	TestSupport.assert_true(single != null, "rank2 single command")
	TestSupport.assert_true(pair != null, "rank2 pair command")
	TestSupport.assert_true(pair.count >= single.count, "rank2 pair count grows")


## 对子 3 当前应启用环火分档：命令中打开椭圆火焰。
static func test_rank3_pair_uses_ellipse_fire_meteor_variant() -> void:
	var cmd = _first_command(_resolve([_card(3), _card(3)], "PAIR"), CmdScript.CMD_METEOR_STORM)
	TestSupport.assert_true(cmd != null, "rank3 pair meteor command")
	TestSupport.assert_true(cmd.meteor_enable_ellipse_fire, "rank3 pair ellipse fire")


## 三条 3 当前应启用二段爆炸分档。
static func test_rank3_triple_uses_end_explosion_meteor_variant() -> void:
	var cmd = _first_command(_resolve([_card(3), _card(3), _card(3)], "THREE_OF_A_KIND"), CmdScript.CMD_METEOR_STORM)
	TestSupport.assert_true(cmd != null, "rank3 triple meteor command")
	TestSupport.assert_true(cmd.meteor_enable_end_explosion, "rank3 triple end explosion")


## 单张 10 应生成按最大生命百分比治疗命令。
static func test_rank10_single_generates_heal_command() -> void:
	var cmd = _first_command(_resolve([_card(10)], "SINGLE"), CmdScript.CmdKind.HEAL_PERCENT_MAX)
	TestSupport.assert_true(cmd != null, "rank10 heal command")
	TestSupport.assert_true(cmd.heal_ratio > 0.0, "rank10 heal ratio")


## 非专属牌型应仍有默认表现命令，避免空计划导致出牌无反馈。
static func test_non_special_falls_back_to_default_projectile() -> void:
	var cmd = _first_command(_resolve([_card(4)], "SINGLE"), CmdScript.CmdKind.PROJECTILE_VOLLEY)
	TestSupport.assert_true(cmd != null, "fallback projectile command")
	TestSupport.assert_true(cmd.count >= 1, "fallback projectile count")


static func test_parallel_spec_uses_catalog_defaults_when_fields_are_missing() -> void:
	var cat := _default_catalog_for_fallback_tests()
	var spec := ShapeParallelVolleyEffectSpec.new()
	spec.projectile_scene = null
	spec.fire_sfx = null
	spec.hit_sfx_first = null
	spec.hit_sfx_pierce = null
	spec.hit_sfx_reroute = null
	var cmd = _first_command(
		_assemble_entry(_entry_with_spec(spec), cat),
		CmdScript.CmdKind.PROJECTILE_VOLLEY
	)
	TestSupport.assert_true(cmd != null, "parallel fallback command")
	TestSupport.assert_eq(cmd.projectile_scene_override, cat.default_projectile_scene, "parallel projectile fallback")
	TestSupport.assert_eq(cmd.sfx_fire, cat.default_fire_sfx, "parallel fire sfx fallback")
	TestSupport.assert_eq(cmd.sfx_hit_first, cat.default_hit_sfx_first, "parallel hit sfx fallback")
	TestSupport.assert_eq(cmd.sfx_hit_pierce, cat.default_hit_sfx_pierce, "parallel pierce sfx fallback")
	TestSupport.assert_eq(cmd.sfx_hit_reroute, cat.default_hit_sfx_reroute, "parallel reroute sfx fallback")


static func test_waypoint_spec_uses_catalog_defaults_when_fields_are_missing() -> void:
	var cat := _default_catalog_for_fallback_tests()
	var spec := ShapeWaypointVolleyEffectSpec.new()
	spec.waypoint_projectile_scene = null
	spec.fire_sfx = null
	spec.hit_sfx_first = null
	spec.hit_sfx_pierce = null
	spec.hit_sfx_reroute = null
	var cmd = _first_command(
		_assemble_entry(_entry_with_spec(spec), cat),
		CmdScript.CmdKind.WAYPOINT_VOLLEY
	)
	TestSupport.assert_true(cmd != null, "waypoint fallback command")
	TestSupport.assert_eq(cmd.waypoint_projectile_scene_override, cat.default_projectile_scene, "waypoint projectile fallback")
	TestSupport.assert_eq(cmd.sfx_fire, cat.default_fire_sfx, "waypoint fire sfx fallback")
	TestSupport.assert_eq(cmd.sfx_hit_first, cat.default_hit_sfx_first, "waypoint hit sfx fallback")
	TestSupport.assert_eq(cmd.sfx_hit_pierce, cat.default_hit_sfx_pierce, "waypoint pierce sfx fallback")
	TestSupport.assert_eq(cmd.sfx_hit_reroute, cat.default_hit_sfx_reroute, "waypoint reroute sfx fallback")


static func test_rank2_table_command_carries_complete_default_hit_sfx() -> void:
	var source_cat: PlayShapeCatalog = load("res://config/card_shape_config.tres") as PlayShapeCatalog
	var cmd = _first_command(_resolve([_card(2)], "SINGLE"), CmdScript.CmdKind.PROJECTILE_VOLLEY)
	TestSupport.assert_true(cmd != null, "rank2 table projectile command")
	TestSupport.assert_eq(cmd.sfx_fire, source_cat.default_fire_sfx, "rank2 table fire sfx")
	TestSupport.assert_eq(cmd.sfx_hit_first, source_cat.default_hit_sfx_first, "rank2 table first-hit sfx")
	TestSupport.assert_eq(cmd.sfx_hit_pierce, source_cat.default_hit_sfx_pierce, "rank2 table pierce-hit sfx")
	TestSupport.assert_eq(cmd.sfx_hit_reroute, source_cat.default_hit_sfx_reroute, "rank2 table reroute-hit sfx")


static func test_rank2_four_kind_waypoint_command_carries_complete_default_hit_sfx() -> void:
	var source_cat: PlayShapeCatalog = load("res://config/card_shape_config.tres") as PlayShapeCatalog
	var cmd = _first_command(
		_resolve([_card(2), _card(2), _card(2), _card(2)], "FOUR_OF_A_KIND"),
		CmdScript.CmdKind.WAYPOINT_VOLLEY
	)
	TestSupport.assert_true(cmd != null, "rank2 four-kind waypoint command")
	TestSupport.assert_eq(cmd.sfx_fire, source_cat.default_fire_sfx, "rank2 waypoint fire sfx")
	TestSupport.assert_eq(cmd.sfx_hit_first, source_cat.default_hit_sfx_first, "rank2 waypoint first-hit sfx")
	TestSupport.assert_eq(cmd.sfx_hit_pierce, source_cat.default_hit_sfx_pierce, "rank2 waypoint pierce-hit sfx")
	TestSupport.assert_eq(cmd.sfx_hit_reroute, source_cat.default_hit_sfx_reroute, "rank2 waypoint reroute-hit sfx")


static func test_missing_local_projectile_scene_uses_global_catalog_fallback() -> void:
	var cat := PlayShapeCatalog.new()
	var parallel_plan := _assemble_entry(_entry_with_spec(ShapeParallelVolleyEffectSpec.new()), cat)
	var waypoint_plan := _assemble_entry(_entry_with_spec(ShapeWaypointVolleyEffectSpec.new()), cat)
	TestSupport.assert_true(parallel_plan.commands.size() > 0, "parallel global fallback command count")
	TestSupport.assert_true(waypoint_plan.commands.size() > 0, "waypoint global fallback command count")


static func test_unknown_effect_spec_is_ignored_without_command() -> void:
	var cat := _default_catalog_for_fallback_tests()
	var plan := _assemble_entry(_entry_with_spec(Resource.new()), cat)
	TestSupport.assert_eq(plan.commands.size(), 0, "unknown spec command count")
