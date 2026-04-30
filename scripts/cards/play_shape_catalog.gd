@tool
extends Resource
class_name PlayShapeCatalog
## 牌型目录：使用 **`shape_dic`** 按 key 直读 `PlayShapeEntry`，不再依赖条目内 rank/count/group_type 字段。
## **策划主路径**：在编辑器中新建或编辑 **`.tres`**（脚本选本类），`shape_dic` 的 key 为牌型字符串（如 `2`、`22`、`ABC`、`AABBCC`）；默认文件 **`config/card_shape_config.tres`**，由 **`GameConfig.PLAY_SHAPE_CATALOG`** 预载引用（不嵌在 **`GameGlobalConfig`**）。
## **`build_fallback_catalog_from_mechanics`**：深拷贝 **`config/card_shape_config.tres`**，仅作 **`PLAY_SHAPE_CATALOG` 为 `null`** 时运行时回落；**不**在代码里写死某一点数分支，与策划表一致。


## 中文：与 **`GameConfig`** 解耦的默认表资源（避免循环引用）
const _DefaultCatalogPacked: Resource = preload("res://config/card_shape_config.tres")
const _PlayShapeEntryScript: GDScript = preload("res://scripts/cards/play_shape_entry.gd")
const _ParallelSpecScript: GDScript = preload("res://scripts/cards/shape_parallel_volley_effect_spec.gd")
const _WaypointSpecScript: GDScript = preload("res://scripts/cards/shape_waypoint_volley_effect_spec.gd")
const _ExplosiveVolleySpecScript: GDScript = preload("res://scripts/cards/shape_explosive_volley_effect_spec.gd")
const _HealInvulnSpecScript: GDScript = preload("res://scripts/cards/shape_heal_invuln_effect_spec.gd")
const _MeteorStormSpecScript: GDScript = preload("res://scripts/cards/shape_meteor_storm_effect_spec.gd")

## 牌型字典：key=牌型字符串，value=`PlayShapeEntry`
@export var shape_dic: Dictionary = {}
## 外层统一资源回落：命中条目缺少资源类配置时按本组字段补全
@export_subgroup("默认资源配置")
@export var default_projectile_scene: PackedScene = null
@export var default_fire_sfx: AudioStream = null
@export var default_hit_sfx_first: AudioStream = null
@export var default_hit_sfx_pierce: AudioStream = null
@export var default_hit_sfx_reroute: AudioStream = null


## 返回默认策划表的深拷贝，供 **`PLAY_SHAPE_CATALOG` 为 `null`** 时使用；与 **`combat_mechanics_tuning`** 的数值对齐由 **`.tres`** 与编辑器维护负责
static func build_fallback_catalog_from_mechanics() -> PlayShapeCatalog:
	var src: PlayShapeCatalog = _DefaultCatalogPacked as PlayShapeCatalog
	if src == null:
		push_error("PlayShapeCatalog: 默认目录资源类型无效")
		return PlayShapeCatalog.new()
	return src.duplicate(true) as PlayShapeCatalog


## 返回可读配置错误；测试入口用它让关键资源缺失在回归阶段直接失败。
func collect_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	var default_entries: Array = _collect_default_entries()
	for raw_key in shape_dic.keys():
		var key: String = str(raw_key)
		_validate_entry(errors, key, shape_dic[raw_key], default_entries)
	return errors


func _collect_default_entries() -> Array:
	var entries: Array = []
	var default_entry = shape_dic.get(PlayShapeMatcher.KEY_DEFAULT)
	if default_entry != null:
		entries.append(default_entry)
	return entries


func _validate_entry(errors: Array[String], key: String, raw_entry, default_entries: Array) -> void:
	if raw_entry == null or raw_entry.get_script() != _PlayShapeEntryScript:
		errors.append("%s: entry is not PlayShapeEntry" % key)
		return
	var entry: Object = raw_entry
	var display_name: String = str(entry.get("display_name")).strip_edges()
	if display_name.is_empty():
		errors.append("%s: display_name is empty" % key)
	var spec: Resource = entry.get("effect_spec") as Resource
	if spec == null:
		errors.append("%s: effect_spec is missing" % key)
		return
	_validate_spec(errors, key, spec, default_entries)


