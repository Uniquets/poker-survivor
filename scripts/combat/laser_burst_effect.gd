extends Node2D
## 多道平行短激光：沿玩家指向目标方向，多根平行线周期性结算伤害（默认 2 道，与 `PlayEffectCommand.count` 一致）

## 每跳伤害（每道激光每跳各结算一次）
var tick_damage: int = 20
## 总持续时间（秒）
var burst_duration_seconds: float = 0.4
## 玩家与敌人管理器（用于定位与枚举）
var _player: Node2D = null
var _enemy_manager: Node = null
## 相邻两道激光在垂直于前进方向上的「半间距」基准（像素）；多道时在总宽度上均匀铺开
var _parallel_offset: float = 14.0
## 平行激光道数，须 ≥2；来自命令 `count`，含全局弹道加成
var _beam_count: int = 2
## 已运行时间
var _elapsed: float = 0.0
## 距下次伤害跳变
var _until_tick: float = 0.0
const TICK_SEC: float = 0.1


## 注入玩家、敌人管理器、伤害、持续时间、相邻道半间距、激光道数（命令侧已含加成）
func setup(
	player: Node2D,
	enemy_manager: Node,
	dmg: int,
	duration_sec: float,
	dual_half_spacing_px: float,
	beam_count: int = 2
) -> void:
	_player = player
	_enemy_manager = enemy_manager
	tick_damage = maxi(0, dmg)
	burst_duration_seconds = maxf(0.08, duration_sec)
	_parallel_offset = maxf(4.0, dual_half_spacing_px)
	_beam_count = maxi(2, beam_count)


func _ready() -> void:
	_until_tick = 0.02


## 持续时间内每 TICK_SEC 对所有平行线附近敌人各结算一次伤害
func _process(delta: float) -> void:
	if _player == null or _enemy_manager == null:
		queue_free()
		return
	_elapsed += delta
	global_position = _player.global_position
	if _elapsed >= burst_duration_seconds:
		queue_free()
		return
	_until_tick -= delta
	if _until_tick > 0.0:
		return
	_until_tick = TICK_SEC
	_tick_laser_damage()
	queue_redraw()


## 对每条平行偏移的线段各打一跳：道数 >2 时在垂直方向均匀分布，外侧两道与旧版双道间距一致
func _tick_laser_damage() -> void:
	var target := _pick_nearest_enemy()
	var forward: Vector2 = Vector2.RIGHT
	if target != null:
		forward = (target.global_position - _player.global_position).normalized()
	if forward.length_squared() < 0.0001:
		forward = Vector2.RIGHT
	var perp: Vector2 = Vector2(-forward.y, forward.x).normalized()
	var n: int = _beam_count
	# n==2 时与历史一致：偏移 -half、+half（总距 2*_parallel_offset）
	var step: float = (2.0 * _parallel_offset) / float(max(1, n - 1))
	for i in range(n):
		var lateral: float = (-(n - 1) / 2.0 + float(i)) * step
		var offset: Vector2 = perp * lateral
		_damage_along_line(_player.global_position, forward, offset)
	queue_redraw()


## 在敌人管理器中找距离玩家最近的存活敌人
func _pick_nearest_enemy() -> CombatEnemy:
	var best: CombatEnemy = null
	var best_d2: float = INF
	for child in _enemy_manager.get_children():
		var e := child as CombatEnemy
		if e == null or e.is_dead():
			continue
		var d2 := _player.global_position.distance_squared_to(e.global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = e
	return best


## 自玩家位置沿 forward 方向射线，对带宽内敌人造成伤害（线段长度封顶）
func _damage_along_line(origin: Vector2, forward: Vector2, lateral_offset: Vector2) -> void:
	var line_start: Vector2 = origin + lateral_offset
	var max_len: float = 520.0
	var line_end: Vector2 = line_start + forward * max_len
	const half_width: float = 16.0
	for child in _enemy_manager.get_children():
		var enemy := child as CombatEnemy
		if enemy == null or enemy.is_dead():
			continue
		var p: Vector2 = enemy.global_position
		if _distance_point_to_segment(p, line_start, line_end) <= half_width:
			enemy.apply_damage(tick_damage)


## 点 p 到线段 ab 的最短距离
func _distance_point_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var t: float = 0.0
	if ab.length_squared() > 0.0000001:
		t = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	var proj: Vector2 = a + ab * t
	return p.distance_to(proj)


## 绘制所有激光线段（与伤害判定同几何）
func _draw() -> void:
	if _player == null or _enemy_manager == null:
		return
	var target := _pick_nearest_enemy()
	var forward: Vector2 = Vector2.RIGHT
	if target != null:
		forward = (target.global_position - _player.global_position).normalized()
	var perp: Vector2 = Vector2(-forward.y, forward.x).normalized()
	var n: int = _beam_count
	var step: float = (2.0 * _parallel_offset) / float(max(1, n - 1))
	var len_px: float = 420.0
	for i in range(n):
		var lateral: float = (-(n - 1) / 2.0 + float(i)) * step
		var o: Vector2 = perp * lateral
		var hue: float = float(i) / float(max(1, n - 1))
		var col: Color = Color(0.35 + 0.65 * hue, 0.85 - 0.3 * hue, 1.0 - 0.15 * hue, 0.75)
		draw_line(o, o + forward * len_px, col, 3.0)
