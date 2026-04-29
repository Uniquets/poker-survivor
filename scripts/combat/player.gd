extends CharacterBody2D
class_name CombatPlayer
## 玩家实体：移动、生命、接触伤害冷却

## 策划表访问（见 `enemy.gd` 说明）

## 预加载 `PlayerCombatStats`：避免仅依赖 `class_name` 时解析顺序导致 `CombatPlayer` 脚本加载失败
const _PlayerCombatStatsScript = preload("res://scripts/combat/player_combat_stats.gd")

## 进程内当前玩家引用（`_enter_tree` 写入、`_exit_tree` 清空）；本局仅应存在一个 `CombatPlayer`；其它脚本经 `preload` 后调用 `get_combat_player()` 或读此字段
static var combat_player_singleton: CombatPlayer = null


## 返回当前已注册的全局玩家；未进树或已出场时为 null（跨脚本请 `preload("player.gd")` 再调本方法，避免 LSP 对 `class_name` 静态方法索引不全）
static func get_combat_player() -> CombatPlayer:
	return combat_player_singleton


## 生命变化时发出当前/最大生命
signal health_changed(current_health: int, max_health: int)
## 生命归零时发出
signal died
## 经验或等级变化时发出：当前等级、本段已累积经验、升到下一级本段所需经验（与 `PlayerBasicsConfig` 段长公式一致）
signal experience_state_changed(level: int, xp_in_segment: int, xp_needed_this_segment: int)
## 单次 `add_experience` 内累计提升的等级数（用于连弹升级选卡）；未升级时不发
signal leveled_up(levels_gained: int)

## 最大生命（可被场景覆盖）
## 中文：默认值与 **`PlayerBasicsConfig.max_health`**（`player_basics_config.gd` / `.tres`）一致；**不得**在类体里读 **`GameConfig.PLAYER_BASICS`**（见本文件 **`_map_bounds`** 注）
@export var max_health: int = 100000
## 对敌结算伤害乘区（与 **`PlayerCombatStats.damage_multiplier`**、暴击在 **`EffectPlanPostProcess.apply_player_combat_stats`** 内**连乘**；**`<0`** 在解析阶段按 **`0`** 处理）
@export var attack_damage_coefficient: float = 1.0
## 连续受接触伤害的最短间隔（秒）
## 中文：默认与 **`PlayerBasicsConfig.contact_damage_cooldown_seconds`** 一致；类体不读 **`GameConfig`**
@export var contact_damage_cooldown_seconds: float = 0.6
## 战场拾取磁力半径基底（像素）；**`PickupCollector`** 用 **`get_effective_combat_pickup_magnet_radius()`**；乘 **`combat_stats.pickup_radius_multiplier`**
## 中文：默认与 **`PlayerBasicsConfig.combat_pickup_magnet_radius`** 一致；类体不读 **`GameConfig`**
@export var combat_pickup_magnet_radius: float = 300.0

## 局内动态战斗属性（伤害倍率、暴击、额外弹道枚数等）；与 `PlayerBasicsConfig` 初值分离；类型为 `_PlayerCombatStatsScript`
var combat_stats = null
## 生命回复小数累积（与 `health_regen_per_second` 配合）
var _hp_regen_accum: float = 0.0
## 当前护盾；上限受 `combat_stats.shield_capacity_bonus` 约束
var current_shield: int = 0

## 战斗等级（与节点 `level` 无关，避免混淆）
## 中文：默认与 **`PlayerBasicsConfig.starting_level`**（`player_basics_config.gd` 默认 **1**）一致；若将来在 **`.tres`** 覆写开局等级，请同步改场景/脚本初值或于 **`_ready`** 从表写入
var combat_level: int = 1
## 当前等级段内已累积的经验（升到下一段清零）
var _xp_in_segment: int = 0

## 当前生命
var current_health: int = 0
## 是否已死亡（锁移动与受击）
var _dead := false
## 上次记录受击的时间戳（秒）
var _last_hit_time_seconds := -1000.0
## 无敌截止时间（毫秒时间戳，Time.get_ticks_msec）；在此之前 apply_damage 直接忽略
var _invulnerable_until_msec: int = -1
## 可移动矩形范围；横向无限时仍用 **`end.y`** 夹紧纵向，**`position.x`/`end.x`** 仅在 **`_horizontal_clamp_enabled`** 为真时参与夹紧
## 中文：不在类体里读 **`GameConfig.GAME_GLOBAL`**（否则 `player.gd` 被 `combat_effect_runner` 等预载时，可能与 `GameConfig` 正在初始化 **`GAME_GLOBAL`** 形成循环引用）
var _map_bounds: Rect2 = Rect2()
## 为真时 **`global_position.x`** 受 **`_map_bounds`** 左右限制；地牢横向无限时为假
var _horizontal_clamp_enabled: bool = true

