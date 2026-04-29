extends Resource
class_name PlayerBasicsConfig
## 玩家侧策划数值：`CombatTuning` 以薄封装暴露原 `PLAYER_*` / `PLAYER_DEFAULT_*` 等符号
## 检查器：分组名为「类别 · 梗概」，便于一眼识别用途

# =============================================================================
@export_group("玩家 · 场景与接触 · 移动生命")
## 移动速度（像素/秒）
@export var move_speed: float = 240.0
## 默认最大生命（点）
@export var max_health: int = 100000
## 受敌人接触伤害的最短间隔（秒）
@export var contact_damage_cooldown_seconds: float = 0.6

# =============================================================================
@export_group("玩家 · 局内战斗默认 · PlayerCombatStats 初值")
## 与 `PlayerCombatStats` 一一对应；`seed_from_tuning_baseline()` 经 `CombatTuning` 读此处
## 全局伤害乘区（1.0 = 无额外加成）
@export var default_damage_multiplier: float = 1.0
## 技能范围：爆炸半径、索敌半径、spread 等
@export var default_skill_range_multiplier: float = 1.0
## 攻速倍率（用于下落/发射节奏；1.0 无加成）
@export var default_attack_speed_multiplier: float = 1.0
## 持续时间倍率（用于持续类技能全流程时长；1.0 无加成）
@export var default_effect_duration_multiplier: float = 1.0
## 解析阶段加法额外弹道/激光/八点扇形枚数（在 augment_snapshot 之前）
@export var default_projectile_count_bonus: int = 0
## 穿透额外可命中目标数（全局加法，与牌型穿透在管线中合并）
@export var default_pierce_bonus: int = 0
## 弹射次数加成（占位；未接线时保持 0）
@export var default_ricochet_bonus: int = 0
## 乘在 `move_speed` 上
@export var default_move_speed_multiplier: float = 1.0
## 暴击率 0～1
@export var default_crit_chance: float = 0.0
## 暴击时相对非暴击的倍率
@export var default_crit_damage_multiplier: float = 1.5
## 承受伤害乘区（1.0 无减免）
@export var default_incoming_damage_multiplier: float = 1.0
## 每秒生命回复（逻辑帧累计）
@export var default_health_regen_per_second: float = 0.0
## 在场景 max_health 基础上的额外上限（加法）
@export var default_max_health_bonus: int = 0
## 护盾容量加成
@export var default_shield_capacity_bonus: int = 0
## 复活次数等占位（未接线时保持 0）
@export var default_revive_charges: int = 0
## 经验结算乘区
@export var default_experience_multiplier: float = 1.0
## 幸运（掉落、抽卡等）
@export var default_luck: float = 0.0
## 升级选项重掷次数等占位
@export var default_upgrade_reroll_charges: int = 0
## 乘在同一资源中的 **`combat_pickup_magnet_radius`**（战场拾取磁力半径）
@export var default_pickup_radius_multiplier: float = 1.0

# =============================================================================
@export_group("成长 · 等级与经验曲线")
@export_subgroup("等级与经验曲线 · 段长公式")
## 开局等级
@export var starting_level: int = 1
## 1→2 本段所需经验；之后每升一级「下一段」长度 + `xp_segment_increase_per_level`
@export var xp_to_level_2: int = 10
## 段长增量：L2→3 为 12，L3→4 为 14…公式 `xp_to_level_2 + 本值 * (当前等级 - 1)`
@export var xp_segment_increase_per_level: int = 2

@export_group("战场拾取 · 磁力与收集（由 **`PickupCollector`** 驱动）")
@export_subgroup("距离与速度")
## 拾取物与玩家锚点距离 ≤ 此值（像素）时进入磁力牵引
@export var combat_pickup_magnet_radius: float = 300.0
## 拾取物中心距玩家锚点 ≤ 此值（像素）时结算拾取并销毁
@export var combat_pickup_collect_distance: float = 24.0
## 磁力牵引起始速度（像素/秒）
@export var combat_pickup_magnet_speed_min: float = 220.0
## 磁力牵引靠近玩家时的速度上限（像素/秒）
@export var combat_pickup_magnet_speed_max: float = 640.0
