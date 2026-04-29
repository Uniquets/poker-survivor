extends RefCounted
class_name PlayShapeTableResolver
## 牌型表解析：先根据 `PlayContext` 构造 key，再从 `shape_dic[key]` 命中条目；未命中时回落 `DEFAULT`。


const _PlayPlanScript = preload("res://scripts/cards/play_plan.gd")
const _EffectPlanPostProcessScript: GDScript = preload("res://scripts/cards/effect_plan_post_process.gd")
const _PlayShapeMatcherScript: GDScript = preload("res://scripts/cards/play_shape_matcher.gd")
const _PlayShapeEffectAssemblerScript: GDScript = preload("res://scripts/cards/play_shape_effect_assembler.gd")
const _PlayShapeCatalogScript: GDScript = preload("res://scripts/cards/play_shape_catalog.gd")

## 当前使用的目录：**`GameConfig.PLAY_SHAPE_CATALOG`**；**`null`** 时用代码工厂（与默认 **`.tres`** 等价）
var _catalog = null


## 从 **`GameConfig.PLAY_SHAPE_CATALOG`** 刷新 **`_catalog`**；**`null`** 时回退 **`build_fallback_catalog_from_mechanics`**
func refresh_catalog_from_game_config() -> void:
	var c: PlayShapeCatalog = GameConfig.PLAY_SHAPE_CATALOG
	if c != null:
		_catalog = c
	else:
		_catalog = _PlayShapeCatalogScript.build_fallback_catalog_from_mechanics()


## **返回**：命中牌型条目或目录级默认条目时的新 **`PlayPlan`**；若目录未配置默认条目则返回 **`null`**（调用方可回落旧解析器）。
## 中文：解析一组牌型，根据 ctx 信息尝试在 shape_dic 表命中条目，未命中时回退默认；返回生成的 PlayPlan 或 null
func try_resolve(ctx) -> Variant:
	# 判空：ctx 为 null 或牌组为空时直接返回 null
	if ctx == null or ctx.cards.is_empty():
		return null
	## 首次解析或 GameConfig 热改时，_catalog 可能未赋值，这里惰性绑定（确保目录有值）
	if _catalog == null:
		refresh_catalog_from_game_config()

	# 取得当前 shape_dic 字典，后续用作主查找表
	var dic: Dictionary = _catalog.shape_dic
	# 预留 default_entries，主要用于 effect 组装时附带目录默认（目前只加一个 default_entry）
	var default_entries: Array = []
	var default_entry = dic.get(_PlayShapeMatcherScript.KEY_DEFAULT)
	if default_entry != null:
		default_entries.append(default_entry)

	# 根据 ctx 构造 shape_key，查表寻找匹配条目
	var shape_key: String = _PlayShapeMatcherScript.build_shape_key(ctx)
	var matched_entry = dic.get(shape_key)
	if matched_entry != null:
		# 命中特定条目，构造并返回 plan（Plan 记录 tag、拼装指令并执行后处理）
		var plan = _PlayPlanScript.new()
		plan.debug_tags.append_array(
			["shape_table_pipeline", "shape_match", shape_key, str(matched_entry.get("display_name"))]
		)
		# 组装条目的具体效果指令，传入上下文与默认
		_PlayShapeEffectAssemblerScript.append_shape_entry_effect_commands(
			plan, matched_entry, ctx, default_entries, _catalog
		)
		# 所有 effect post process 阶段
		_EffectPlanPostProcessScript.apply_all(plan, ctx)
		return plan

	# 未命中特定 key，若存在 default_entry，用 default 构造 fallback_plan
	if default_entry != null:
		var fallback_plan = _PlayPlanScript.new()
		fallback_plan.debug_tags.append_array(
			["shape_table_pipeline", "shape_default_fallback", str(default_entry.get("display_name"))]
		)
		_PlayShapeEffectAssemblerScript.append_shape_entry_effect_commands(
			fallback_plan, default_entry, ctx, default_entries, _catalog
		)
		_EffectPlanPostProcessScript.apply_all(fallback_plan, ctx)
		return fallback_plan

	# 两种都没命中，返回 null，调用方可回退旧逻辑
	return null
