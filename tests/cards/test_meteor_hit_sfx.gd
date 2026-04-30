extends RefCounted

const TestSupport = preload("res://tests/test_support.gd")


static func test_meteor_impact_uses_catalog_default_hit_sfx() -> void:
	var cat: PlayShapeCatalog = load("res://config/card_shape_config.tres") as PlayShapeCatalog
	TestSupport.assert_true(cat != null, "shape catalog exists")
	TestSupport.assert_true(cat.default_hit_sfx_first != null, "catalog default hit sfx exists")
	var meteor_script: Script = ResourceLoader.load(
		"res://scripts/combat/meteor_strike.gd",
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as Script
	TestSupport.assert_true(meteor_script != null, "meteor script loads")
	var meteor = meteor_script.new()
	TestSupport.assert_true(meteor.has_method("resolve_impact_hit_sfx"), "meteor hit sfx resolver exists")
	TestSupport.assert_eq(
		meteor.call("resolve_impact_hit_sfx"),
		cat.default_hit_sfx_first,
		"meteor impact default hit sfx"
	)
