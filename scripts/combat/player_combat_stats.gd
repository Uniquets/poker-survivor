extends RefCounted
## 策划表访问（见 `enemy.gd` 说明）

## 玩家局内 **动态** 战斗属性：可被拾取、升级、Buff 修改。
## **说明**：不使用 `class_name`，由 `CombatPlayer` 经 `preload` 引用，避免与全局类表冲突及循环解析。
## 与 `GameConfig.PLAYER_BASICS` 的关系：**默认值** 一律来自该资源中 `default_*` 字段；本类存 **运行时实际值**（可被拾取等修改）。

## 下列字段的 **唯一策划来源** 为 `PlayerBasicsConfig` 中 `default_*`；字面初值仅占位，**构造时由 `_init` → `seed_from_tuning_baseline()` 覆盖**
var damage_multiplier: float = 0.0
var skill_range_multiplier: float = 0.0
## 攻速倍率：用于技能执行节奏（如陨石下落时长）
var attack_speed_multiplier: float = 0.0
## 持续时间倍率：用于持续类技能总时长
var effect_duration_multiplier: float = 0.0
var projectile_count_bonus: int = 0
var pierce_bonus: int = 0
var ricochet_bonus: int = 0
var move_speed_multiplier: float = 0.0
var crit_chance: float = 0.0
var crit_damage_multiplier: float = 0.0
var incoming_damage_multiplier: float = 0.0
var health_regen_per_second: float = 0.0
var max_health_bonus: int = 0
var shield_capacity_bonus: int = 0
var revive_charges: int = 0
var experience_multiplier: float = 0.0
var luck: float = 0.0
var upgrade_reroll_charges: int = 0
var pickup_radius_multiplier: float = 0.0


## 构造时即对齐 `GameConfig.PLAYER_BASICS` 中 `default_*`（与 `CombatPlayer._ready` 再调 `seed` 不冲突，可重复刷表）
func _init() -> void:
	seed_from_tuning_baseline()


## 用 **`PlayerBasicsConfig.default_*`** **整表重置** 为开局/难度表基底（与字段初值同源，便于回合中途强制对齐策划配置）
func seed_from_tuning_baseline() -> void:
	var b := GameConfig.PLAYER_BASICS
	damage_multiplier = b.default_damage_multiplier
	skill_range_multiplier = b.default_skill_range_multiplier
	attack_speed_multiplier = b.default_attack_speed_multiplier
	effect_duration_multiplier = b.default_effect_duration_multiplier
	projectile_count_bonus = b.default_projectile_count_bonus
	pierce_bonus = b.default_pierce_bonus
	ricochet_bonus = b.default_ricochet_bonus
	move_speed_multiplier = b.default_move_speed_multiplier
	crit_chance = b.default_crit_chance
	crit_damage_multiplier = b.default_crit_damage_multiplier
	incoming_damage_multiplier = b.default_incoming_damage_multiplier
	health_regen_per_second = b.default_health_regen_per_second
	max_health_bonus = b.default_max_health_bonus
	shield_capacity_bonus = b.default_shield_capacity_bonus
	revive_charges = b.default_revive_charges
	experience_multiplier = b.default_experience_multiplier
	luck = b.default_luck
	upgrade_reroll_charges = b.default_upgrade_reroll_charges
	pickup_radius_multiplier = b.default_pickup_radius_multiplier


## 解析前快照，避免单步内引用被异步修改
func duplicate_snapshot():
	var c = get_script().new()
	c.damage_multiplier = damage_multiplier
	c.skill_range_multiplier = skill_range_multiplier
	c.attack_speed_multiplier = attack_speed_multiplier
	c.effect_duration_multiplier = effect_duration_multiplier
	c.projectile_count_bonus = projectile_count_bonus
	c.pierce_bonus = pierce_bonus
	c.ricochet_bonus = ricochet_bonus
	c.move_speed_multiplier = move_speed_multiplier
	c.crit_chance = crit_chance
	c.crit_damage_multiplier = crit_damage_multiplier
	c.incoming_damage_multiplier = incoming_damage_multiplier
	c.health_regen_per_second = health_regen_per_second
	c.max_health_bonus = max_health_bonus
	c.shield_capacity_bonus = shield_capacity_bonus
	c.revive_charges = revive_charges
	c.experience_multiplier = experience_multiplier
	c.luck = luck
	c.upgrade_reroll_charges = upgrade_reroll_charges
	c.pickup_radius_multiplier = pickup_radius_multiplier
	return c
