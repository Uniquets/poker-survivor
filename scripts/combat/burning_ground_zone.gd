extends Node2D
## 灼烧地面：周期性对重叠敌人造成伤害，持续若干秒后移除

## 每秒伤害
var burn_dps: int = 6
## 区域半径（像素）
var zone_radius: float = 100.0
## 总存活时间（秒）
var zone_duration_seconds: float = 4.0
## 伤害间隔（秒）
var _tick_interval_seconds: float = 0.45
## 敌人管理器
var _enemy_manager: Node = null
## 灼烧 tick 复用的命中投递
var _hit_delivery: CombatHitDelivery = CombatHitDelivery.new()
## 累计存活时间
var _elapsed: float = 0.0
## 距下次结算剩余时间
var _until_tick: float = 0.0


## 外部注入参数与敌人容器
func setup(enemy_manager: Node, radius_px: float, duration_sec: float, dps: int) -> void:
	_enemy_manager = enemy_manager
	zone_radius = maxf(8.0, radius_px)
	zone_duration_seconds = maxf(0.2, duration_sec)
	burn_dps = maxi(0, dps)
	_hit_delivery.source = self


func _ready() -> void:
	_until_tick = 0.05


## 每帧累加时间并周期性结算灼烧
func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= zone_duration_seconds:
		queue_free()
		return
	_until_tick -= delta
	if _until_tick > 0.0:
		return
	_until_tick = _tick_interval_seconds
	_tick_damage()
	queue_redraw()


## 对圆内敌人造成一次 tick 伤害（按间隔拆分的 DPS）；飘字取圆心→敌心方向上的**区内落点**（敌在区内时即敌心）
func _tick_damage() -> void:
	if _enemy_manager == null:
		return
	var per_tick: int = maxi(1, int(round(float(burn_dps) * _tick_interval_seconds)))
	var units: Node = _enemy_manager
	if _enemy_manager is EnemyManager:
		units = (_enemy_manager as EnemyManager).get_units_root()
	for child in units.get_children():
		var enemy := child as CombatEnemy
		if enemy == null or enemy.is_dead():
			continue
		var anchor_e: Vector2 = enemy.get_hurtbox_anchor_global()
		var to_e: Vector2 = anchor_e - global_position
		if to_e.length() <= zone_radius:
			var burn_hit: Vector2 = (
				global_position + to_e.normalized() * minf(zone_radius, to_e.length())
				if to_e.length_squared() > 1e-8
				else anchor_e
			)
			_hit_delivery.damage = per_tick
			CombatHurtbox2D.deliver_to_enemy_best_effort(enemy, _hit_delivery, burn_hit)


func _draw() -> void:
	var alpha := clampf(1.0 - _elapsed / maxf(zone_duration_seconds, 0.01), 0.0, 1.0) * 0.28
	draw_arc(Vector2.ZERO, zone_radius, 0.0, TAU, 48, Color(1.0, 0.2, 0.05, alpha), 2.0, true)
