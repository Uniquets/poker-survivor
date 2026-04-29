extends ShapeEffectSpec
class_name ShapeMeteorStormEffectSpec
## 天外陨石效果规格：牌型层只负责发射参数与增益映射，命中/爆炸/火焰结算由陨石场景脚本负责。


@export_group("基础发射")
## 单次效果基础陨石数量（未叠加全局弹道数量加成前）
@export var meteor_count: int = 3
## 投射物数量加成映射到陨石数量的效率倍率（最终增量向下取整）
@export var projectile_count_bonus_scale: float = 0.5
## 陨石场景预制体
@export var meteor_scene: PackedScene = null
## 陨石完整存在时长（秒）；无二段爆炸时到时渐隐结束
@export var meteor_lifetime_sec: float = 5.0
## 陨石下落阶段时长（秒）
@export var fall_duration_sec: float = 0.6
## 命中关键帧基础伤害
@export var impact_damage: int = 20

@export_group("落点采样")
## 是否在相机可见区域采样（当前需求固定为 true，保留开关便于调试）
@export var sample_in_camera_view: bool = true
## 是否优先从随机敌人位置取样落点；关闭时走随机点位采样
@export var sample_from_random_enemy: bool = false
## 是否启用落点间最小/最大距离限制；关闭时仅要求在视图内
@export var limit_point_distance: bool = true
## 落点最小间距（像素）
@export var point_min_distance: float = 120.0
## 落点最大间距（像素）
@export var point_max_distance: float = 460.0
## 随机采样最大尝试次数
@export var sample_max_attempts: int = 72

@export_group("对子增强（两张3）")
## 对子3的陨石缩放倍率（再叠加范围加成缩放）
@export var meteor_scale_mul_pair: float = 1.35
## 对子3是否在结束阶段触发二段爆炸
@export var enable_end_explosion_pair: bool = true
## 对子3二段爆炸伤害
@export var end_explosion_damage_pair: int = 22

@export_group("三条增强（三张3）")
## 三条3是否启用椭圆火焰覆盖区
@export var enable_ring_fire_triple: bool = true
## 三条3对陨石总持续时间的额外延长（秒）
@export var meteor_lifetime_bonus_triple_sec: float = 0.8
## 三条3椭圆火焰区域的持续伤害（DPS）
@export var ring_fire_dot_dps: int = 12
## 三条3椭圆火焰区域跳伤间隔（秒）
@export var ring_fire_tick_interval_sec: float = 0.45

@export_group("四条增强（四张3）")
## 四条3是否启用包围区域火焰
@export var enable_triangle_fire_four: bool = true
## 四条3对陨石总持续时间的额外延长（秒）
@export var meteor_lifetime_bonus_four_sec: float = 1.4
## 四条3包围区域火焰持续伤害（DPS）
@export var triangle_fire_dot_dps: int = 18
## 四条3包围区域跳伤间隔（秒）
@export var triangle_fire_tick_interval_sec: float = 0.45
