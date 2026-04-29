extends RefCounted
class_name PlayShapeEffectAssembler
## 将 **`PlayShapeEntry.effect_spec`**（**`ShapeEffectSpec`** 子类 **`Resource`**）转为 **`PlayEffectCommand`**。


const _CmdScript = preload("res://scripts/cards/play_effect_command.gd")
const _CMD_METEOR_STORM: int = 1001
const _PlayShapeEntryScript: GDScript = preload("res://scripts/cards/play_shape_entry.gd")
const _ParallelSpecScript: GDScript = preload("res://scripts/cards/shape_parallel_volley_effect_spec.gd")
const _WaypointSpecScript: GDScript = preload("res://scripts/cards/shape_waypoint_volley_effect_spec.gd")
const _ExplosiveVolleySpecScript: GDScript = preload("res://scripts/cards/shape_explosive_volley_effect_spec.gd")
const _HealInvulnSpecScript: GDScript = preload("res://scripts/cards/shape_heal_invuln_effect_spec.gd")
const _MeteorStormSpecScript: GDScript = preload("res://scripts/cards/shape_meteor_storm_effect_spec.gd")


## 解析多发弹道发射音（参数仅保留兼容；当前统一读取 `PlayShapeCatalog` 外层默认）
static func resolve_projectile_volley_fire_sfx(
	binding_volley_presentation: bool, _use_primary_parallel_fire_slot: bool
) -> AudioStream:
	if not binding_volley_presentation:
		return null
	var cat: PlayShapeCatalog = GameConfig.PLAY_SHAPE_CATALOG as PlayShapeCatalog
	if cat == null:
		return null
	return cat.default_fire_sfx


## 本步牌 **`CardResource.damage`** 求和（与旧 **`PlayEffectResolver._sum_card_damage`** 语义一致）
static func _sum_cards_damage(cards: Array) -> int:
	var t: int = 0
	for c in cards:
		if c is CardResource:
			t += (c as CardResource).damage
	return t


## 从默认条目提取同类型 **`effect_spec`**，用于命中条目的字段回落（如预制体/发射音）
static func _resolve_fallback_spec(default_entries: Array, spec_script: Script) -> Resource:
	for de in default_entries:
		if de == null or de.get_script() != _PlayShapeEntryScript:
			continue
		var dspec: Resource = de.get("effect_spec") as Resource
		if dspec == null:
			continue
		if dspec.get_script() == spec_script:
			return dspec
	return null


## 按 **`ctx.cards`** 张数与 **`COMBAT_MECHANICS`** 追加一条 **`EXPLOSIVE_VOLLEY`**（扇形发射 + 命中爆炸 + 可选灼地）
static func _append_explosive_volley_from_ctx(plan, ctx) -> void:
	var n: int = ctx.cards.size()
	var mech8: CombatMechanicsTuning = GameConfig.COMBAT_MECHANICS as CombatMechanicsTuning
	var base_d: int = _sum_cards_damage(ctx.cards)
	base_d = maxi(base_d, mech8.explosive_explosion_min_damage)
	var base_r: float = mech8.explosive_explosion_base_radius
	var rmul: float = 1.0
	var dmul: float = 1.0
	match n:
		1:
			pass
		2:
			rmul = mech8.explosive_pair_radius_mul
		3:
			dmul = mech8.explosive_triple_damage_mul
		4:
			dmul = mech8.explosive_triple_damage_mul
		_:
			pass
	var exp_dmg: int = int(round(float(base_d) * dmul))
	var exp_r: float = base_r * rmul
	var spread: float = (
		mech8.explosive_payload_spread_base_deg
		* (1.0 + mech8.explosive_payload_spread_extra_per_card * float(n - 1))
	)
	var burn_r: float = 0.0
	var burn_sec: float = 0.0
	var burn_dps: int = 0
	if n == 4:
		burn_r = base_r * rmul * mech8.explosive_burn_radius_scale
		burn_sec = mech8.explosive_burn_ground_seconds
		burn_dps = mech8.explosive_burn_ground_dps
	plan.commands.append(
		_CmdScript.create_explosive_volley(n, exp_dmg, exp_r, spread, burn_r, burn_sec, burn_dps)
	)


