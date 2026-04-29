extends RefCounted
## 从 **`PlayEffectResolver`** 抽离的 **`PlayPlan`** 后处理：玩家战斗属性、全局弹道强化、伤害预估；**牌型表管线与旧解析器共用**。（无 **`class_name`**，由调用方 **`preload` 本脚本** 调静态方法。）


const _CmdScript = preload("res://scripts/cards/play_effect_command.gd")
const _CMD_METEOR_STORM: int = 1001


## 依次应用：**玩家属性** → **全局 augment** → **伤害预估**
static func apply_all(plan, ctx) -> void:
	apply_player_combat_stats(plan, ctx)
	apply_global_augment_volley(plan, ctx)
	recalc_damage_hint(plan)


## 与旧 **`PlayEffectResolver._apply_player_combat_stats`** 一致
static func apply_player_combat_stats(plan, ctx) -> void:
	if plan == null or ctx == null:
		return
	var st = ctx.player_stats
	var dmg_scale: float = 1.0
	var range_scale: float = 1.0
	var extra_n: int = 0
	var attack_speed_scale: float = 1.0
	var duration_scale: float = 1.0
	if st != null:
		dmg_scale = maxf(0.0, st.damage_multiplier)
		range_scale = maxf(0.05, st.skill_range_multiplier)
		attack_speed_scale = maxf(0.05, st.attack_speed_multiplier)
		duration_scale = maxf(0.05, st.effect_duration_multiplier)
		extra_n = maxi(0, st.projectile_count_bonus)
	var attack_coef: float = maxf(0.0, ctx.player_attack_damage_coefficient)
	var dmg_combined: float = dmg_scale * attack_coef

	for cmd in plan.commands:
		if cmd == null or cmd.get_script() != _CmdScript:
			continue
		var c = cmd
		var crit_m: float = _roll_crit_multiplier(st)
		var dmg_mul: float = dmg_combined * crit_m
		match c.kind:
			_CmdScript.CmdKind.PROJECTILE_VOLLEY:
				c.damage = maxi(0, int(round(float(c.damage) * dmg_mul)))
				c.count = maxi(1, c.count + extra_n)
				c.lock_query_radius = maxf(1.0, c.lock_query_radius * range_scale)
				c.spread_deg = c.spread_deg * range_scale
			_CmdScript.CmdKind.WAYPOINT_VOLLEY:
				c.damage = maxi(0, int(round(float(c.damage) * dmg_mul)))
				c.count = maxi(1, c.count + extra_n)
				c.lock_query_radius = maxf(1.0, c.lock_query_radius * range_scale)
			_CmdScript.CmdKind.EXPLOSIVE_VOLLEY:
				c.damage = maxi(0, int(round(float(c.damage) * dmg_mul)))
				c.count = maxi(1, c.count + extra_n)
				c.radius = maxf(4.0, c.radius * range_scale)
				c.radius_mul = maxf(0.0, c.radius_mul * range_scale)
				c.spread_deg = c.spread_deg * range_scale
				c.burn_dps = maxi(0, int(round(float(c.burn_dps) * dmg_mul)))
				c.lock_query_radius = maxf(1.0, c.lock_query_radius * range_scale)
			_CmdScript.CmdKind.LASER_DUAL_BURST:
				c.damage = maxi(0, int(round(float(c.damage) * dmg_mul)))
				c.count = maxi(2, c.count + extra_n)
			_CmdScript.CmdKind.EXPLOSION_ONE_SHOT:
				c.damage = maxi(0, int(round(float(c.damage) * dmg_mul)))
				c.radius = maxf(1.0, c.radius * range_scale)
			_CmdScript.CmdKind.BURNING_GROUND:
				c.burn_dps = maxi(0, int(round(float(c.burn_dps) * dmg_mul)))
				c.radius = maxf(1.0, c.radius * range_scale)
			_CMD_METEOR_STORM:
				# 中文：数量加成按配置效率映射并向下取整；保底至少 1 颗。
				var bonus_count: int = int(floor(float(extra_n) * maxf(0.0, c.meteor_projectile_count_bonus_scale)))
				c.meteor_count = maxi(1, c.meteor_count + bonus_count)
				c.meteor_impact_damage = maxi(0, int(round(float(c.meteor_impact_damage) * dmg_mul)))
				c.meteor_end_explosion_damage = maxi(0, int(round(float(c.meteor_end_explosion_damage) * dmg_mul)))
				c.meteor_ellipse_fire_dps = maxi(0, int(round(float(c.meteor_ellipse_fire_dps) * dmg_mul)))
				c.meteor_polygon_fire_dps = maxi(0, int(round(float(c.meteor_polygon_fire_dps) * dmg_mul)))
				# 中文：范围加成分两段生效：采样间距 + 陨石整体缩放。
				c.meteor_point_min_distance = maxf(0.0, c.meteor_point_min_distance * range_scale)
				c.meteor_point_max_distance = maxf(c.meteor_point_min_distance, c.meteor_point_max_distance * range_scale)
				c.meteor_scale_mul = maxf(0.05, c.meteor_scale_mul * range_scale)
				# 中文：攻速只影响下落阶段；持续时间倍率影响全流程时长。
				c.meteor_fall_duration_sec = maxf(0.05, c.meteor_fall_duration_sec / attack_speed_scale)
				c.meteor_lifetime_sec = maxf(
					c.meteor_fall_duration_sec,
					c.meteor_lifetime_sec * duration_scale
				)
			_:
				pass


