class_name CombatHitbox2D
extends Area2D
## 通用战斗命中盒：`Area2D`；**碰撞形状**由检查器 **`hit_collision_shape`**（**`NodePath`**，相对本节点）指向单个 **`CollisionShape2D`**，在 **`_enter_tree`** 解析并 **`reparent`** 到本节点下；**空或无效**则生成**默认圆**。**`collision_mask`** 由调用方设为敌/玩家受击层，与 **`CombatHurtbox2D`** 分层配合。


## 命中宿主（**`CombatEnemy` 或 `CombatPlayer`**）与接触世界坐标；伤害通常已由 Hurtbox 结算
signal hit_body(body: Node2D, hit_position: Vector2)
## 瞬时模式：脉冲结束发出；若 **`queue_free_after_pulse`** 为真则本节点随后自毁
signal pulse_finished()

## 无绑定形状时生成的内置圆 **`CollisionShape2D`** 节点名，便于重复入树时去重
const _FALLBACK_HIT_SHAPE_NAME := &"_HitboxFallbackCircle"
## 无宿主形状时的默认 **`CircleShape2D` 半径**（像素）
const _FALLBACK_CIRCLE_RADIUS_PX: float = 16.0

## 为真时 `run_pulse_once` 结束后 `queue_free`（爆炸子节点）
var _free_after_pulse: bool = false
## 避免 `body_entered` 重复连接
var _monitoring_connected: bool = false
## 避免 `area_entered` 重复连接
var _monitoring_area_connected: bool = false
## 非空时由 Hitbox 向 Hurtbox **`receive_hit`**
var hit_delivery: CombatHitDelivery = null
## 为真时每物理帧对重叠的 Hurtbox 重复投递（贴近伤；依赖接收端冷却）；**`EnemyContactHitbox2D`** 使用
var repeat_deliver_overlapping_areas: bool = false
## 为真时不发 **`hit_body`**（避免每帧穿透信号）
var suppress_hit_body_signal: bool = false

@export_group("命中形状", "hit_")
## 指向 **`CollisionShape2D`** 的路径（相对本 **`Area2D`**）；检查器拖节点会写入 **`NodePath`**；运行时 **`reparent`** 到本节点；**空**则回退圆
@export var hit_collision_shape: NodePath = NodePath("")


func _enter_tree() -> void:
	## 推迟到本帧消息队列末尾：避免宿主仍在 **`add_child`** 栈内时 **`reparent`** 触发「父节点正忙」错误
	call_deferred("_attach_hit_shape_from_export_or_fallback")


func _ready() -> void:
	set_physics_process(false)


## 统计本 **`Area2D`** 下 **`CollisionShape2D`** 子节点数量（含回退圆）
func _count_collision_shapes_on_self() -> int:
	var n := 0
	for c in get_children():
		if c is CollisionShape2D:
			n += 1
	return n


## 移除本节点下由本脚本生成的回退圆，避免与绑定形状并存
func _remove_fallback_shape_if_any() -> void:
	var fb: Node = get_node_or_null(String(_FALLBACK_HIT_SHAPE_NAME))
	if fb != null:
		fb.queue_free()


## 无有效绑定时挂一个默认 **`CircleShape2D`**
func _ensure_fallback_circle_shape() -> void:
	if get_node_or_null(String(_FALLBACK_HIT_SHAPE_NAME)) != null:
		return
	var cs := CollisionShape2D.new()
	cs.name = _FALLBACK_HIT_SHAPE_NAME
	var circ := CircleShape2D.new()
	circ.radius = _FALLBACK_CIRCLE_RADIUS_PX
	cs.shape = circ
	add_child(cs)


## 将检查器绑定的形状（**`NodePath` → `CollisionShape2D`**）挂到本 Hitbox；无有效项则回退预制圆
func _attach_hit_shape_from_export_or_fallback() -> void:
	if not is_inside_tree():
		return
	if hit_collision_shape.is_empty():
		if _count_collision_shapes_on_self() > 0:
			return
		_ensure_fallback_circle_shape()
		return
	var n: Node = get_node_or_null(hit_collision_shape)
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


## 取用于飘字/反馈的参考形状：优先第一个带 **`CircleShape2D`** 的子碰撞体，否则第一个子碰撞体
func _primary_collision_shape_for_feedback() -> CollisionShape2D:
	for c in get_children():
		if c is CollisionShape2D:
			var cs := c as CollisionShape2D
			if cs.shape is CircleShape2D:
				return cs
	for c in get_children():
		if c is CollisionShape2D:
			return c as CollisionShape2D
	return null


## 写入本次攻击的投递数据（投射物/爆炸在 **`start_monitoring` / `run_pulse_once`** 前调用）
func set_hit_delivery(delivery: CombatHitDelivery) -> void:
	hit_delivery = delivery


## 开启或关闭每物理帧重叠投递（须在入树后、**`start_monitoring`** 前或后调用均可）
func configure_repeat_deliver(on: bool) -> void:
	repeat_deliver_overlapping_areas = on
	set_physics_process(on)


## 每物理帧：贴近持续投递（不发信号时 **`suppress_hit_body_signal`** 应为 true）
func _physics_process(_delta: float) -> void:
	if not repeat_deliver_overlapping_areas or hit_delivery == null:
		return
	for a in get_overlapping_areas():
		_deliver_to_hurtbox_area(a, not suppress_hit_body_signal)


