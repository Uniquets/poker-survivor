extends RefCounted

const TestSupport = preload("res://tests/test_support.gd")


static func test_default_shape_catalog_is_complete() -> void:
	var catalog: PlayShapeCatalog = load("res://config/card_shape_config.tres") as PlayShapeCatalog
	TestSupport.assert_true(catalog != null, "default shape catalog loads")
	if catalog == null:
		return
	var errors: Array[String] = catalog.collect_validation_errors()
	TestSupport.assert_true(
		errors.is_empty(),
		"default shape catalog validation errors: %s" % "\n".join(errors)
	)


static func test_validation_reports_missing_entry_fields() -> void:
	var catalog := PlayShapeCatalog.new()
	var entry := PlayShapeEntry.new()
	catalog.shape_dic = {"BROKEN": entry}

	var errors: Array[String] = catalog.collect_validation_errors()

	TestSupport.assert_true(
		errors.has("BROKEN: display_name is empty"),
		"missing display_name is reported"
	)
	TestSupport.assert_true(
		errors.has("BROKEN: effect_spec is missing"),
		"missing effect_spec is reported"
	)


static func test_validation_reports_missing_projectile_sfx_fallbacks() -> void:
	var catalog := PlayShapeCatalog.new()
	var entry := PlayShapeEntry.new()
	entry.display_name = "缺音效弹道"
	entry.effect_spec = ShapeParallelVolleyEffectSpec.new()
	catalog.default_projectile_scene = load("res://scenes/combat/ParallelStraightCardProjectile.tscn")
	catalog.shape_dic = {"BROKEN": entry}

	var errors: Array[String] = catalog.collect_validation_errors()

	TestSupport.assert_true(
		errors.has("BROKEN: fire_sfx is missing and no fallback default_fire_sfx is configured"),
		"missing fire sfx fallback is reported"
	)
	TestSupport.assert_true(
		errors.has("BROKEN: hit_sfx_first is missing and no fallback default_hit_sfx_first is configured"),
		"missing first-hit sfx fallback is reported"
	)
	TestSupport.assert_true(
		errors.has("BROKEN: hit_sfx_pierce is missing and no fallback default_hit_sfx_pierce is configured"),
		"missing pierce-hit sfx fallback is reported"
	)
	TestSupport.assert_true(
		errors.has("BROKEN: hit_sfx_reroute is missing and no fallback default_hit_sfx_reroute is configured"),
		"missing reroute-hit sfx fallback is reported"
	)
