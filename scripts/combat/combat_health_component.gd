extends Node
class_name CombatHealthComponent
## 统一「受击→扣生命」入口：**`CombatHurtbox2D`** 只与本节点对话，不再区分宿主类型分支。
## - **敌**：本节点持有 **`current_health`**，飘字与归零发 **`depleted`**，由 **`CombatEnemy`** 接 **`_die`**。
## - **玩家**：本节点为薄转发，护盾/复活/无敌仍在 **`CombatPlayer`**。


## 敌宿主归零后由 **`CombatEnemy`** 监听并 **`_die`**
signal depleted

## 子模式（由父节点类型在 **`_ready`** 判定）
enum _HostMode { NONE, ENEMY, PLAYER }

var _host_mode: _HostMode = _HostMode.NONE
## 敌宿主（**`ENEMY`** 模式）
var _enemy: CombatEnemy = null
## 玩家宿主（**`PLAYER`** 模式）
var _player: CombatPlayer = null
## 敌当前生命（仅 **`ENEMY`** 使用）
var _enemy_current_health: int = 0
## 避免 **`depleted`** 连发
var _enemy_depleted_emitted: bool = false


func _ready() -> void:
	var p: Node = get_parent()
	if p is CombatEnemy:
		_host_mode = _HostMode.ENEMY
		_enemy = p as CombatEnemy
		_enemy_current_health = maxi(1, _enemy.max_health)
	elif p is CombatPlayer:
		_host_mode = _HostMode.PLAYER
		_player = p as CombatPlayer
	else:
		push_warning("CombatHealthComponent: 父节点须为 CombatEnemy 或 CombatPlayer")


## 由 **`CombatHurtbox2D`** 调用：按 **`CombatHitDelivery`** 与命中世界坐标结算
func apply_hit_delivery(delivery: CombatHitDelivery, hit_world: Vector2) -> void:
	if delivery == null:
		return
	match _host_mode:
		_HostMode.ENEMY:
			take_damage_enemy(delivery.damage, hit_world, delivery)
		_HostMode.PLAYER:
			if _player == null or _player.is_dead():
				return
			if delivery.use_player_contact_gate:
				_player.receive_contact_damage(delivery.damage)
			else:
				_player.apply_damage(delivery.damage, hit_world, delivery)
		_:
			pass


## 敌：直接扣血（卡牌经 Hurtbox 投递与 **`CombatEnemy.apply_damage`** 回落共用）；**`delivery`** 为 null 时仍按全局默认击退处理
func take_damage_enemy(
	amount: int,
	hit_world: Vector2 = Vector2(NAN, NAN),
	delivery: CombatHitDelivery = null
) -> void:
	if _host_mode != _HostMode.ENEMY or _enemy == null or _enemy.is_dead():
		return
	if _enemy_current_health <= 0:
		return
	var clamped_damage: int = maxi(amount, 0)
	if clamped_damage > 0:
		var float_at: Vector2 = (
			hit_world if hit_world.is_finite() else _enemy.get_hurtbox_anchor_global()
		)
		GameToolSingleton.world_damage_float(float_at, clamped_damage, Vector2(0, -22))
		_enemy.play_hit_white_flash()
	_enemy_current_health = maxi(0, _enemy_current_health - clamped_damage)
	var kb_delivery: CombatHitDelivery = delivery
	if kb_delivery == null and clamped_damage > 0:
		kb_delivery = CombatHitDelivery.new()
	if clamped_damage > 0 and kb_delivery != null:
		_enemy.apply_hit_knockback(hit_world, kb_delivery, clamped_damage)
	if _enemy_current_health <= 0 and not _enemy_depleted_emitted:
		_enemy_depleted_emitted = true
		depleted.emit()


## 敌当前生命（供扩展）
func get_enemy_current_health() -> int:
	return _enemy_current_health


## 覆盖敌人最大生命值，并可选把当前生命回满。
func set_enemy_max_health(value: int, refill: bool) -> void:
	if _host_mode != _HostMode.ENEMY or _enemy == null:
		return
	_enemy.max_health = maxi(1, value)
	if refill:
		_enemy_current_health = _enemy.max_health
	else:
		_enemy_current_health = mini(_enemy_current_health, _enemy.max_health)
