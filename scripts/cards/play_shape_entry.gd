extends Resource
class_name PlayShapeEntry
## 单条牌型表项：仅承载展示名与 **`effect_spec`**，匹配条件由 `PlayShapeCatalog.shape_dic` 的 key 决定。

## 人类可读牌型名（UI/日志）
@export var display_name: String = ""
## 本行命中后的效果规格；脚本须 **`extends ShapeEffectSpec`**（如 **`ShapeParallelVolleyEffectSpec`**、**`ShapeWaypointVolleyEffectSpec`**）
@export var effect_spec: Resource
