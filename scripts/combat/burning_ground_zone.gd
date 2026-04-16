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


## 对圆内敌人造成一次 tick 伤害（按间隔拆分的 DPS）
func _tick_damage() -> void:
	if _enemy_manager == null:
		return
	var per_tick: int = maxi(1, int(round(float(burn_dps) * _tick_interval_seconds)))
	for child in _enemy_manager.get_children():
		var enemy := child as CombatEnemy
		if enemy == null or enemy.is_dead():
			continue
		if global_position.distance_to(enemy.global_position) <= zone_radius:
			enemy.apply_damage(per_tick)


func _draw() -> void:
	var alpha := clampf(1.0 - _elapsed / maxf(zone_duration_seconds, 0.01), 0.0, 1.0) * 0.28
	draw_arc(Vector2.ZERO, zone_radius, 0.0, TAU, 48, Color(1.0, 0.2, 0.05, alpha), 2.0, true)