func _validate_spec(errors: Array[String], key: String, spec: Resource, default_entries: Array) -> void:
	var script: Script = spec.get_script()
	if script == _ParallelSpecScript:
		_validate_scene_fallback(
			errors,
			key,
			spec,
			default_entries,
			_ParallelSpecScript,
			"projectile_scene",
			"default_projectile_scene"
		)
		_validate_projectile_sfx_fallbacks(errors, key, spec, default_entries, _ParallelSpecScript)
		return
	if script == _WaypointSpecScript:
		_validate_scene_fallback(
			errors,
			key,
			spec,
			default_entries,
			_WaypointSpecScript,
			"waypoint_projectile_scene",
			"default_projectile_scene"
		)
		_validate_projectile_sfx_fallbacks(errors, key, spec, default_entries, _WaypointSpecScript)
		return
	if script == _ExplosiveVolleySpecScript or script == _HealInvulnSpecScript:
		return
	if script == _MeteorStormSpecScript:
		if spec.get("meteor_scene") == null:
			errors.append("%s: meteor_scene is missing" % key)
		return
	var type_hint: String = script.resource_path.get_file() if script != null else str(spec)
	errors.append("%s: unsupported effect_spec type %s" % [key, type_hint])


func _validate_scene_fallback(
	errors: Array[String],
	key: String,
	spec: Resource,
	default_entries: Array,
	spec_script: Script,
	spec_field: String,
	catalog_field: String
) -> void:
	if _resolve_scene_fallback(spec, default_entries, spec_script, spec_field, catalog_field) == null:
		errors.append("%s: %s is missing and no fallback %s is configured" % [key, spec_field, catalog_field])


func _resolve_scene_fallback(
	spec: Resource,
	default_entries: Array,
	spec_script: Script,
	spec_field: String,
	catalog_field: String
) -> PackedScene:
	var scene: PackedScene = spec.get(spec_field) as PackedScene
	if scene != null:
		return scene
	var fallback_spec: Resource = _resolve_fallback_spec(default_entries, spec_script)
	if fallback_spec != null:
		scene = fallback_spec.get(spec_field) as PackedScene
		if scene != null:
			return scene
	return get(catalog_field) as PackedScene


func _validate_projectile_sfx_fallbacks(
	errors: Array[String],
	key: String,
	spec: Resource,
	default_entries: Array,
	spec_script: Script
) -> void:
	_validate_sfx_fallback(errors, key, spec, default_entries, spec_script, "fire_sfx", "default_fire_sfx")
	_validate_sfx_fallback(errors, key, spec, default_entries, spec_script, "hit_sfx_first", "default_hit_sfx_first")
	_validate_sfx_fallback(errors, key, spec, default_entries, spec_script, "hit_sfx_pierce", "default_hit_sfx_pierce")
	_validate_sfx_fallback(errors, key, spec, default_entries, spec_script, "hit_sfx_reroute", "default_hit_sfx_reroute")


func _validate_sfx_fallback(
	errors: Array[String],
	key: String,
	spec: Resource,
	default_entries: Array,
	spec_script: Script,
	spec_field: String,
	catalog_field: String
) -> void:
	if _resolve_audio_fallback(spec, default_entries, spec_script, spec_field, catalog_field) == null:
		errors.append("%s: %s is missing and no fallback %s is configured" % [key, spec_field, catalog_field])


func _resolve_audio_fallback(
	spec: Resource,
	default_entries: Array,
	spec_script: Script,
	spec_field: String,
	catalog_field: String
) -> AudioStream:
	var stream: AudioStream = spec.get(spec_field) as AudioStream
	if stream != null:
		return stream
	var fallback_spec: Resource = _resolve_fallback_spec(default_entries, spec_script)
	if fallback_spec != null:
		stream = fallback_spec.get(spec_field) as AudioStream
		if stream != null:
			return stream
	return get(catalog_field) as AudioStream


func _resolve_fallback_spec(default_entries: Array, spec_script: Script) -> Resource:
	for raw_entry in default_entries:
		if raw_entry == null or raw_entry.get_script() != _PlayShapeEntryScript:
			continue
		var spec: Resource = raw_entry.get("effect_spec") as Resource
		if spec != null and spec.get_script() == spec_script:
			return spec
	return null
