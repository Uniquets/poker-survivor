extends RefCounted
class_name PlayEffectCommand
## 策划表访问（见 `enemy.gd` 说明）

## 单条可执行效果命令：由 cards 解析产出，由 CombatEffectRunner 分相执行

## 逻辑相：Buff、治疗、无敌等须在本步内完成的状态
const PHASE_LOGICAL: String = "logical"
## 表现相：弹道、爆炸、激光、地面持续等
const PHASE_PRESENTATIONAL: String = "presentational"
## 天外陨石命令常量：用于跨脚本在 LSP 索引滞后时稳定引用。
const CMD_METEOR_STORM: int = 1001

## 命令种类枚举
enum CmdKind {
	NONE,                   ## 无实际命令（默认/占位，不会产生任何效果）
	PROJECTILE_VOLLEY,      ## 多发弹道，通常为直线或轻微扇形展开，每发单独判定命中与伤害
	EXPLOSION_ONE_SHOT,     ## 圆形范围爆炸，瞬时对范围内目标造成伤害
	LASER_DUAL_BURST,       ## 多道平行短激光；`count` 为道数（默认 2），每道每跳独立结算
	BURNING_GROUND,         ## 地面留灼烧场，持续造成区域伤害与时长
	HEAL_PERCENT_MAX,       ## 治疗类型：按玩家最大生命值百分比回复
	INVULNERABLE_SECONDS,   ## 无敌状态：赋予玩家指定秒数的无敌
	EXPLOSIVE_VOLLEY, ## 兼容旧存档/旧分支的枚举名：语义为扇形投射物齐射（发射载荷弹，命中爆炸，可选灼地）
	WAYPOINT_VOLLEY,        ## 圆内随机航点弹道 + 穿透计数 + 并发上限补发（专用场景体，非并行 `Projectile`）
	METEOR_STORM,          ## 天外陨石：按落点生成多陨石，命中/爆炸/火焰由陨石场景脚本内部结算
}

## 命令类型（保留 int，兼容自定义扩展命令常量）
var kind: int = CmdKind.NONE
## 本命令所属相位（logical / presentational）
var phase: String = PHASE_PRESENTATIONAL

## 以下为各 kind 共用或分支负载字段（未使用者保持默认）
var damage: int = 0
## 多发弹道/扇形爆炸载荷：发射枚数；`LASER_DUAL_BURST`：平行激光道数（默认 2，受全局弹道加成）
var count: int = 1
## 多发弹道时扇形展开角（度），0 表示仍朝向主目标方向
var spread_deg: float = 0.0
## 爆炸/灼烧基础半径（像素）
var radius: float = 90.0
## 半径倍率（单次爆炸命令使用）；`EXPLOSIVE_VOLLEY` 时复用为灼地区域半径（像素）
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
## 并行多发横向线距（像素）
var volley_line_spacing: float = 14.0
## 多发弹道：每发在首次命中后还可再命中的**额外**敌人数（0=仅打一敌；由牌型表与默认条目决定）
var volley_pierce_extra_targets: int = 0
## 为真时：沿首发向直线穿透，共 `1+volley_pierce_extra_targets` 名敌；为假时（如回落弹道）可走链式弹射
var volley_linear_pierce: bool = false
## 为真时：由 Runner 在 **`COMBAT_PRESENTATION`** 的并行主/副槽间选预制体与专属音效链；**回落管线**等多发常保持 false
var volley_bind_presentation_slots: bool = false
## 为真且 **`volley_bind_presentation_slots`**：用并行**主槽**（子弹等）；为假则用**副槽**（卡牌等）
var volley_use_primary_scene: bool = false
## 写入弹道 **`CombatHitDelivery.knockback_speed`**（像素/秒）：**`-1`** 走 **`CombatHitDelivery`** 解析的击退档（并行管线见 **`use_parallel_volley_knockback_profile`**）；**`0`** 本管线不击退；**`>0`** 本击覆盖强度
var hit_knockback_speed: float = -1.0
## **`PROJECTILE_VOLLEY` / `WAYPOINT_VOLLEY`**：发射瞬间音效；由 **`PlayEffectResolver`** 解析写入；**`null`** 表示不播发射音
var sfx_fire: AudioStream = null
## 命中音（首击）
var sfx_hit_first: AudioStream = null
## 命中音（穿透段）
var sfx_hit_pierce: AudioStream = null
## 命中音（换向段）
var sfx_hit_reroute: AudioStream = null
## 非空时：**`CombatEffectRunner`** 多发弹道**直接**用本预制体，不再走表现表槽切换（牌型表等可填）
var projectile_scene_override: PackedScene = null
## 非空时：**`WaypointArenaVolleySpawner`** 实例化本航点弹预制体；空值视为配置缺失并跳过该发射
var waypoint_projectile_scene_override: PackedScene = null
## 航点弹全局并发上限（由航点 spec 注入，供 Spawner 控制在场数量）
var waypoint_max_concurrent_in_radius: int = 8
## 航点批量刷新间隔（秒，由航点 spec 注入）
var waypoint_batch_refresh_sec: float = 3.0
## `METEOR_STORM`：陨石场景（非空时 Runner 才执行）
var meteor_scene_override: PackedScene = null
## `METEOR_STORM`：本次陨石数量（已叠加部分后处理）
var meteor_count: int = 3
## `METEOR_STORM`：落点最小间距（像素）
var meteor_point_min_distance: float = 120.0
## `METEOR_STORM`：落点最大间距（像素）
var meteor_point_max_distance: float = 460.0
## `METEOR_STORM`：采样最大尝试次数
var meteor_sample_max_attempts: int = 72
## `METEOR_STORM`：是否强制相机可见区采样
var meteor_sample_in_camera_view: bool = true
## `METEOR_STORM`：是否优先从随机敌人位置取样落点
var meteor_sample_from_random_enemy: bool = false
## `METEOR_STORM`：是否启用落点最小/最大距离限制
var meteor_limit_point_distance: bool = true
## `METEOR_STORM`：基础下落阶段时长（秒）
var meteor_fall_duration_sec: float = 0.6
## `METEOR_STORM`：基础存在总时长（秒）
var meteor_lifetime_sec: float = 5.0
## `METEOR_STORM`：命中关键帧伤害
var meteor_impact_damage: int = 20
## `METEOR_STORM`：陨石整体缩放倍率（已含对子与范围加成）
var meteor_scale_mul: float = 1.0
## `METEOR_STORM`：是否启用对子二段爆炸
var meteor_enable_end_explosion: bool = false
## `METEOR_STORM`：对子二段爆炸伤害
var meteor_end_explosion_damage: int = 0
## `METEOR_STORM`：是否启用三条椭圆火焰覆盖区
var meteor_enable_ellipse_fire: bool = false
## `METEOR_STORM`：三条椭圆火焰 DoT DPS
var meteor_ellipse_fire_dps: int = 0
## `METEOR_STORM`：三条椭圆火焰跳伤间隔（秒）
var meteor_ellipse_fire_tick_sec: float = 0.45
## `METEOR_STORM`：是否启用四条包围区域火焰
var meteor_enable_polygon_fire: bool = false
## `METEOR_STORM`：四条包围区域火焰 DoT DPS
var meteor_polygon_fire_dps: int = 0
## `METEOR_STORM`：四条包围区域跳伤间隔（秒）
var meteor_polygon_fire_tick_sec: float = 0.45
## `METEOR_STORM`：投射物数量加成映射倍率
var meteor_projectile_count_bonus_scale: float = 0.5