## 由 **`CircleShape2D`** 圆心指向 **`target`** 中心取圆周上一点；多形状时以**首个圆**为参考
func _hit_feedback_world_for_target(target: Node2D) -> Vector2:
	if target == null:
		return global_position
	var center := global_position
	var eff_r: float = 8.0
	var col := _primary_collision_shape_for_feedback()
	if col != null:
		center = col.global_position
		var sh := col.shape
		if sh is CircleShape2D:
			var sc: Vector2 = col.global_transform.get_scale()
			eff_r = (sh as CircleShape2D).radius * maxf(absf(sc.x), absf(sc.y))
	var aim: Vector2 = target.global_position
	if target is CombatEnemy:
		aim = (target as CombatEnemy).get_hurtbox_anchor_global()
	var to_t: Vector2 = aim - center
	if to_t.length_squared() < 1e-8:
		return center + Vector2.RIGHT * eff_r
	return center + to_t.normalized() * eff_r


## **`hurtbox_mask_bits`**：敌受击层或玩家受击层（位标志）
func configure_collision_layers(hitbox_layer_bits: int, hurtbox_mask_bits: int) -> void:
	collision_layer = hitbox_layer_bits
	collision_mask = hurtbox_mask_bits
	monitoring = true
	monitorable = false


## 对所有子 **`CollisionShape2D`** 中 **`CircleShape2D`** 同步 **`radius`**（贴近敌 **`contact_touch_radius_px`** 等）
func apply_circle_radius_px(radius_px: float) -> void:
	var r: float = maxf(1.0, radius_px)
	for c in get_children():
		if c is CollisionShape2D:
			var sh := (c as CollisionShape2D).shape
			if sh is CircleShape2D:
				(sh as CircleShape2D).radius = r


## 下一物理帧执行一次重叠查询并向 Hurtbox 投递
func run_pulse_once(queue_free_after: bool = true) -> void:
	_free_after_pulse = queue_free_after
	call_deferred("_run_pulse_once")


## 持续监听重叠；补扫首帧已压在形状内的 Hurtbox
func start_monitoring() -> void:
	if not _monitoring_area_connected:
		area_entered.connect(_on_area_entered_monitoring)
		_monitoring_area_connected = true
	if not _monitoring_connected:
		body_entered.connect(_on_body_entered_monitoring)
		_monitoring_connected = true
	call_deferred("_scan_initial_overlaps")


## 对已压在形状内的 Hurtbox 补投递
func _scan_initial_overlaps() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	for a in get_overlapping_areas():
		_on_area_entered_monitoring(a)
	for b in get_overlapping_bodies():
		_on_body_entered_monitoring(b)


## 脉冲：对所有重叠 Hurtbox 各投递一次
func _run_pulse_once() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	for a in get_overlapping_areas():
		_deliver_to_hurtbox_area(a, true)
	pulse_finished.emit()
	if _free_after_pulse:
		queue_free()


## 进入形状的 Hurtbox：投递并可选通知监听方
func _on_area_entered_monitoring(area: Area2D) -> void:
	_deliver_to_hurtbox_area(area, not suppress_hit_body_signal)


## 兼容无 Hurtbox 的 **`CharacterBody2D`**：仅发 **`hit_body`**
func _on_body_entered_monitoring(body: Node) -> void:
	var nd := body as Node2D
	if nd == null:
		return
	if hit_delivery != null:
		return
	hit_body.emit(nd, _hit_feedback_world_for_target(nd))


func _deliver_to_hurtbox_area(area: Area2D, emit_hit_body: bool) -> void:
	# 尝试将参数 area 转为 CombatHurtbox2D 类型，代表被攻击目标的受击盒
	var hb := area as CombatHurtbox2D
	if hb == null:
		# 如果 area 不是 CombatHurtbox2D，直接返回
		return
	# 获取受击盒所属敌人（如果有）
	var host_enemy: CombatEnemy = hb.get_host_combat_enemy()
	# 获取受击盒所属玩家（如果有）
	var host_player: CombatPlayer = hb.get_host_combat_player()
	if host_enemy != null:
		# 如果存在敌人宿主
		if host_enemy.is_dead():
			# 若敌人已死亡，不做处理直接返回
			return
	elif host_player != null:
		# 如果存在玩家宿主（且未匹配敌人分支时）
		if host_player.is_dead():
			# 若玩家已死亡，不做处理直接返回
			return
	else:
		# 若没有宿主，直接返回
		return
	# 计算命中的世界坐标点，用于反馈/表现
	var hit_pt: Vector2 = _hit_feedback_world_for_target(area as Node2D)
	if hit_delivery == null:
		# 若当前没有可用的命中数据（HitDelivery），直接返回
		return
	# 通知受击盒被命中，将命中数据和世界坐标传递过去
	hb.receive_hit(hit_delivery, hit_pt)
	if emit_hit_body:
		# 若需要对外发送 signal，确定实际命中的 Node2D（敌人或玩家）
		var sig_body: Node2D = (host_enemy as Node2D) if host_enemy != null else (host_player as Node2D)
		# 发送 hit_body 信号，附带命中的角色和命中点
		hit_body.emit(sig_body, hit_pt)