## 由 **`animated_sprite_node`** 在 **`_ready`** 解析；用于 locomotion、朝向与 **`get_attack_anchor_global`**
var _animated_sprite: AnimatedSprite2D = null

@export_group("表现", "anim_")
## 行走/待机动画所在 **`AnimatedSprite2D`**（相对玩家根）；默认 **`Animated`** 与 `player.tscn` 一致；**空**则跳过精灵动画与朝向逻辑
@export var animated_sprite_node: NodePath = NodePath("Animated")

## `SpriteFrames` 中行走循环的名称（`player.tscn` 当前为 **`move`**；若资源改为 `walk` 请在检查器改此导出）
@export var move_animation_name: StringName = &"move"
## 静止动画名，须与槽位节点上 **`SpriteFrames`** 资源一致
const _IDLE_ANIMATION: StringName = &"idle"
## 速度平方大于此值视为「在移动」，用于 idle / 行走切换，避免浮点抖动
@export var moving_speed_squared_threshold: float = 64.0
## 水平合成速度 **`velocity.x`**（输入 + 击退）绝对值低于此时不改 **`flip_h`**，避免静止/纯纵向微抖改朝向；停走后保持最后一次左右面向
@export var flip_velocity_x_epsilon: float = 1.0

## 受击闪红：调制向高峰色（略偏红，仍保持可读性）
const _HIT_FLASH_COLOR: Color = Color(1.0, 0.42, 0.42, 1.0)
## 受击闪红：从常态拉到高峰的时长（秒）
const _HIT_FLASH_IN_SEC: float = 0.05
## 受击闪红：从高峰回到白色的时长（秒）
const _HIT_FLASH_OUT_SEC: float = 0.14
## 当前受击闪红 tween；连续挨打会打断后重来，避免 `modulate` 叠偏
var _damage_flash_tween: Tween = null
## 受击击退残留速度（像素/秒）；与八向输入速度叠加后 **`move_and_slide`**
var _knockback_velocity: Vector2 = Vector2.ZERO
## 击退残留指数衰减系数（秒⁻¹）；由 **`apply_hit_knockback`** 根据投递解析刷新；**`_ready`** 对齐牌型默认
var _knockback_decay_rate: float = 7.0


## 是否已因生命归零死亡（供 **`PickupCollector`** / 拾取物等查询）
func is_dead() -> bool:
	return _dead


## 进入场景树时注册为全局单例（供 `CombatEffectRunner` 等获取）
func _enter_tree() -> void:
	if combat_player_singleton != null and is_instance_valid(combat_player_singleton) and combat_player_singleton != self:
		push_warning("CombatPlayer: 重复注册全局单例，将覆盖为当前节点")
	combat_player_singleton = self


## 离开场景树时注销单例，避免悬空引用
func _exit_tree() -> void:
	if combat_player_singleton == self:
		combat_player_singleton = null


## 初始化生命、碰撞层与首帧血条信号；确保 locomotion 动画从 idle 起播
func _ready() -> void:
	## 中文：在 **`GameConfig` 已就绪** 后同步地图夹紧矩形（见类字段 **`_map_bounds`** 说明）
	_map_bounds = Rect2(Vector2.ZERO, Vector2(GameConfig.GAME_GLOBAL.map_width, GameConfig.GAME_GLOBAL.map_height))
	if animated_sprite_node.is_empty():
		_animated_sprite = null
	else:
		_animated_sprite = get_node_or_null(animated_sprite_node) as AnimatedSprite2D
	## `PlayerCombatStats._init` 已调用 `seed_from_tuning_baseline()`，此处不再重复
	combat_stats = _PlayerCombatStatsScript.new()
	current_health = get_effective_max_health()
	current_shield = mini(current_shield, combat_stats.shield_capacity_bonus)
	collision_layer = GameConfig.GAME_GLOBAL.player_collision_layer
	collision_mask = GameConfig.GAME_GLOBAL.player_collision_mask
	_knockback_decay_rate = GameConfig.COMBAT_PRESENTATION.hit_knockback_decay_per_second
	emit_signal("health_changed", current_health, get_effective_max_health())
	_update_locomotion_animation(true)
	_emit_experience_state()