## 处理并行多发弹道规格：解析回落字段并追加 **`PROJECTILE_VOLLEY`**
static func _handle_parallel_spec(
	plan, spec: Resource, _entry: Object, _ctx, default_entries: Array, default_catalog: Object
) -> void:
	var fb_parallel: Resource = _resolve_fallback_spec(default_entries, _ParallelSpecScript)
	var proj_scene: PackedScene = spec.get("projectile_scene") as PackedScene
	if proj_scene == null and fb_parallel != null:
		proj_scene = fb_parallel.get("projectile_scene") as PackedScene
	if proj_scene == null and default_catalog != null:
		proj_scene = default_catalog.get("default_projectile_scene") as PackedScene
	var binding: bool = bool(spec.get("binding_card_shape_presentation"))
	var use_default_fire: bool = bool(spec.get("binding_use_default_shape_fire_slot"))
	var fire_stream: AudioStream = spec.get("fire_sfx") as AudioStream
	if fire_stream == null and fb_parallel != null:
		fire_stream = fb_parallel.get("fire_sfx") as AudioStream
	if fire_stream == null and default_catalog != null:
		fire_stream = default_catalog.get("default_fire_sfx") as AudioStream
	## 中文：已显式指定预制体时关闭 **`volley_bind_presentation_slots`**，避免 Runner 再用表现槽覆盖 **`projectile_scene_override`**
	var cmd_use_shape_slots: bool = binding and proj_scene == null
	if fire_stream == null:
		fire_stream = resolve_projectile_volley_fire_sfx(cmd_use_shape_slots, use_default_fire)
	var hit_first: AudioStream = spec.get("hit_sfx_first") as AudioStream
	if hit_first == null and fb_parallel != null:
		hit_first = fb_parallel.get("hit_sfx_first") as AudioStream
	if hit_first == null and default_catalog != null:
		hit_first = default_catalog.get("default_hit_sfx_first") as AudioStream
	var hit_pierce: AudioStream = spec.get("hit_sfx_pierce") as AudioStream
	if hit_pierce == null and fb_parallel != null:
		hit_pierce = fb_parallel.get("hit_sfx_pierce") as AudioStream
	if hit_pierce == null and default_catalog != null:
		hit_pierce = default_catalog.get("default_hit_sfx_pierce") as AudioStream
	var hit_reroute: AudioStream = spec.get("hit_sfx_reroute") as AudioStream
	if hit_reroute == null and fb_parallel != null:
		hit_reroute = fb_parallel.get("hit_sfx_reroute") as AudioStream
	if hit_reroute == null and default_catalog != null:
		hit_reroute = default_catalog.get("default_hit_sfx_reroute") as AudioStream
	var lock_r: float = float(spec.get("lock_query_radius"))
	if lock_r <= 0.0 and fb_parallel != null:
		lock_r = float(fb_parallel.get("lock_query_radius"))
	var line_spacing: float = float(spec.get("line_spacing"))
	if line_spacing <= 0.0 and fb_parallel != null:
		line_spacing = float(fb_parallel.get("line_spacing"))
	plan.commands.append(
		_CmdScript.create_projectile_volley(
			int(spec.get("volley_count")),
			int(spec.get("damage_per_hit")),
			float(spec.get("spread_deg")),
			int(spec.get("extra_hit_budget_per_shot")),
			lock_r,
			line_spacing,
			cmd_use_shape_slots,
			bool(spec.get("straight_volley")),
			use_default_fire,
			fire_stream,
			hit_first,
			hit_pierce,
			hit_reroute,
			proj_scene
		)
	)


