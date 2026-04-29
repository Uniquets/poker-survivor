extends CharacterBody2D
class_name CombatEnemy
## 策划表：**`@export` 默认** 与 **`EnemyConfig`** 脚本内默认值（`enemy_config.gd` / `enemy_config.tres`）一致；**类体不读** **`GameConfig`**，避免与 **`GAME_GLOBAL`** 静态初始化环

## 追击玩家的敌人：移动、接触伤害、生命与自毁

## 预载掉落条目脚本，供运行时校验 **`death_drop_entries`** 元素类型，并协助 LSP 解析 **`EnemyDropEntry`**
const _EnemyDropEntryScript: GDScript = preload("res://scripts/combat/enemy_drop_entry.gd")

## 移动速度（像素/秒）
@export var move_speed: float = 120.0
## 与玩家重叠时造成的伤害
@export var touch_damage: int = 10
## 最大生命
@export var max_health: int = 30
## 单种敌人死亡时按条目独立掷概率；元素须为 **`EnemyDropEntry`** 资源（**`enemy_drop_entry.gd`**）；空数组则不掉落
@export var death_drop_entries: Array = []
## 与 **`class_name CombatHealthComponent`** 同脚本；**`preload`** 供本文件类型解析与 LSP，避免仅依赖全局类名索引顺序
const _CombatHealthComponentScript = preload("res://scripts/combat/combat_health_component.gd")

## 追击目标（通常为玩家）
var target: Node2D
## 是否已死亡（生命由子节点 **`CombatHealthComponent`** 管理）
var _dead := false
## 贴近玩家时用于 **`CombatHitbox2D`** 投递 **`touch_damage`**（场景子节点名须为 **`EnemyContactHitbox2D`**）
@onready var _contact_hitbox: CombatHitbox2D = get_node_or_null("EnemyContactHitbox2D") as CombatHitbox2D
## 复用的接触投递（每物理帧更新 **`damage`**）
var _contact_delivery: CombatHitDelivery = CombatHitDelivery.new()
## 敌人 **`EnemyContactHitbox2D`** 接触伤害圆半径（像素）；与根 **`CharacterBody2D`** 物理碰撞圆分离，便于单独调贴脸范围
@export var contact_touch_radius_px: float = 48.0

@export_group("表现", "anim_")
## 行走/待机动画所在 **`AnimatedSprite2D`**（相对本敌人根）；**空**则不播精灵动画、`_draw` 占位圆仍可用。**朝向约定**：与玩家一致，**默认贴图朝右**；追击时向左则 **`flip_h`**，请在美术侧统一右向基准
@export var animated_sprite_node: NodePath = NodePath("")

## 缓存的精灵；由 **`animated_sprite_node`** 在 **`_ready`** 解析
var _animated_sprite: AnimatedSprite2D = null
## 受击闪白：根节点 **`modulate`** 拉亮峰值（略超 1 以增强可见度）
const _HIT_FLASH_WHITE_PEAK: Color = Color(2.6, 2.6, 2.6, 1.0)
## 受击闪白：拉到峰值时长（秒）
const _HIT_FLASH_IN_SEC: float = 0.05
## 受击闪白：回到白色时长（秒）
const _HIT_FLASH_OUT_SEC: float = 0.12
## 当前受击闪白 tween；连打打断重来，避免 **`modulate`** 叠偏
var _hit_flash_tween: Tween = null
## 受击击退残留速度（像素/秒）；每帧衰减并与追击 **`velocity`** 叠加
var _knockback_velocity: Vector2 = Vector2.ZERO
## 击退残留指数衰减系数（秒⁻¹）；由 **`apply_hit_knockback`** 根据投递解析刷新；**`_ready`** 对齐牌型默认
var _knockback_decay_rate: float = 7.0


## 初始化生命与碰撞层；若槽位绑定 **`AnimatedSprite2D`** 则播放首段动画（美术敌人），并避免占位 `_draw` 盖住精灵；配置贴近玩家的 **`CombatHitbox2D`**
func _ready() -> void:
	collision_layer = GameConfig.GAME_GLOBAL.enemy_collision_layer
	collision_mask = GameConfig.GAME_GLOBAL.enemy_collision_mask
	if not animated_sprite_node.is_empty():
		_animated_sprite = get_node_or_null(animated_sprite_node) as AnimatedSprite2D
	var anim := _animated_sprite
	if anim != null and anim.sprite_frames != null:
		var anim_names := anim.sprite_frames.get_animation_names()
		if anim_names.size() > 0:
			anim.play(anim_names[0])
	queue_redraw()
	var hc: Node = get_node_or_null("CombatHealthComponent")
	if hc != null and hc.get_script() == _CombatHealthComponentScript:
		if not hc.depleted.is_connected(_on_combat_health_depleted):
			hc.depleted.connect(_on_combat_health_depleted)
	_knockback_decay_rate = GameConfig.COMBAT_PRESENTATION.hit_knockback_decay_per_second
	## 推迟：等 **`EnemyContactHitbox2D`** 将 **`HitShape`** **`reparent`** 后再调半径与监听
	call_deferred("_setup_contact_hitbox")