## 从当前 `combat_level` 升到下一级所需的本段经验总量（与 `PlayerBasicsConfig` 段长公式一致）
func get_xp_needed_this_segment() -> int:
	var b := GameConfig.PLAYER_BASICS
	return b.xp_to_level_2 + b.xp_segment_increase_per_level * maxi(0, combat_level - 1)


## 当前等级段内已累积经验（供 HUD 首帧读取）
func get_xp_in_segment() -> int:
	return _xp_in_segment


## 有效最大生命：场景 `max_health` + 动态 `max_health_bonus`
func get_effective_max_health() -> int:
	var bonus: int = 0
	if combat_stats != null:
		bonus = combat_stats.max_health_bonus
	return maxi(1, max_health + bonus)


## 有效战场拾取磁力半径（像素）；**`PickupCollector`** 与 **`BattlePickup`**（旧逻辑已迁入收集器）共用
func get_effective_combat_pickup_magnet_radius() -> float:
	var m: float = 1.0
	if combat_stats != null:
		m = maxf(0.1, combat_stats.pickup_radius_multiplier)
	return combat_pickup_magnet_radius * m


## 增加经验：可连续跨多级；每升一级由 `leveled_up` 汇总一次本次调用内的升级次数供 UI 连弹选卡
func add_experience(amount: int) -> void:
	if amount <= 0 or _dead:
		return
	var mult: float = 1.0
	if combat_stats != null:
		mult = maxf(0.0, combat_stats.experience_multiplier)
	var rest: int = int(round(float(amount) * mult))
	if rest <= 0:
		return
	var levels_gained: int = 0
	while rest > 0:
		var need: int = get_xp_needed_this_segment()
		var space: int = need - _xp_in_segment
		if rest < space:
			_xp_in_segment += rest
			rest = 0
		else:
			rest -= space
			_xp_in_segment = 0
			combat_level += 1
			levels_gained += 1
	_emit_experience_state()
	if levels_gained > 0:
		emit_signal("leveled_up", levels_gained)


## 向 HUD 等广播当前等级段进度
func _emit_experience_state() -> void:
	emit_signal("experience_state_changed", combat_level, _xp_in_segment, get_xp_needed_this_segment())


## 每物理帧：八向移动并夹紧在地图内
func _physics_process(_delta: float) -> void:
	if _dead:
		velocity = Vector2.ZERO
		_knockback_velocity = Vector2.ZERO
		move_and_slide()
		_update_locomotion_animation(false)
		return

	_decay_knockback_velocity(_delta)

	var input_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var sp_mul: float = 1.0
	if combat_stats != null:
		sp_mul = maxf(0.05, combat_stats.move_speed_multiplier)
	velocity = input_vector * GameConfig.PLAYER_BASICS.move_speed * sp_mul + _knockback_velocity
	move_and_slide()
	_apply_health_regen(_delta)
	var p: Vector2 = global_position
	if _horizontal_clamp_enabled:
		p.x = clampf(p.x, _map_bounds.position.x, _map_bounds.end.x - 0.001)
	p.y = clampf(p.y, _map_bounds.position.y, _map_bounds.end.y - 0.001)
	global_position = p
	_update_locomotion_animation(false)
	_update_sprite_facing_from_velocity()


## 每帧衰减击退残留（系数来自最近一次 **`CombatHitDelivery`** 解析，初值同 **`COMBAT_PRESENTATION.hit_knockback_decay_per_second`**）
func _decay_knockback_velocity(delta: float) -> void:
	var k: float = _knockback_decay_rate
	if k > 0.0:
		_knockback_velocity *= exp(-k * delta)
	if _knockback_velocity.length_squared() < 4.0:
		_knockback_velocity = Vector2.ZERO


## 按 `health_regen_per_second` 累计小数并转化为整数治疗（不超过有效上限）
func _apply_health_regen(delta: float) -> void:
	if _dead or combat_stats == null:
		return
	var r: float = combat_stats.health_regen_per_second
	if r <= 0.0:
		return
	_hp_regen_accum += r * delta
	if _hp_regen_accum < 1.0:
		return
	var heal_i: int = int(floor(_hp_regen_accum))
	_hp_regen_accum -= float(heal_i)
	var cap: int = get_effective_max_health()
	current_health = mini(current_health + heal_i, cap)
	emit_signal("health_changed", current_health, cap)