## 工厂：多发直线/微扇弹道，伤害均分或每发 damage（此处每发相同 damage）；首发锁敌默认 **圆内最近**
## **`p_pierce_extra`**：每发额外穿透；**`p_bind_slots`**：是否走表现表并行槽；**`p_linear_pierce`**：直线穿透；**`p_use_primary_scene`**：主槽 vs 副槽；**`p_sfx_fire`** / **`p_projectile_scene_override`** 同字段名语义
static func create_projectile_volley(
	p_count: int,
	p_damage: int,
	p_spread_deg: float,
	p_pierce_extra: int = 0,
	p_lock_query_radius: float = 800.0,
	p_line_spacing: float = 14.0,
	p_bind_slots: bool = false,
	p_linear_pierce: bool = false,
	p_use_primary_scene: bool = false,
	p_sfx_fire: AudioStream = null,
	p_sfx_hit_first: AudioStream = null,
	p_sfx_hit_pierce: AudioStream = null,
	p_sfx_hit_reroute: AudioStream = null,
	p_projectile_scene_override: PackedScene = null
) -> PlayEffectCommand:
	var c := PlayEffectCommand.new()
	c.kind = CmdKind.PROJECTILE_VOLLEY
	c.phase = PHASE_PRESENTATIONAL
	c.count = maxi(1, p_count)
	c.damage = maxi(0, p_damage)
	c.spread_deg = p_spread_deg
	c.lock_target_kind = TargetConfirmDefault.TargetConfirmScheme.NEAREST_IN_RADIUS
	c.lock_query_radius = maxf(8.0, p_lock_query_radius)
	c.volley_line_spacing = maxf(0.0, p_line_spacing)
	c.volley_pierce_extra_targets = maxi(0, p_pierce_extra)
	c.volley_bind_presentation_slots = p_bind_slots
	c.volley_linear_pierce = p_linear_pierce
	c.volley_use_primary_scene = p_use_primary_scene
	c.sfx_fire = p_sfx_fire
	c.sfx_hit_first = p_sfx_hit_first
	c.sfx_hit_pierce = p_sfx_hit_pierce
	c.sfx_hit_reroute = p_sfx_hit_reroute
	c.projectile_scene_override = p_projectile_scene_override
	return c


