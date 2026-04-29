extends Node2D
## 单次圆形爆炸：宿主根下 **`HitShape`**（由 **`CombatHitbox2D.hit_collision_shape`** **`NodePath`** 收编并 **`reparent`**）与 **`CombatHitbox2D`** 逻辑分离；`setup` 将策划 **`explosion_radius`** 同步到圆半径后 **`run_pulse_once`**；伤害由 Hitbox 脉冲扫层结算

## 爆炸中心伤害
var explosion_damage: int = 20
## 命中半径（像素）；与 `_draw` 调试圈及 **`CombatHitbox2D`** 圆半径同步
var explosion_radius: float = 90.0
## 敌人管理器引用（用于表现父节点等）
var _enemy_manager: Node = null
## 非空且配置有爆炸中心表现预制时，在**同世界坐标**挂表现预制（与逻辑节点兄弟，避免随本节点 0.18s 销毁）
var _hit_vfx_parent: Node = null
## 脉冲投递：由 **`CombatHitbox2D`** 向各 **`CombatHurtbox2D`** 扣血
var _explosion_hit_delivery: CombatHitDelivery = null
## 场景内命中盒（勿改名，与 `ExplosionOneShot.tscn` 一致）
@onready var _combat_hitbox: Area2D = $CombatHitbox2D


## 由 CombatEffectRunner / `EightExplosiveProjectile` 在加入树前调用：写入伤害、半径与敌人容器；**`hit_vfx_parent`** 仅点数 8 传入，用于挂载爆炸序列帧
func setup(enemy_manager: Node, dmg: int, radius_px: float, hit_vfx_parent: Node = null) -> void:
	_enemy_manager = enemy_manager
	explosion_damage = maxi(0, dmg)
	explosion_radius = maxf(1.0, radius_px)
	_hit_vfx_parent = hit_vfx_parent


## 首帧：配 Hitbox 层、把策划半径写入场景圆、脉冲扫敌；表现与调试绘制；短时后销毁逻辑根节点
func _ready() -> void:
	## 推迟：等子节点 **`CombatHitbox2D`** 将 **`HitShape`** 从宿主 **`reparent`** 完成后再改半径与脉冲
	call_deferred("_setup_scene_hitbox_for_pulse")
	_spawn_rank8_hit_vfx_if_configured()
	queue_redraw()
	var tw: SceneTreeTimer = get_tree().create_timer(0.18)
	tw.timeout.connect(func () -> void:
		queue_free()
	)


## 使用预制体内 **`CombatHitbox2D`**：配层掩码；**`apply_circle_radius_px`** 作用于 Hitbox 子级下所有圆（含从槽位收编的形状）；随后 **`run_pulse_once`**
func _setup_scene_hitbox_for_pulse() -> void:
	if _combat_hitbox == null:
		return
	_explosion_hit_delivery = CombatHitDelivery.new()
	_explosion_hit_delivery.damage = explosion_damage
	_explosion_hit_delivery.source = self
	var gg := GameConfig.GAME_GLOBAL
	if _combat_hitbox.has_method("set_hit_delivery"):
		_combat_hitbox.call("set_hit_delivery", _explosion_hit_delivery)
	if _combat_hitbox.has_method("configure_collision_layers"):
		_combat_hitbox.call(
			"configure_collision_layers",
			gg.combat_hitbox_collision_layer,
			gg.combat_hurtbox_collision_layer
		)
	if _combat_hitbox.has_method("apply_circle_radius_px"):
		_combat_hitbox.call("apply_circle_radius_px", explosion_radius)
	if _combat_hitbox.has_signal("hit_body") and not _combat_hitbox.hit_body.is_connected(_on_hitbox_hit_body):
		_combat_hitbox.hit_body.connect(_on_hitbox_hit_body)
	if _combat_hitbox.has_method("run_pulse_once"):
		_combat_hitbox.call("run_pulse_once", true)


## 脉冲命中：扣血已由 Hitbox→Hurtbox 完成；此处仅挂近身命中表现
func _on_hitbox_hit_body(_body: Node2D, hit_position: Vector2) -> void:
	_spawn_contact_hit_feedback_at(hit_position)


## 在 **`world_pos`** 挂一次近身受击反馈预制（**`COMBAT_PRESENTATION.hit_feedback_vfx_scene`**）；与整圈爆炸中心表现互补
func _spawn_contact_hit_feedback_at(world_pos: Vector2) -> void:
	var ps: PackedScene = GameConfig.COMBAT_PRESENTATION.hit_feedback_vfx_scene
	if ps == null:
		return
	var p := get_parent()
	if p == null:
		return
	var inst: Node = ps.instantiate()
	inst.global_position = world_pos
	p.call_deferred("add_child", inst)


## 扇形爆炸载荷专用：从 **`COMBAT_PRESENTATION.explosion_hit_vfx_scene`** 实例化，挂到 `_hit_vfx_parent`（与逻辑爆炸同级）
func _spawn_rank8_hit_vfx_if_configured() -> void:
	if _hit_vfx_parent == null or not is_instance_valid(_hit_vfx_parent):
		return
	var ps: PackedScene = GameConfig.COMBAT_PRESENTATION.explosion_hit_vfx_scene
	if ps == null:
		return
	var vfx: Node = ps.instantiate()
	vfx.global_position = global_position
	_hit_vfx_parent.call_deferred("add_child", vfx)


## 调试绘制爆炸范围（淡红圈）；与 Hitbox 圆一致（依赖 **`explosion_radius`**）
func _draw() -> void:
	draw_arc(Vector2.ZERO, explosion_radius, 0.0, TAU, 48, Color(1.0, 0.35, 0.1, 0.35), 3.0, true)