## 按**合成速度**水平分量更新 **`flip_h`**：贴图默认朝**右**时，向左运动（**`velocity.x < 0`**）翻面；**`|velocity.x|`** 过小时不改，停步后保持最后面向
func _update_sprite_facing_from_velocity() -> void:
	if _animated_sprite == null or not is_instance_valid(_animated_sprite):
		return
	if _dead:
		return
	if absf(velocity.x) < flip_velocity_x_epsilon:
		return
	_animated_sprite.flip_h = velocity.x < 0.0


## 按当前 `velocity` 与 `_dead` 切换 `AnimatedSprite2D` 的 idle / 行走动画；`force` 时忽略与当前 animation 相同则跳过（用于 `_ready` 首帧）
func _update_locomotion_animation(force: bool) -> void:
	if _animated_sprite == null or not is_instance_valid(_animated_sprite):
		return
	var frames: SpriteFrames = _animated_sprite.sprite_frames
	if frames == null:
		return

	var target: StringName
	if _dead or velocity.length_squared() <= moving_speed_squared_threshold:
		target = _IDLE_ANIMATION
	else:
		target = move_animation_name
		if not frames.has_animation(target) and frames.has_animation(&"walk"):
			target = &"walk"

	if not frames.has_animation(target):
		return
	if not force and _animated_sprite.animation == target:
		return
	_animated_sprite.play(target)


## 攻击、弹道、激光、爆炸索敌等表现使用的世界锚点（`AnimatedSprite2D` 全局中心）；移动/摄像机仍以 `global_position` 脚点为准
func get_attack_anchor_global() -> Vector2:
	if _animated_sprite != null and is_instance_valid(_animated_sprite):
		return _animated_sprite.global_position
	return global_position


## 玩家受击参考点：与子节点 **`CombatHurtbox2D`** 对齐；无则脚点
func get_hurtbox_anchor_global() -> Vector2:
	var hb: CombatHurtbox2D = find_child("CombatHurtbox2D", true, false) as CombatHurtbox2D
	if hb != null and is_instance_valid(hb):
		return hb.global_position
	return global_position


## 敌人贴近伤害入口：由 **`CombatHurtbox2D`**（`use_player_contact_gate` 投递）调用；受冷却限制返回是否生效
func receive_contact_damage(amount: int) -> bool:
	if _dead:
		return false

	var now_seconds := Time.get_ticks_msec() / 1000.0
	if now_seconds - _last_hit_time_seconds < contact_damage_cooldown_seconds:
		return false

	_last_hit_time_seconds = now_seconds
	apply_damage(amount)
	return true


## 扣血并可能在归零时触发死亡（先扣护盾，再乘 `incoming_damage_multiplier`）；**`hit_delivery`** 非空且实际扣血 **`>0`** 时叠加击退
func apply_damage(
	amount: int,
	hit_world: Vector2 = Vector2(NAN, NAN),
	hit_delivery: CombatHitDelivery = null
) -> void:
	if _dead:
		return
	if is_invulnerable():
		return

	var dmg: int = maxi(amount, 0)
	if dmg <= 0:
		return

	if combat_stats != null:
		dmg = int(round(float(dmg) * combat_stats.incoming_damage_multiplier))
		dmg = maxi(dmg, 0)

	if current_shield > 0:
		var use_s: int = mini(current_shield, dmg)
		current_shield -= use_s
		dmg -= use_s

	if dmg <= 0:
		return

	current_health = max(current_health - dmg, 0)
	_play_damage_hit_flash()
	var cap_hp: int = get_effective_max_health()
	emit_signal("health_changed", current_health, cap_hp)
	print("[combat] player_hit | damage=%d hp=%d/%d shield=%d" % [dmg, current_health, cap_hp, current_shield])

	if hit_delivery != null:
		apply_hit_knockback(hit_world, hit_delivery, dmg)

	if current_health == 0:
		_try_revive_or_finalize_death()


