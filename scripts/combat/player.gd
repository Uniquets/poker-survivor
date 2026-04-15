extends CharacterBody2D
class_name CombatPlayer
## 玩家实体：移动、生命、接触伤害冷却与简单圆形绘制

## 生命变化时发出当前/最大生命
signal health_changed(current_health: int, max_health: int)
## 生命归零时发出
signal died

## 最大生命（可被场景覆盖）
@export var max_health: int = CombatTuning.PLAYER_MAX_HEALTH
## 连续受接触伤害的最短间隔（秒）
@export var contact_damage_cooldown_seconds: float = CombatTuning.PLAYER_CONTACT_DAMAGE_COOLDOWN_SECONDS

## 当前生命
var current_health: int = 0
## 是否已死亡（锁移动与受击）
var _dead := false
## 上次记录受击的时间戳（秒）
var _last_hit_time_seconds := -1000.0
## 可移动矩形范围
var _map_bounds := Rect2(Vector2.ZERO, Vector2(CombatTuning.MAP_WIDTH, CombatTuning.MAP_HEIGHT))


## 初始化生命、碰撞层与首帧血条信号
func _ready() -> void:
	current_health = max_health
	collision_layer = CombatTuning.PLAYER_COLLISION_LAYER
	collision_mask = CombatTuning.PLAYER_COLLISION_MASK
	queue_redraw()
	emit_signal("health_changed", current_health, max_health)


## 每物理帧：八向移动并夹紧在地图内
func _physics_process(_delta: float) -> void:
	if _dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var input_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = input_vector * CombatTuning.PLAYER_MOVE_SPEED
	move_and_slide()
	global_position = global_position.clamp(_map_bounds.position, _map_bounds.end)


## 敌人接触伤害入口：受冷却限制返回是否生效
func receive_contact_damage(amount: int) -> bool:
	if _dead:
		return false

	var now_seconds := Time.get_ticks_msec() / 1000.0
	if now_seconds - _last_hit_time_seconds < contact_damage_cooldown_seconds:
		return false

	_last_hit_time_seconds = now_seconds
	apply_damage(amount)
	return true


## 扣血并可能在归零时触发死亡
func apply_damage(amount: int) -> void:
	if _dead:
		return

	current_health = max(current_health - max(amount, 0), 0)
	emit_signal("health_changed", current_health, max_health)
	print("[combat] player_hit | damage=%d hp=%d/%d" % [amount, current_health, max_health])

	if current_health == 0:
		_die()


## 标记死亡并发 died
func _die() -> void:
	_dead = true
	queue_redraw()
	print("[combat] player_dead | reason=hp_zero")
	emit_signal("died")


## 绘制玩家圆点（存活青/死亡灰）
func _draw() -> void:
	var color := Color(0.2, 0.8, 1.0) if not _dead else Color(0.4, 0.4, 0.4)
	draw_circle(Vector2.ZERO, CombatTuning.PLAYER_DRAW_RADIUS, color)


## 由场景设置可走动地图矩形
func set_map_bounds(bounds: Rect2) -> void:
	_map_bounds = bounds
