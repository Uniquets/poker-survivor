extends CharacterBody2D
class_name CombatPlayer
## 玩家实体：移动、生命、接触伤害冷却与简单圆形绘制

## 进程内当前玩家引用（`_enter_tree` 写入、`_exit_tree` 清空）；本局仅应存在一个 `CombatPlayer`；其它脚本经 `preload` 后调用 `get_combat_player()` 或读此字段
static var combat_player_singleton: CombatPlayer = null


## 返回当前已注册的全局玩家；未进树或已出场时为 null（跨脚本请 `preload("player.gd")` 再调本方法，避免 LSP 对 `class_name` 静态方法索引不全）
static func get_combat_player() -> CombatPlayer:
	return combat_player_singleton


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
## 无敌截止时间（毫秒时间戳，Time.get_ticks_msec）；在此之前 apply_damage 直接忽略
var _invulnerable_until_msec: int = -1
## 可移动矩形范围
var _map_bounds := Rect2(Vector2.ZERO, Vector2(CombatTuning.MAP_WIDTH, CombatTuning.MAP_HEIGHT))


## 进入场景树时注册为全局单例（供 `CombatEffectRunner` 等获取）
func _enter_tree() -> void:
	if combat_player_singleton != null and is_instance_valid(combat_player_singleton) and combat_player_singleton != self:
		push_warning("CombatPlayer: 重复注册全局单例，将覆盖为当前节点")
	combat_player_singleton = self


## 离开场景树时注销单例，避免悬空引用
func _exit_tree() -> void:
	if combat_player_singleton == self:
		combat_player_singleton = null


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
	if is_invulnerable():
		return

	var dmg: int = maxi(amount, 0)
	if dmg <= 0:
		return

	current_health = max(current_health - dmg, 0)
	GameToolSingleton.world_damage_float(global_position, dmg, Vector2(0, -28))
	emit_signal("health_changed", current_health, max_health)
	print("[combat] player_hit | damage=%d hp=%d/%d" % [dmg, current_health, max_health])

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


## 按最大生命百分比治疗（不超过上限）；死亡状态不治疗
func heal_percent_of_max_health(ratio: float) -> void:
	if _dead:
		return
	var r: float = clampf(ratio, 0.0, 1.0)
	var gain: int = int(round(float(max_health) * r))
	if gain <= 0:
		return
	current_health = mini(current_health + gain, max_health)
	GameToolSingleton.world_heal_float(global_position, gain, Vector2(0, -28))
	emit_signal("health_changed", current_health, max_health)
	print("[combat] player_heal | +%d hp=%d/%d ratio=%.2f" % [gain, current_health, max_health, r])