## 处理航点齐射规格：解析回落字段并追加 **`WAYPOINT_VOLLEY`**
static func _handle_waypoint_spec(
	plan, spec: Resource, _entry: Object, _ctx, default_entries: Array, default_catalog: Object
) -> void:
	var fb_waypoint: Resource = _resolve_fallback_spec(default_entries, _WaypointSpecScript)
	var wp_scene: PackedScene = spec.get("waypoint_projectile_scene") as PackedScene
	if wp_scene == null and fb_waypoint != null:
		wp_scene = fb_waypoint.get("waypoint_projectile_scene") as PackedScene
	if wp_scene == null and default_catalog != null:
		wp_scene = default_catalog.get("default_projectile_scene") as PackedScene
	var wp_fire: AudioStream = spec.get("fire_sfx") as AudioStream
	if wp_fire == null and fb_waypoint != null:
		wp_fire = fb_waypoint.get("fire_sfx") as AudioStream
	if wp_fire == null and default_catalog != null:
		wp_fire = default_catalog.get("default_fire_sfx") as AudioStream
	if wp_fire == null:
		wp_fire = resolve_projectile_volley_fire_sfx(true, false)
	var wp_hit_first: AudioStream = spec.get("hit_sfx_first") as AudioStream
	if wp_hit_first == null and fb_waypoint != null:
		wp_hit_first = fb_waypoint.get("hit_sfx_first") as AudioStream
	if wp_hit_first == null and default_catalog != null:
		wp_hit_first = default_catalog.get("default_hit_sfx_first") as AudioStream
	var wp_hit_pierce: AudioStream = spec.get("hit_sfx_pierce") as AudioStream
	if wp_hit_pierce == null and fb_waypoint != null:
		wp_hit_pierce = fb_waypoint.get("hit_sfx_pierce") as AudioStream
	if wp_hit_pierce == null and default_catalog != null:
		wp_hit_pierce = default_catalog.get("default_hit_sfx_pierce") as AudioStream
	var wp_hit_reroute: AudioStream = spec.get("hit_sfx_reroute") as AudioStream
	if wp_hit_reroute == null and fb_waypoint != null:
		wp_hit_reroute = fb_waypoint.get("hit_sfx_reroute") as AudioStream
	if wp_hit_reroute == null and default_catalog != null:
		wp_hit_reroute = default_catalog.get("default_hit_sfx_reroute") as AudioStream
	var wp_max_concurrent: int = int(spec.get("max_concurrent_in_radius"))
	if wp_max_concurrent <= 0 and fb_waypoint != null:
		wp_max_concurrent = int(fb_waypoint.get("max_concurrent_in_radius"))
	if wp_max_concurrent <= 0:
		wp_max_concurrent = 8
	var wp_batch_refresh_sec: float = float(spec.get("batch_refresh_sec"))
	if wp_batch_refresh_sec <= 0.0 and fb_waypoint != null:
		wp_batch_refresh_sec = float(fb_waypoint.get("batch_refresh_sec"))
	if wp_batch_refresh_sec <= 0.0:
		wp_batch_refresh_sec = 3.0
	plan.commands.append(
		_CmdScript.create_waypoint_volley(
			int(spec.get("volley_count")),
			int(spec.get("damage_per_hit")),
			float(spec.get("random_query_radius")),
			int(spec.get("pierce_extra_per_shot")),
			wp_fire,
			wp_hit_first,
			wp_hit_pierce,
			wp_hit_reroute,
			wp_scene,
			wp_max_concurrent,
			wp_batch_refresh_sec
		)
	)


## 处理扇形爆炸规格：依赖 **`ctx.cards`** 生成 **`EXPLOSIVE_VOLLEY`**
static func _handle_explosive_volley_spec(
	plan, _spec: Resource, entry: Object, ctx, _default_entries: Array, _default_catalog: Object
) -> void:
	if ctx == null:
		push_warning("PlayShapeEffectAssembler: EXPLOSIVE_VOLLEY 规格需要 ctx | entry=%s" % str(entry.get("display_name")))
		return
	_append_explosive_volley_from_ctx(plan, ctx)