## 与 **`CombatEnemy.apply_hit_knockback`** 语义一致：由带 **`CombatHitDelivery`** 的受击路径调用
func apply_hit_knockback(hit_world: Vector2, delivery: CombatHitDelivery, damage_dealt: int) -> void:
	if _dead or damage_dealt <= 0 or delivery == null:
		return
	_knockback_decay_rate = delivery.get_effective_knockback_decay_per_second()
	var spd: float = delivery.get_effective_knockback_speed()
	if spd <= 0.0:
		return
	var ref: Vector2 = get_hurtbox_anchor_global()
	var dir: Vector2 = ref - hit_world
	if not hit_world.is_finite() or dir.length_squared() < 1e-8:
		if delivery.source is Node2D and is_instance_valid(delivery.source as Node2D):
			dir = ref - (delivery.source as Node2D).global_position
		if dir.length_squared() < 1e-8:
			dir = Vector2.RIGHT
	dir = dir.normalized()
	_knockback_velocity += dir * spd


## 受伤时在精灵上短时偏红再恢复（不再使用世界坐标伤害飘字）
func _play_damage_hit_flash() -> void:
	if _animated_sprite == null or not is_instance_valid(_animated_sprite):
		return
	if _damage_flash_tween != null:
		_damage_flash_tween.kill()
		_damage_flash_tween = null
	_animated_sprite.modulate = Color.WHITE
	_damage_flash_tween = create_tween()
	_damage_flash_tween.tween_property(_animated_sprite, "modulate", _HIT_FLASH_COLOR, _HIT_FLASH_IN_SEC)
	_damage_flash_tween.tween_property(_animated_sprite, "modulate", Color.WHITE, _HIT_FLASH_OUT_SEC)
	_damage_flash_tween.finished.connect(
		func () -> void:
			_damage_flash_tween = null
	)


## 生命归零：有复活次数则半血起身，否则真正死亡
func _try_revive_or_finalize_death() -> void:
	if combat_stats != null and combat_stats.revive_charges > 0:
		combat_stats.revive_charges -= 1
		var cap_hp: int = get_effective_max_health()
		current_health = maxi(1, int(round(float(cap_hp) * 0.5)))
		emit_signal("health_changed", current_health, cap_hp)
		print("[combat] player_revive | charges_left=%d hp=%d/%d" % [combat_stats.revive_charges, current_health, cap_hp])
		return
	_finalize_death()


## 标记死亡并发 `died`
func _finalize_death() -> void:
	_dead = true
	if _damage_flash_tween != null:
		_damage_flash_tween.kill()
		_damage_flash_tween = null
	if _animated_sprite != null and is_instance_valid(_animated_sprite):
		_animated_sprite.modulate = Color.WHITE
	_update_locomotion_animation(true)
	print("[combat] player_dead | reason=hp_zero")
	emit_signal("died")


## 由场景设置可走动地图矩形
func set_map_bounds(bounds: Rect2) -> void:
	_map_bounds = bounds


## 是否限制 **`x`** 在 **`_map_bounds`** 内；地牢横向无限时传 **`false`**，仅保留纵向与 **`StaticBody`** 碰撞
func set_horizontal_clamp_enabled(enabled: bool) -> void:
	_horizontal_clamp_enabled = enabled


## 当前是否处于无敌帧（供 UI 或调试）
func is_invulnerable() -> bool:
	return Time.get_ticks_msec() < _invulnerable_until_msec


## 叠加无敌时间：若已有更长无敌则取较大者
func add_invulnerable_seconds(seconds: float) -> void:
	if seconds <= 0.0:
		return
	var until: int = Time.get_ticks_msec() + int(round(seconds * 1000.0))
	_invulnerable_until_msec = maxi(_invulnerable_until_msec, until)
	print("[combat] player_invuln | until_msec=%d (+%.2fs)" % [_invulnerable_until_msec, seconds])


## 按最大生命百分比治疗（不超过有效上限）；死亡状态不治疗
func heal_percent_of_max_health(ratio: float) -> void:
	if _dead:
		return
	var r: float = clampf(ratio, 0.0, 1.0)
	var cap_hp: int = get_effective_max_health()
	var gain: int = int(round(float(cap_hp) * r))
	if gain <= 0:
		return
	current_health = mini(current_health + gain, cap_hp)
	GameToolSingleton.world_heal_float(global_position, gain, Vector2(0, -28))
	emit_signal("health_changed", current_health, cap_hp)
	print("[combat] player_heal | +%d hp=%d/%d ratio=%.2f" % [gain, current_health, cap_hp, r])
