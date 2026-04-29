extends Resource
class_name PlayShapeCatalog
## 牌型目录：使用 **`shape_dic`** 按 key 直读 `PlayShapeEntry`，不再依赖条目内 rank/count/group_type 字段。
## **策划主路径**：在编辑器中新建或编辑 **`.tres`**（脚本选本类），`shape_dic` 的 key 为牌型字符串（如 `2`、`22`、`ABC`、`AABBCC`）；默认文件 **`config/card_shape_config.tres`**，由 **`GameConfig.PLAY_SHAPE_CATALOG`** 预载引用（不嵌在 **`GameGlobalConfig`**）。
## **`build_fallback_catalog_from_mechanics`**：深拷贝 **`config/card_shape_config.tres`**，仅作 **`PLAY_SHAPE_CATALOG` 为 `null`** 时运行时回落；**不**在代码里写死某一点数分支，与策划表一致。


## 中文：与 **`GameConfig`** 解耦的默认表资源（避免循环引用）
const _DefaultCatalogPacked: Resource = preload("res://config/card_shape_config.tres")

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
