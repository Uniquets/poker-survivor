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
