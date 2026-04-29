extends Node2D
## 点数 8 管线专用投射物：与点数 2 所用 `Projectile.tscn` 分离；红色闪烁。传入非零 `flight_direction` 时沿该向**直线**飞行并扫敌近距引爆；为零向量时退回追击 `target` 的旧逻辑

const _ExplosionOneShotScene: PackedScene = preload("res://scenes/combat/ExplosionOneShot.tscn")
const _BurnZoneScript = preload("res://scripts/combat/burning_ground_zone.gd")

## 飞行速度（像素/秒）；通常由 **`CombatEffectRunner`** 从 **`GameConfig.COMBAT_MECHANICS.explosive_payload_speed`** 注入
var _speed: float = 680.0
## 超时（秒）后仍在当前位置引爆，避免永远悬挂
var _travel_timeout_seconds: float = 2.5

## 敌人容器（爆炸枚举伤害用）
var _enemy_manager: EnemyManager = null
## 用于挂爆炸/灼地节点的战斗父节点
var _fx_parent: Node = null
## 角度扇为零时的追击目标；直线模式下仍可用于占位
var _target: Node2D = null
## 非零则直线飞行（归一化）；由 `ProjectileToolSingleton.compute_angular_fan_layout` 写入
var _flight_dir: Vector2 = Vector2.ZERO
## 直线模式下判定与敌重叠的半径（像素）
var _hit_radius: float = 22.0
## 爆炸单次伤害与半径（像素）
var _explosion_damage: int = 0
var _explosion_radius: float = 90.0
## 为真时在本弹落点额外生成灼地（四条 8 仅最后一弹为真）
var _spawn_burn_after: bool = false
## 灼地参数；`_spawn_burn_after` 为假时不使用
var _burn_zone_radius: float = 0.0
var _burn_seconds: float = 0.0
var _burn_dps: int = 0

## 已引爆则不再重复结算
var _detonated: bool = false
## 已飞行时间（秒）
var _travel_time: float = 0.0


## 追击目标用世界点：**`CombatEnemy`** 用 **`Hurtbox`** 锚点，其余用节点原点
func _aim_point_for_target(t: Node2D) -> Vector2:
	if t == null or not is_instance_valid(t):
		return Vector2.ZERO
	if t is CombatEnemy:
		return (t as CombatEnemy).get_hurtbox_anchor_global()
	return t.global_position
## 闪烁相位（弧度累加）
var _flash_phase: float = 0.0


## 注入飞行与爆炸/灼地参数；`flight_direction` 非零为角度扇直线弹，零向量则朝 `target` 追踪
func setup(
	enemy_manager: EnemyManager,
	fx_parent: Node,
	target: Node2D,
	explosion_damage: int,
	explosion_radius: float,
	speed_px_per_sec: float,
	spawn_burn_after: bool,
	burn_zone_radius: float,
	burn_seconds: float,
	burn_dps: int,
	flight_direction: Vector2 = Vector2.ZERO
) -> void:
	_enemy_manager = enemy_manager
	_fx_parent = fx_parent
	_target = target
	_explosion_damage = maxi(0, explosion_damage)
	_explosion_radius = maxf(4.0, explosion_radius)
	_speed = maxf(60.0, speed_px_per_sec)
	_spawn_burn_after = spawn_burn_after
	_burn_zone_radius = maxf(0.0, burn_zone_radius)
	_burn_seconds = maxf(0.0, burn_seconds)
	_burn_dps = maxi(0, burn_dps)
	if flight_direction.length_squared() > 1e-6:
		_flight_dir = flight_direction.normalized()
		rotation = _flight_dir.angle()
	else:
		_flight_dir = Vector2.ZERO


func _ready() -> void:
	queue_redraw()


## 直线扇或追踪目标；近敌或超时则引爆
func _process(delta: float) -> void:
	if _detonated:
		return
	_flash_phase += delta * 18.0
	queue_redraw()

	if _flight_dir.length_squared() > 1e-6:
		_process_straight(delta)
		return

	if not is_instance_valid(_target):
		_detonate_at(global_position)
		return

	_travel_time += delta
	var aim: Vector2 = _aim_point_for_target(_target)
	var to_t: Vector2 = aim - global_position
	var dist: float = to_t.length()
	if dist < 26.0 or _travel_time > _travel_timeout_seconds:
		var hit_pos: Vector2 = aim if dist < 40.0 else global_position
		_detonate_at(hit_pos)
		return

	var direction: Vector2 = to_t.normalized() if dist > 0.001 else Vector2.RIGHT
	global_position += direction * _speed * delta


## 角度扇：沿 `_flight_dir` 匀速移动，与任一存活敌距离小于 `_hit_radius` 时于当前位置引爆
func _process_straight(delta: float) -> void:
	_travel_time += delta
	global_position += _flight_dir * _speed * delta
	if _enemy_manager != null and _try_hit_any_enemy():
		_detonate_at(global_position)
		return
	if _travel_time > _travel_timeout_seconds:
		_detonate_at(global_position)


## 是否与场上任一敌足够接近（用于直线弹体）
func _try_hit_any_enemy() -> bool:
	if _enemy_manager == null:
		return false
	var r2: float = _hit_radius * _hit_radius
	for child in _enemy_manager.get_units_root().get_children():
		var e := child as CombatEnemy
		if e == null or e.is_dead():
			continue
		if global_position.distance_squared_to(e.get_hurtbox_anchor_global()) <= r2:
			return true
	return false


## 在 pos 生成爆炸，按需生成灼地后移除自身
func _detonate_at(pos: Vector2) -> void:
	if _detonated:
		return
	_detonated = true
	set_process(false)

	if is_instance_valid(_fx_parent) and is_instance_valid(_enemy_manager):
		var ex := _ExplosionOneShotScene.instantiate()
		ex.global_position = pos
		ex.setup(_enemy_manager, _explosion_damage, _explosion_radius, _fx_parent)
		_fx_parent.call_deferred("add_child", ex)

		if _spawn_burn_after and _burn_zone_radius > 1.0 and _burn_seconds > 0.05:
			var zone := Node2D.new()
			zone.global_position = pos
			zone.set_script(_BurnZoneScript)
			zone.setup(_enemy_manager, _burn_zone_radius, _burn_seconds, _burn_dps)
			_fx_parent.call_deferred("add_child", zone)

	queue_free()


## 绘制红色闪烁弹体（不依赖 Projectile 预制体）
func _draw() -> void:
	var pulse: float = 0.55 + 0.45 * sin(_flash_phase)
	var core := Color(1.0, 0.12 + 0.08 * pulse, 0.1, 0.95)
	var ring_a: float = 0.35 + 0.35 * pulse
	draw_circle(Vector2.ZERO, 8.5, core)
	draw_arc(Vector2.ZERO, 12.0, 0.0, TAU, 28, Color(1.0, 0.35, 0.28, ring_a), 2.5, true)
