extends CharacterBody2D
class_name CombatEnemy
## 追击玩家的敌人：移动、接触伤害、生命与自毁

## 移动速度（像素/秒）
@export var move_speed: float = CombatTuning.ENEMY_MOVE_SPEED
## 与玩家重叠时造成的伤害
@export var touch_damage: int = CombatTuning.ENEMY_TOUCH_DAMAGE
## 最大生命
@export var max_health: int = CombatTuning.ENEMY_MAX_HEALTH

## 追击目标（通常为玩家）
var target: Node2D
## 当前生命
var current_health: int = 0
## 是否已死亡
var _dead := false
## 用于检测与玩家接触的 Area2D
@onready var touch_area: Area2D = $TouchArea


## 初始化生命与碰撞层
func _ready() -> void:
	current_health = max_health
	collision_layer = CombatTuning.ENEMY_COLLISION_LAYER
	collision_mask = CombatTuning.ENEMY_COLLISION_MASK
	queue_redraw()


## 朝目标移动并对重叠玩家施加接触伤害
func _physics_process(_delta: float) -> void:
	if _dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if not is_instance_valid(target):
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var to_target := target.global_position - global_position
	var direction := to_target.normalized() if to_target.length() > 0.001 else Vector2.ZERO
	velocity = direction * move_speed
	move_and_slide()

	for collider in touch_area.get_overlapping_bodies():
		if collider != null and collider.has_method("receive_contact_damage"):
			collider.receive_contact_damage(touch_damage)


## 受到伤害，归零时 _die
func apply_damage(amount: int) -> void:
	if _dead:
		return

	var clamped_damage: int = maxi(amount, 0)
	if clamped_damage > 0:
		GameToolSingleton.world_damage_float(global_position, clamped_damage, Vector2(0, -22))
	current_health = max(current_health - clamped_damage, 0)
	if current_health > 0:
		return
	_die()


## 查询是否已死亡
func is_dead() -> bool:
	return _dead


## 死亡后 queue_free
func _die() -> void:
	_dead = true
	print("[combat] enemy_killed | node=%s" % name)
	queue_free()


## 绘制敌人圆点
func _draw() -> void:
	draw_circle(Vector2.ZERO, CombatTuning.ENEMY_DRAW_RADIUS, Color(1.0, 0.25, 0.25))