## **`CombatHealthComponent`** 生命归零：进入死亡流程
func _on_combat_health_depleted() -> void:
	_die()


## 子节点 **`EnemyContactHitbox2D`**：层掩码打 **`combat_player_hurtbox_collision_layer`**，每帧重复投递、由玩家 **`receive_contact_damage`** 冷却
func _setup_contact_hitbox() -> void:
	if _contact_hitbox == null:
		return
	_contact_delivery.source = self
	_contact_delivery.use_player_contact_gate = true
	_contact_delivery.knockback_speed = 0.0
	_contact_hitbox.suppress_hit_body_signal = true
	_contact_hitbox.configure_repeat_deliver(true)
	_contact_hitbox.set_hit_delivery(_contact_delivery)
	var gg := GameConfig.GAME_GLOBAL
	_contact_hitbox.configure_collision_layers(
		gg.combat_hitbox_collision_layer,
		gg.combat_player_hurtbox_collision_layer
	)
	_contact_hitbox.apply_circle_radius_px(contact_touch_radius_px)
	_contact_hitbox.start_monitoring()


## 朝玩家根 **`global_position`** 追击；与玩家距离小于 **`EnemyConfig.chase_stop_distance_to_player`** 时停止追击向位移（击退仍生效）；贴近伤由子节点 Hitbox→玩家 Hurtbox 处理；**`AnimatedSprite2D`** 与玩家一致：**默认贴图朝右**，水平追击 **`direction.x < 0`**（向左）时 **`flip_h = true`**
func _physics_process(_delta: float) -> void:
	if _dead:
		velocity = Vector2.ZERO
		_knockback_velocity = Vector2.ZERO
		move_and_slide()
		return

	if _contact_hitbox != null:
		_contact_delivery.damage = touch_damage

	_decay_knockback_velocity(_delta)

	if not is_instance_valid(target):
		velocity = _knockback_velocity
		move_and_slide()
		return

	var to_player: Vector2 = target.global_position - global_position
	var dist: float = to_player.length()
	var stop_d: float = maxf(0.0, GameConfig.ENEMY_CONFIG.chase_stop_distance_to_player)
	var direction: Vector2 = Vector2.ZERO
	if dist >= stop_d and dist > 0.001:
		direction = to_player / dist
	var chase_vel: Vector2 = direction * move_speed
	velocity = chase_vel + _knockback_velocity
	var sprite := _animated_sprite
	if sprite != null and is_instance_valid(sprite) and absf(direction.x) > 0.05:
		## 中文：与 **`player.gd`** 的 **`_update_sprite_facing_from_velocity`** 同一约定——贴图默认朝**右**；向左追玩家则翻面
		sprite.flip_h = direction.x < 0.0
	move_and_slide()


## 每帧衰减击退残留（指数衰减 + 小阈值清零）
func _decay_knockback_velocity(delta: float) -> void:
	var k: float = _knockback_decay_rate
	if k > 0.0:
		_knockback_velocity *= exp(-k * delta)
	if _knockback_velocity.length_squared() < 4.0:
		_knockback_velocity = Vector2.ZERO


## 受到伤害（经 **`CombatHealthComponent`**）；**`p_hit_feedback_world`** 为飘字世界坐标；**`hit_delivery`** 为 null 时 **`CombatHealthComponent`** 内会为击退构造默认 **`CombatHitDelivery`**
func apply_damage(
	amount: int,
	p_hit_feedback_world: Vector2 = Vector2(NAN, NAN),
	hit_delivery: CombatHitDelivery = null
) -> void:
	if _dead:
		return
	var hc: Node = get_node_or_null("CombatHealthComponent")
	if hc == null or hc.get_script() != _CombatHealthComponentScript:
		push_warning("CombatEnemy: 缺少子节点 CombatHealthComponent，apply_damage 已忽略")
		return
	hc.take_damage_enemy(amount, p_hit_feedback_world, hit_delivery)


