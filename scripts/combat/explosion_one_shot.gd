extends Node2D
## 单次圆形爆炸：对半径内敌人各结算一次伤害后自毁

## 爆炸中心伤害
var explosion_damage: int = 20
## 命中半径（像素）
var explosion_radius: float = 90.0
## 敌人管理器引用（用于枚举 CombatEnemy）
var _enemy_manager: Node = null


## 由 CombatEffectRunner 在加入树前调用：写入伤害、半径与敌人容器
func setup(enemy_manager: Node, dmg: int, radius_px: float) -> void:
	_enemy_manager = enemy_manager
	explosion_damage = maxi(0, dmg)
	explosion_radius = maxf(1.0, radius_px)


## 首帧结算伤害并短时后销毁节点
func _ready() -> void:
	_apply_explosion_damage()
	queue_redraw()
	var tw: SceneTreeTimer = get_tree().create_timer(0.18)
	tw.timeout.connect(func () -> void:
		queue_free()
	)


## 对圆内存活敌人各调用一次 apply_damage
func _apply_explosion_damage() -> void:
	if _enemy_manager == null:
		return
	for child in _enemy_manager.get_children():
		var enemy := child as CombatEnemy
		if enemy == null or enemy.is_dead():
			continue
		if global_position.distance_to(enemy.global_position) <= explosion_radius:
			enemy.apply_damage(explosion_damage)


## 调试绘制爆炸范围（淡红圈）
func _draw() -> void:
	draw_arc(Vector2.ZERO, explosion_radius, 0.0, TAU, 48, Color(1.0, 0.35, 0.1, 0.35), 3.0, true)