## 处理治疗/无敌规格：按表项字段追加逻辑相命令
static func _handle_heal_invuln_spec(
	plan, spec: Resource, _entry: Object, _ctx, _default_entries: Array, _default_catalog: Object
) -> void:
	var hr: float = clampf(float(spec.get("heal_ratio")), 0.0, 1.0)
	plan.commands.append(_CmdScript.create_heal_percent(hr))
	var inv: float = float(spec.get("invulnerable_seconds"))
	if inv > 0.0:
		plan.commands.append(_CmdScript.create_invulnerable(inv))


## 处理天外陨石规格：按牌张数分档合成（single/pair/triple/four）
static func _handle_meteor_storm_spec(
	plan, spec: Resource, entry: Object, ctx, _default_entries: Array, _default_catalog: Object
) -> void:
	# 中文：陨石规格依赖本步牌数量做分档覆盖，ctx 缺失时无法确定分支。
	if ctx == null:
		push_warning("PlayShapeEffectAssembler: METEOR_STORM 规格需要 ctx | entry=%s" % str(entry.get("display_name")))
		return
	var n: int = maxi(1, ctx.cards.size())
	var scale_mul: float = 1.0
	var enable_end_explosion: bool = false
	var end_explosion_damage: int = 0
	var enable_ellipse_fire: bool = false
	var ellipse_fire_dps: int = 0
	var ellipse_fire_tick: float = 0.45
	var enable_polygon_fire: bool = false
	var polygon_fire_dps: int = 0
	var polygon_fire_tick: float = 0.45
	var lifetime_bonus_sec: float = 0.0
	# 中文：分档互斥，四条触发时覆盖三条，不做双重叠加。
	if n >= 4:
		enable_polygon_fire = bool(spec.get("enable_triangle_fire_four"))
		polygon_fire_dps = int(spec.get("triangle_fire_dot_dps"))
		polygon_fire_tick = float(spec.get("triangle_fire_tick_interval_sec"))
		lifetime_bonus_sec = float(spec.get("meteor_lifetime_bonus_four_sec"))
	elif n == 3:
		enable_ellipse_fire = bool(spec.get("enable_ring_fire_triple"))
		ellipse_fire_dps = int(spec.get("ring_fire_dot_dps"))
		ellipse_fire_tick = float(spec.get("ring_fire_tick_interval_sec"))
		lifetime_bonus_sec = float(spec.get("meteor_lifetime_bonus_triple_sec"))
	elif n == 2:
		scale_mul = float(spec.get("meteor_scale_mul_pair"))
		enable_end_explosion = bool(spec.get("enable_end_explosion_pair"))
		end_explosion_damage = int(spec.get("end_explosion_damage_pair"))
	var c = _CmdScript.new()
	c.kind = _CMD_METEOR_STORM
	c.phase = _CmdScript.PHASE_PRESENTATIONAL
	c.meteor_scene_override = spec.get("meteor_scene") as PackedScene
	c.meteor_count = maxi(1, int(spec.get("meteor_count")))
	c.meteor_sample_in_camera_view = bool(spec.get("sample_in_camera_view"))
	c.meteor_sample_from_random_enemy = bool(spec.get("sample_from_random_enemy"))
	c.meteor_limit_point_distance = bool(spec.get("limit_point_distance"))
	c.meteor_point_min_distance = maxf(0.0, float(spec.get("point_min_distance")))
	c.meteor_point_max_distance = maxf(c.meteor_point_min_distance, float(spec.get("point_max_distance")))
	c.meteor_sample_max_attempts = maxi(1, int(spec.get("sample_max_attempts")))
	c.meteor_fall_duration_sec = maxf(0.05, float(spec.get("fall_duration_sec")))
	c.meteor_lifetime_sec = maxf(
		c.meteor_fall_duration_sec,
		float(spec.get("meteor_lifetime_sec")) + lifetime_bonus_sec
	)
	c.meteor_impact_damage = maxi(0, int(spec.get("impact_damage")))
	c.meteor_scale_mul = maxf(0.05, scale_mul)
	c.meteor_enable_end_explosion = enable_end_explosion
	c.meteor_end_explosion_damage = maxi(0, end_explosion_damage)
	c.meteor_enable_ellipse_fire = enable_ellipse_fire
	c.meteor_ellipse_fire_dps = maxi(0, ellipse_fire_dps)
	c.meteor_ellipse_fire_tick_sec = maxf(0.05, ellipse_fire_tick)
	c.meteor_enable_polygon_fire = enable_polygon_fire
	c.meteor_polygon_fire_dps = maxi(0, polygon_fire_dps)
	c.meteor_polygon_fire_tick_sec = maxf(0.05, polygon_fire_tick)
	c.meteor_projectile_count_bonus_scale = maxf(0.0, float(spec.get("projectile_count_bonus_scale")))
	plan.commands.append(c)