## 由 **`CombatHealthComponent`** 在扣血成功后调用：按 **`CombatHitDelivery`** 与命中点叠加击退
func apply_hit_knockback(hit_world: Vector2, delivery: CombatHitDelivery, damage_dealt: int) -> void:
	if _dead or damage_dealt <= 0 or delivery == null:
		return
	_knockback_decay_rate = delivery.get_effective_knockback_decay_per_second()
	var spd: float = delivery.get_effective_knockback_speed()
	if spd <= 0.0:
		return
	var ref: Vector2 = get_hurtbox_anchor_global()
	var dir: Vector2 = ref - hit_world
	if not hit_world.is_finite() or dir.length_squared() < 1e-8:
		if delivery.source is Node2D and is_instance_valid(delivery.source as Node2D):
			dir = ref - (delivery.source as Node2D).global_position
		if dir.length_squared() < 1e-8:
			dir = Vector2.RIGHT
	dir = dir.normalized()
	_knockback_velocity += dir * spd


## 查询是否已死亡
func is_dead() -> bool:
	return _dead


## 扣血成功时由 **`CombatHealthComponent`** 调用：根节点短时闪白增强打击感（无精灵占位圆亦受 **`modulate`** 影响）
func play_hit_white_flash() -> void:
	if _dead:
		return
	if _hit_flash_tween != null and is_instance_valid(_hit_flash_tween):
		_hit_flash_tween.kill()
		_hit_flash_tween = null
	modulate = Color.WHITE
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_property(self, "modulate", _HIT_FLASH_WHITE_PEAK, _HIT_FLASH_IN_SEC)
	_hit_flash_tween.tween_property(self, "modulate", Color.WHITE, _HIT_FLASH_OUT_SEC)
	_hit_flash_tween.finished.connect(
		func () -> void:
			_hit_flash_tween = null
	)


## 弹道/激光/爆炸圆心等**瞄准用**世界点：优先子节点 **`CombatHurtbox2D`** 原点（与受击 **`Area2D`** 对齐，多在躯干）；无则回落脚点 **`global_position`**
func get_hurtbox_anchor_global() -> Vector2:
	var hb: CombatHurtbox2D = find_child("CombatHurtbox2D", true, false) as CombatHurtbox2D
	if hb != null and is_instance_valid(hb):
		return hb.global_position
	return global_position


## 死亡后 queue_free
func _die() -> void:
	_dead = true
	if _hit_flash_tween != null and is_instance_valid(_hit_flash_tween):
		_hit_flash_tween.kill()
		_hit_flash_tween = null
	modulate = Color.WHITE
	print("[combat] enemy_killed | node=%s" % name)
	## 计入本局 HUD 击杀数（与掉落经验独立）
	var em: EnemyManager = EnemyManager.get_enemy_manager()
	if em != null and is_instance_valid(em):
		em.register_enemy_kill(self)
	_spawn_death_drops()
	queue_free()


## 按 **`death_drop_entries`** 逐条掷概率，在 **`EnemyManager.units_root`** 上实例化拾取物；与经验豆相同带微小位置抖动
func _spawn_death_drops() -> void:
	if death_drop_entries.is_empty():
		return
	var em := EnemyManager.get_enemy_manager()
	if em == null or not is_instance_valid(em):
		return
	var root: Node = em.get_units_root()
	if root == null:
		return
	for entry in death_drop_entries:
		if entry == null or entry.get_script() != _EnemyDropEntryScript:
			continue
		var p: float = clampf(float(entry.get("drop_probability")), 0.0, 1.0)
		## 中文：**`randf()` ∈ [0,1)`**；**`< p`** 为成功，**`p=1`** 时必掉，**`p=0.1`** 约一成
		if randf() >= p:
			continue
		var ps: PackedScene = entry.get("pickup_scene") as PackedScene
		if ps == null:
			continue
		var inst: Node = ps.instantiate()
		if inst == null:
			continue
		root.add_child(inst)
		if inst is Node2D:
			(inst as Node2D).global_position = global_position + Vector2(
				randf_range(-16.0, 16.0),
				randf_range(-10.0, 10.0)
			)


## 绘制敌人占位圆点；槽位已绑定有效精灵时跳过，以免与 `Slm` 等美术资源叠绘
func _draw() -> void:
	if _animated_sprite != null and is_instance_valid(_animated_sprite):
		return
	draw_circle(Vector2.ZERO, GameConfig.ENEMY_CONFIG.draw_radius, Color(1.0, 0.25, 0.25))