## 工厂：航点圆内齐射 — 半径、总发数、穿透由牌型表注入；表现预制见本命令覆盖或表现表默认
static func create_waypoint_volley(
	p_count: int,
	p_damage: int,
	p_random_query_radius: float,
	p_pierce_extra_per_shot: int,
	p_sfx_fire: AudioStream = null,
	p_sfx_hit_first: AudioStream = null,
	p_sfx_hit_pierce: AudioStream = null,
	p_sfx_hit_reroute: AudioStream = null,
	p_waypoint_projectile_scene_override: PackedScene = null,
	p_waypoint_max_concurrent_in_radius: int = 8,
	p_waypoint_batch_refresh_sec: float = 3.0
) -> PlayEffectCommand:
	var c := PlayEffectCommand.new()
	c.kind = CmdKind.WAYPOINT_VOLLEY
	c.phase = PHASE_PRESENTATIONAL
	c.count = maxi(1, p_count)
	c.damage = maxi(0, p_damage)
	c.spread_deg = 0.0
	c.lock_target_kind = TargetConfirmDefault.TargetConfirmScheme.NEAREST_IN_RADIUS
	c.lock_query_radius = maxf(8.0, p_random_query_radius)
	c.volley_pierce_extra_targets = maxi(0, p_pierce_extra_per_shot)
	c.volley_bind_presentation_slots = true
	c.sfx_fire = p_sfx_fire
	c.sfx_hit_first = p_sfx_hit_first
	c.sfx_hit_pierce = p_sfx_hit_pierce
	c.sfx_hit_reroute = p_sfx_hit_reroute
	c.waypoint_projectile_scene_override = p_waypoint_projectile_scene_override
	c.waypoint_max_concurrent_in_radius = maxi(1, p_waypoint_max_concurrent_in_radius)
	c.waypoint_batch_refresh_sec = maxf(0.05, p_waypoint_batch_refresh_sec)
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


## 工厂：平行短激光；`p_beam_count` 默认 2，全局强化会再增大 `count`
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


## 工厂：扇形投射物齐射（命中爆炸，可选灼地）
static func create_explosive_volley(
	p_count: int,
	p_explosion_damage: int,
	p_explosion_radius: float,
	p_spread_deg: float,
	p_burn_zone_radius: float,
	p_burn_seconds: float,
	p_burn_dps: int
) -> PlayEffectCommand:
	var c := PlayEffectCommand.new()
	c.kind = CmdKind.EXPLOSIVE_VOLLEY
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


## 工厂：天外陨石（落点采样 + 多陨石发射）；命中/爆炸/火焰由陨石脚本执行
static func create_meteor_storm(
	p_meteor_scene_override: PackedScene,
	p_meteor_count: int,
	p_sample_in_camera_view: bool,
	p_point_min_distance: float,
	p_point_max_distance: float,
	p_sample_max_attempts: int,
	p_sample_from_random_enemy: bool,
	p_limit_point_distance: bool,
	p_fall_duration_sec: float,
	p_lifetime_sec: float,
	p_impact_damage: int,
	p_scale_mul: float,
	p_enable_end_explosion: bool,
	p_end_explosion_damage: int,
	p_enable_ellipse_fire: bool,
	p_ellipse_fire_dps: int,
	p_ellipse_fire_tick_sec: float,
	p_enable_polygon_fire: bool,
	p_polygon_fire_dps: int,
	p_polygon_fire_tick_sec: float,
	p_projectile_count_bonus_scale: float
) -> PlayEffectCommand:
	var c := PlayEffectCommand.new()
	c.kind = CMD_METEOR_STORM
	c.phase = PHASE_PRESENTATIONAL
	c.meteor_scene_override = p_meteor_scene_override
	c.meteor_count = maxi(1, p_meteor_count)
	c.meteor_sample_in_camera_view = p_sample_in_camera_view
	c.meteor_point_min_distance = maxf(0.0, p_point_min_distance)
	c.meteor_point_max_distance = maxf(c.meteor_point_min_distance, p_point_max_distance)
	c.meteor_sample_max_attempts = maxi(1, p_sample_max_attempts)
	c.meteor_sample_from_random_enemy = p_sample_from_random_enemy
	c.meteor_limit_point_distance = p_limit_point_distance
	c.meteor_fall_duration_sec = maxf(0.05, p_fall_duration_sec)
	c.meteor_lifetime_sec = maxf(c.meteor_fall_duration_sec, p_lifetime_sec)
	c.meteor_impact_damage = maxi(0, p_impact_damage)
	c.meteor_scale_mul = maxf(0.05, p_scale_mul)
	c.meteor_enable_end_explosion = p_enable_end_explosion
	c.meteor_end_explosion_damage = maxi(0, p_end_explosion_damage)
	c.meteor_enable_ellipse_fire = p_enable_ellipse_fire
	c.meteor_ellipse_fire_dps = maxi(0, p_ellipse_fire_dps)
	c.meteor_ellipse_fire_tick_sec = maxf(0.05, p_ellipse_fire_tick_sec)
	c.meteor_enable_polygon_fire = p_enable_polygon_fire
	c.meteor_polygon_fire_dps = maxi(0, p_polygon_fire_dps)
	c.meteor_polygon_fire_tick_sec = maxf(0.05, p_polygon_fire_tick_sec)
	c.meteor_projectile_count_bonus_scale = maxf(0.0, p_projectile_count_bonus_scale)
	return c