## 按表项 **`effect_spec`** 追加命令；**`ctx`** 供扇形爆炸等读取本步牌张数与伤害和；**`default_entries`** 用于未配置字段回落
## 按表项 effect_spec 追加效果命令（支持并行动作、弹道攻击、爆炸、治疗、无敌等多种类型）
## 参数说明：
## - plan：最终待执行的效果命令队列
## - entry：当前组牌的表项，需为 _PlayShapeEntryScript 类型
## - ctx：上下文数据（如组牌张数、伤害），某些类型（例如爆炸）需要
## - default_entries：备用表项列表，用于未配置字段时的回落（可选）
## - default_catalog：全局资源目录，部分效果需要查表（可选）
static func append_shape_entry_effect_commands(
	plan,
	entry: Object,
	ctx,
	default_entries: Array = [],
	default_catalog: Object = null
) -> void:
	# 校验 entry 类型，必须是 _PlayShapeEntryScript 实例
	if entry == null or entry.get_script() != _PlayShapeEntryScript:
		push_warning("PlayShapeEffectAssembler: entry 类型无效")
		return
	# 读取 effect_spec（效果规格资源）
	var spec: Resource = entry.get("effect_spec") as Resource
	if spec == null:
		push_warning("PlayShapeEffectAssembler: effect_spec 为空 | entry=%s" % str(entry.get("display_name")))
		return
	var sp: Script = spec.get_script()
	# 针对不同效果类型分派到对应处理方法
	if sp == _ParallelSpecScript:
		# 并行弹道
		_handle_parallel_spec(plan, spec, entry, ctx, default_entries, default_catalog)
		return
	if sp == _WaypointSpecScript:
		# 航点弹道
		_handle_waypoint_spec(plan, spec, entry, ctx, default_entries, default_catalog)
		return
	if sp == _ExplosiveVolleySpecScript:
		# 扇形爆炸（多段弹幕）
		_handle_explosive_volley_spec(plan, spec, entry, ctx, default_entries, default_catalog)
		return
	if sp == _HealInvulnSpecScript:
		# 治疗/无敌
		_handle_heal_invuln_spec(plan, spec, entry, ctx, default_entries, default_catalog)
		return
	if sp == _MeteorStormSpecScript:
		# 天外陨石
		_handle_meteor_storm_spec(plan, spec, entry, ctx, default_entries, default_catalog)
		return
	# 未支持的效果类型，输出警告并跳过
	var type_hint: String = sp.resource_path.get_file() if sp != null else str(spec)
	push_warning(
		"PlayShapeEffectAssembler: 未支持的 effect_spec 类型 | entry=%s | spec=%s"
		% [str(entry.get("display_name")), type_hint]
	)
