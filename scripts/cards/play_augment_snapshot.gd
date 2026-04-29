extends RefCounted
class_name PlayAugmentSnapshot
## 单次出牌解析前由 `GlobalAugmentState` 汇总生成的强化快照，写入 `PlayContext`；解析器只读应用，不修改局内状态

## 作用于 `PROJECTILE_VOLLEY` / `WAYPOINT_VOLLEY` / `EXPLOSIVE_VOLLEY` 的枚数，以及 `LASER_DUAL_BURST` 的激光道数（与基础值线性相加）
var volley_count_bonus: int = 0
