extends RefCounted
class_name PlayEffectCommand
## 单条可执行效果命令：由 cards 解析产出，由 CombatEffectRunner 分相执行

## 逻辑相：Buff、治疗、无敌等须在本步内完成的状态
const PHASE_LOGICAL: String = "logical"
## 表现相：弹道、爆炸、激光、地面持续等
const PHASE_PRESENTATIONAL: String = "presentational"

## 命令种类枚举
enum CmdKind {
	NONE,                   ## 无实际命令（默认/占位，不会产生任何效果）
	PROJECTILE_VOLLEY,      ## 多发弹道，通常为直线或轻微扇形展开，每发单独判定命中与伤害
	EXPLOSION_ONE_SHOT,     ## 圆形范围爆炸，瞬时对范围内目标造成伤害
	LASER_DUAL_BURST,       ## 多道平行短激光；`count` 为道数（默认 2），每道每跳独立结算
	BURNING_GROUND,         ## 地面留灼烧场，持续造成区域伤害与时长
	HEAL_PERCENT_MAX,       ## 治疗类型：按玩家最大生命值百分比回复
	INVULNERABLE_SECONDS,   ## 无敌状态：赋予玩家指定秒数的无敌
	EIGHT_EXPLOSIVE_VOLLEY, ## 八向扇形弹道，同时发射多枚子弹，部分命中点可生成持续灼地
}

## 命令类型
var kind: CmdKind = CmdKind.NONE
## 本命令所属相位（logical / presentational）
var phase: String = PHASE_PRESENTATIONAL

## 以下为各 kind 共用或分支负载字段（未使用者保持默认）
var damage: int = 0
## 多发弹道/8 点扇形：发射枚数；`LASER_DUAL_BURST`：平行激光道数（默认 2，受全局弹道加成）
var count: int = 1
## 多发弹道时扇形展开角（度），0 表示仍朝向主目标方向
var spread_deg: float = 0.0
## 爆炸/灼烧基础半径（像素）
var radius: float = 90.0
## 半径倍率（一对 8 爆炸）；EIGHT_EXPLOSIVE_VOLLEY 时复用为灼地区域半径（像素）
var radius_mul: float = 1.0
## 伤害倍率（三个 8 / 四个 8 翻倍等）
var damage_mul: float = 1.0
## 治疗：占最大生命比例 0~1
var heal_ratio: float = 0.0
## 无敌持续时间（秒）
var invuln_seconds: float = 0.0
## 激光持续时间（秒）
var laser_duration: float = 0.4
## 灼烧地面持续时间（秒）
var burn_duration: float = 4.0
## 灼烧地面每秒伤害
var burn_dps: int = 6
## 弹道锁敌方案
var lock_target_kind: TargetConfirmDefault.TargetConfirmScheme = TargetConfirmDefault.TargetConfirmScheme.NEAREST_IN_RADIUS
## 索敌半径（像素）
var lock_query_radius: float = 800


## 工厂：多发直线/微扇弹道，伤害均分或每发 damage（此处每发相同 damage）；首发锁敌默认 **圆内最近**（与 `CombatTuning.BALLISTIC_LOCK_SCHEME_PROJECTILE_VOLLEY` 同值）
static func create_projectile_volley(p_count: int, p_damage: int, p_spread_deg: float) -> PlayEffectCommand:
	var c := PlayEffectCommand.new()
	c.kind = CmdKind.PROJECTILE_VOLLEY
	c.phase = PHASE_PRESENTATIONAL
	c.count = maxi(1, p_count)
	c.damage = maxi(0, p_damage)
	c.spread_deg = p_spread_deg
	c.lock_target_kind = TargetConfirmDefault.TargetConfirmScheme.NEAREST_IN_RADIUS
	c.lock_query_radius = CombatTuning.RANK_TWO_VOLLEY_LOCK_QUERY_RADIUS
	return c


## 工厂：单次圆形爆炸
static func create_explosion(p_damage: int, p_radius: float, p_radius_mul: float, p_damage_mul: float) -> PlayEffectCommand:
	var c := PlayEffectCommand.new()
	c.kind = CmdKind.EXPLOSION_ONE_SHOT
	c.phase = PHASE_PRESENTATIONAL
	c.damage = maxi(0, p_damage)
	c.radius = p_radius
	c.radius_mul = maxf(0.1, p_radius_mul)
	c.damage_mul = maxf(0.1, p_damage_mul)
	return c


## 工厂：四条 2 的平行短激光；`p_beam_count` 默认 2，全局强化会再增大 `count`
static func create_laser_dual_burst(
	p_tick_damage: int,
	p_duration: float,
	p_beam_count: int = 2
) -> PlayEffectCommand:
	var c := PlayEffectCommand.new()
	c.kind = CmdKind.LASER_DUAL_BURST
	c.phase = PHASE_PRESENTATIONAL
	c.damage = maxi(0, p_tick_damage)
	c.laser_duration = maxf(0.05, p_duration)
	c.count = maxi(2, p_beam_count)
	return c


## 工厂：点数 8 管线 — 多枚红色闪烁弹道，各自命中后在落点爆炸；四条时由最后一弹在命中点生成灼地
static func create_eight_explosive_volley(
	p_count: int,
	p_explosion_damage: int,
	p_explosion_radius: float,
	p_spread_deg: float,
	p_burn_zone_radius: float,
	p_burn_seconds: float,
	p_burn_dps: int
) -> PlayEffectCommand:
	var c := PlayEffectCommand.new()
	c.kind = CmdKind.EIGHT_EXPLOSIVE_VOLLEY
	c.phase = PHASE_PRESENTATIONAL
	c.count = maxi(1, p_count)
	c.damage = maxi(0, p_explosion_damage)
	c.radius = maxf(4.0, p_explosion_radius)
	c.spread_deg = maxf(0.0, p_spread_deg)
	c.radius_mul = maxf(0.0, p_burn_zone_radius)
	c.burn_duration = maxf(0.0, p_burn_seconds)
	c.burn_dps = maxi(0, p_burn_dps)
	c.lock_target_kind = TargetConfirmDefault.TargetConfirmScheme.NEAREST_IN_RADIUS
	return c


## 工厂：灼烧地面（四个 8 在爆炸后遗留）
static func create_burning_ground(p_radius: float, p_duration: float, p_dps: int) -> PlayEffectCommand:
	var c := PlayEffectCommand.new()
	c.kind = CmdKind.BURNING_GROUND
	c.phase = PHASE_PRESENTATIONAL
	c.radius = p_radius
	c.burn_duration = maxf(0.1, p_duration)
	c.burn_dps = maxi(0, p_dps)
	return c


## 工厂：按最大生命百分比治疗（逻辑相）
static func create_heal_percent(p_ratio: float) -> PlayEffectCommand:
	var c := PlayEffectCommand.new()
	c.kind = CmdKind.HEAL_PERCENT_MAX
	c.phase = PHASE_LOGICAL
	c.heal_ratio = clampf(p_ratio, 0.0, 1.0)
	return c


## 工厂：无敌若干秒（逻辑相）
static func create_invulnerable(p_seconds: float) -> PlayEffectCommand:
	var c := PlayEffectCommand.new()
	c.kind = CmdKind.INVULNERABLE_SECONDS
	c.phase = PHASE_LOGICAL
	c.invuln_seconds = maxf(0.0, p_seconds)
	return c
