extends ShapeEffectSpec
class_name ShapeHealInvulnEffectSpec
## 牌型表：**治疗百分比** + 可选 **无敌秒数**；装配为 **`HEAL_PERCENT_MAX`** / **`INVULNERABLE_SECONDS`**（逻辑相）。


@export_group("逻辑相")
## 占最大生命 **0～1** 的治疗比例
@export var heal_ratio: float = 0.1
## **>0** 时追加 **`create_invulnerable`**；**0** 表示仅治疗
@export var invulnerable_seconds: float = 0.0