## 暴击倍率掷骰（与旧逻辑一致）
static func _roll_crit_multiplier(st) -> float:
	if st == null:
		return 1.0
	if st.crit_chance <= 0.0:
		return 1.0
	if randf() < st.crit_chance:
		return maxf(1.0, st.crit_damage_multiplier)
	return 1.0


## 与旧 **`PlayEffectResolver._apply_global_augment_volley`** 一致
static func apply_global_augment_volley(plan, ctx) -> void:
	if plan == null:
		return
	var bonus: int = 0
	if ctx != null and ctx.augment_snapshot != null:
		bonus = int(ctx.augment_snapshot.volley_count_bonus)
	if bonus <= 0:
		return
	for cmd in plan.commands:
		if cmd == null or cmd.get_script() != _CmdScript:
			continue
		var c = cmd
		if c.kind == _CmdScript.CmdKind.PROJECTILE_VOLLEY:
			c.count = maxi(1, c.count + bonus)
		elif c.kind == _CmdScript.CmdKind.WAYPOINT_VOLLEY:
			c.count = maxi(1, c.count + bonus)
		elif c.kind == _CmdScript.CmdKind.EXPLOSIVE_VOLLEY:
			c.count = maxi(1, c.count + bonus)
		elif c.kind == _CmdScript.CmdKind.LASER_DUAL_BURST:
			c.count = maxi(1, c.count + bonus)


## 与旧 **`PlayEffectResolver._recalc_damage_hint`** 一致
static func recalc_damage_hint(plan) -> void:
	var total: int = 0
	var mech_hint: CombatMechanicsTuning = GameConfig.COMBAT_MECHANICS as CombatMechanicsTuning
	for cmd in plan.commands:
		if cmd == null or cmd.get_script() != _CmdScript:
			continue
		var c = cmd
		match c.kind:
			_CmdScript.CmdKind.PROJECTILE_VOLLEY:
				var pierce: int = maxi(0, c.volley_pierce_extra_targets)
				total += c.damage * maxi(1, c.count) * (1 + pierce)
			_CmdScript.CmdKind.WAYPOINT_VOLLEY:
				var pierce4: int = maxi(0, c.volley_pierce_extra_targets)
				total += c.damage * maxi(1, c.count) * (1 + pierce4)
			_CmdScript.CmdKind.EXPLOSION_ONE_SHOT:
				total += int(float(c.damage) * c.damage_mul)
			_CmdScript.CmdKind.EXPLOSIVE_VOLLEY:
				total += c.damage * maxi(1, c.count)
				if (
					c.burn_duration > mech_hint.explosive_damage_hint_burn_duration_threshold_sec
					and c.radius_mul > mech_hint.explosive_damage_hint_radius_mul_for_burn
				):
					total += int(c.burn_dps * c.burn_duration)
			_CmdScript.CmdKind.LASER_DUAL_BURST:
				var tick_sec: float = mech_hint.laser_legacy_damage_hint_tick_interval_sec
				var ticks: int = maxi(
					1,
					int(floor(c.laser_duration / tick_sec + mech_hint.laser_legacy_damage_hint_tick_floor_epsilon))
				)
				var beams: int = maxi(mech_hint.augment_min_laser_dual_burst_beams, c.count)
				total += c.damage * ticks * beams
			_CmdScript.CmdKind.BURNING_GROUND:
				total += int(c.burn_dps * c.burn_duration)
			_CMD_METEOR_STORM:
				var meteor_hits: int = maxi(1, c.meteor_count)
				total += c.meteor_impact_damage * meteor_hits
				if c.meteor_enable_end_explosion:
					total += c.meteor_end_explosion_damage * meteor_hits
				if c.meteor_enable_ellipse_fire:
					total += int(float(c.meteor_ellipse_fire_dps) * c.meteor_lifetime_sec)
				if c.meteor_enable_polygon_fire:
					total += int(float(c.meteor_polygon_fire_dps) * c.meteor_lifetime_sec)
			_:
				pass
	plan.estimated_enemy_damage = total
