class_name CombatHurtbox2D
extends Area2D
## 受击盒：与 **`CombatHitbox2D`** 通过**不同物理层**配对；命中时转调父节点下 **`CombatHealthComponent.apply_hit_delivery`**。
## **碰撞形状**：由检查器 **`hurt_collision_shape`**（**`NodePath`**，相对本节点）指向单个 **`CollisionShape2D`**，在 **`_enter_tree`** 解析并 **`reparent`** 到本节点；**空或无效**则生成**默认圆**。


## 宿主类型：决定 **`collision_layer`** 与向上解析宿主引用（供 Hitbox **`hit_body`** 信号取 **`CombatEnemy` / `CombatPlayer`**）
enum HurtboxHostKind { ENEMY, PLAYER }

## 检查器可选；场景中敌用默认 **ENEMY**，玩家预制设为 **PLAYER**
@export var host_kind: HurtboxHostKind = HurtboxHostKind.ENEMY

@export_group("受击形状", "hurt_")
## 指向 **`CollisionShape2D`** 的路径（相对本 **`Area2D`**）；检查器拖节点会写入 **`NodePath`**；运行时 **`reparent`** 到本节点；**空**则回退内置圆
@export var hurt_collision_shape: NodePath = NodePath("")

## 无有效绑定时生成的内置圆节点名
const _FALLBACK_HURT_SHAPE_NAME := &"_HurtboxFallbackCircle"
## 回退圆半径（像素）
const _FALLBACK_CIRCLE_RADIUS_PX: float = 22.0

## 缓存的 **`CombatEnemy`**（仅 **`host_kind == ENEMY`** 时有效，供 **`CombatHitbox2D`** 穿透等）
var _host_enemy: CombatEnemy = null
## 缓存的 **`CombatPlayer`**（仅 **`host_kind == PLAYER`** 时有效）
var _host_player: CombatPlayer = null


func _enter_tree() -> void:
	## 推迟到本帧消息队列末尾：避免宿主仍在 **`add_child`** 栈内时 **`reparent`** 触发「父节点正忙」错误
	call_deferred("_attach_hurt_shape_from_export_or_fallback")


func _ready() -> void:
	var gg := GameConfig.GAME_GLOBAL
	collision_mask = 0
	monitoring = false
	monitorable = true
	match host_kind:
		HurtboxHostKind.ENEMY:
			collision_layer = gg.combat_hurtbox_collision_layer
			var p: Node = get_parent()
			while p != null:
				if p is CombatEnemy:
					_host_enemy = p as CombatEnemy
					break
				p = p.get_parent()
		HurtboxHostKind.PLAYER:
			collision_layer = gg.combat_player_hurtbox_collision_layer
			var q: Node = get_parent()
			while q != null:
				if q is CombatPlayer:
					_host_player = q as CombatPlayer
					break
				q = q.get_parent()


func _count_collision_shapes_on_self() -> int:
	var n := 0
	for c in get_children():
		if c is CollisionShape2D:
			n += 1
	return n


func _remove_fallback_shape_if_any() -> void:
	var fb: Node = get_node_or_null(String(_FALLBACK_HURT_SHAPE_NAME))
	if fb != null:
		fb.queue_free()


func _ensure_fallback_circle_shape() -> void:
	if get_node_or_null(String(_FALLBACK_HURT_SHAPE_NAME)) != null:
		return
	var cs := CollisionShape2D.new()
	cs.name = _FALLBACK_HURT_SHAPE_NAME
	var circ := CircleShape2D.new()
	circ.radius = _FALLBACK_CIRCLE_RADIUS_PX
	cs.shape = circ
	add_child(cs)


## 将检查器绑定的形状挂到本 **`Area2D`**；否则回退圆
func _attach_hurt_shape_from_export_or_fallback() -> void:
	if not is_inside_tree():
		return
	if hurt_collision_shape.is_empty():
		if _count_collision_shapes_on_self() > 0:
			return
		_ensure_fallback_circle_shape()
		return
	var n: Node = get_node_or_null(hurt_collision_shape)
	if n == null or not (n is CollisionShape2D):
		if _count_collision_shapes_on_self() > 0:
			return
		_ensure_fallback_circle_shape()
		return
	var sh: CollisionShape2D = n as CollisionShape2D
	if not is_instance_valid(sh):
		if _count_collision_shapes_on_self() > 0:
			return
		_ensure_fallback_circle_shape()
		return
	if sh.get_parent() != self:
		sh.reparent(self)
	_remove_fallback_shape_if_any()


## 供 Hitbox 发 **`hit_body`** 时取敌宿主（弹道穿透等）
func get_host_combat_enemy() -> CombatEnemy:
	return _host_enemy


## 供 Hitbox 发信号或调试时取玩家宿主
func get_host_combat_player() -> CombatPlayer:
	return _host_player


## 由 **`CombatHitbox2D`** 或静态投递入口调用：转 **`CombatHealthComponent`**
func receive_hit(delivery: CombatHitDelivery, hit_world: Vector2) -> void:
	if delivery == null:
		return
	var hc: CombatHealthComponent = get_parent().get_node_or_null("CombatHealthComponent") as CombatHealthComponent
	if hc != null:
		hc.apply_hit_delivery(delivery, hit_world)
		return
	push_warning("CombatHurtbox2D: 父节点缺少 CombatHealthComponent，已忽略命中")
	return


## 尽量经子节点 **`CombatHurtbox2D`** 对敌扣血，否则回落 **`apply_damage`**
static func deliver_to_enemy_best_effort(enemy: CombatEnemy, delivery: CombatHitDelivery, hit_world: Vector2) -> void:
	if enemy == null or delivery == null:
		return
	var hb: CombatHurtbox2D = enemy.find_child("CombatHurtbox2D", true, false) as CombatHurtbox2D
	if hb != null:
		hb.receive_hit(delivery, hit_world)
	else:
		enemy.apply_damage(delivery.damage, hit_world, delivery)


## 尽量经子节点 **`CombatHurtbox2D`** 对玩家结算，否则按投递标志回落
static func deliver_to_player_best_effort(player: CombatPlayer, delivery: CombatHitDelivery, hit_world: Vector2) -> void:
	if player == null or delivery == null:
		return
	var hb: CombatHurtbox2D = player.find_child("CombatHurtbox2D", true, false) as CombatHurtbox2D
	if hb != null:
		hb.receive_hit(delivery, hit_world)
	else:
		if delivery.use_player_contact_gate:
			player.receive_contact_damage(delivery.damage)
		else:
			player.apply_damage(delivery.damage, hit_world, delivery)
