extends Resource
class_name CombatMechanicsTuning
## 战斗数值与「并行/航点/爆炸/治疗」等**非预制体表现**策划表；预制体与全局默认音画见 **`CombatPresentationDefaults`**（**`GameConfig.COMBAT_PRESENTATION`**）。

@export_subgroup("航点手感调试")
@export var waypoint_arrive_distance: float = 28.0 # 航点到达判定距离
@export var waypoint_arrival_slowing_radius: float = 200.0 # 接近目标减速区域半径
@export var waypoint_brake_speed_threshold: float = 35.0 # 减速阈值
@export var waypoint_max_speed: float = 620.0 # 航点最大速度
@export var waypoint_accel: float = 1100.0 # 航点加速度
@export var waypoint_decel: float = 900.0 # 航点减速度
@export var waypoint_reorient_cruise_speed: float = 90.0 # 巡航转向速度
@export var waypoint_heading_turn_rate: float = 4.5 # 航点转向速率

@export_group("爆炸载荷 · 扇形与灼地")
@export var explosive_angular_fan_arc_base_deg: float = 32.0 # 基础扇形角度
@export var explosive_angular_fan_arc_per_spread_deg: float = 1.15 # 每额外散布角增加的扇形角度
@export var explosive_payload_speed: float = 680.0 # 爆炸投递速度
@export var explosive_payload_spread_base_deg: float = 14.0 # 爆炸散布基础角度
@export var explosive_payload_spread_extra_per_card: float = 0.15 # 每张牌额外增加的散布角度
@export var explosive_explosion_base_radius: float = 92.0 # 爆炸基础半径
@export var explosive_explosion_min_damage: int = 16 # 爆炸最小伤害
@export var explosive_single_card_config_note: String = "" # 单张爆炸配置说明
@export var explosive_pair_radius_mul: float = 1.45 # 对子爆炸半径倍率
@export var explosive_triple_damage_mul: float = 2.0 # 三条爆炸伤害倍率
@export var explosive_burn_radius_scale: float = 1.05 # 灼地半径比例
@export var explosive_burn_ground_seconds: float = 4.0 # 灼地持续时间（秒）
@export var explosive_burn_ground_dps: int = 6 # 灼地每秒伤害
@export var explosive_damage_hint_burn_duration_threshold_sec: float = 0.05 # 灼地伤害提示显示阈值（秒）
@export var explosive_damage_hint_radius_mul_for_burn: float = 1.0 # 灼地伤害提示半径倍率

@export_group("治疗与无敌")
@export var heal_invuln_common_config_note: String = "" # 治疗与无敌配置说明
@export var heal_invuln_percent_single: float = 0.10 # 单张治疗百分比
@export var heal_invuln_percent_pair: float = 0.30 # 对子治疗百分比
@export var heal_invuln_percent_triple: float = 0.50 # 三条治疗百分比
@export var heal_invuln_invulnerable_seconds_triple: float = 2.0 # 三条无敌时间（秒）
@export var heal_invuln_percent_four: float = 1.0 # 四条治疗百分比
@export var heal_invuln_invulnerable_seconds_four: float = 5.0 # 四条无敌时间（秒）
