extends Resource
class_name EnemyConfig
## 敌人：敌人生成（刷怪节奏与区间）与敌人战斗（单敌体基底）；调试绘制挂在战斗下
## 由 `CombatTuning` 薄封装为 `ENEMY_*` 符号

# =============================================================================
@export_group("敌人生成 · 刷怪节奏与生成区间")
@export_subgroup("随玩家等级 · 间隔下限与系数")
## 生成间隔随等级公式中与 `base` 取 max 的下限（秒）；`base` 见 `EnemyManager` 场景
@export var spawn_interval_min_seconds: float = 0.38
## 间隔缩放系数：`base / (1 + 本系数 * max(0, level-1))`
@export var spawn_interval_level_k: float = 0.12

@export_subgroup("波次与场上 · 极坐标生成")
## 生成尝试间隔（秒）
@export var spawn_interval_seconds: float = 1.5
## 场上敌人数量上限
@export var max_alive: int = 12
## 生成位置距玩家的半径（像素）
@export var spawn_radius: float = 340.0

# =============================================================================
@export_group("敌人战斗 · 单敌体与追逐")
## 追击移动速度（像素/秒）
@export var move_speed: float = 120.0
## 单次接触对玩家伤害（点）
@export var touch_damage: int = 10
## 默认最大生命（点）
@export var max_health: int = 30
## 追击停止距离（像素）：**敌根 `global_position` 与玩家根 `global_position` 距离 `<` 本值** 时不再沿追击方向推进（**击退残留仍叠加**）；贴近伤害仍由 **`EnemyContactHitbox2D`** 处理
@export var chase_stop_distance_to_player: float = 64.0

@export_subgroup("调试与占位 · 绘制与碰撞体")
## 敌人占位 `_draw` 圆半径（像素）
@export var draw_radius: float = 10.0
## 敌人碰撞体相对默认的缩放系数
@export var collider_scale: float = 0.2
