extends Node
class_name AutoAttackSystem
## 无卡时自动朝最近敌发射弹道；有 CardRuntime 时改为监听 group_played 结算组牌伤害

## 无卡自动射击间隔（秒）
@export var attack_interval_seconds: float = CombatTuning.PLAYER_AUTO_ATTACK_INTERVAL_SECONDS
## 无卡自动射击单发伤害
@export var base_attack_damage: int = CombatTuning.PLAYER_AUTO_ATTACK_DAMAGE

## 距下次自动射击剩余秒数
var _time_until_attack_seconds := 0.0
## 弹道场景
var _projectile_scene: PackedScene
## 父场景 CardRuntime（可为 null）
var _card_runtime = null
## 效果解析器实例
var _effect_resolver = null

## 单张牌名参与攻击时（预留）
signal card_attacked(card_name: String, damage: int)
## 一组牌结算后发出总伤害等信息
signal group_attacked(group_type: String, total_damage: int)


## 加载弹道与解析器，并尝试绑定 CardRuntime
func _ready() -> void:
	_time_until_attack_seconds = attack_interval_seconds
	_projectile_scene = load("res://scenes/combat/Projectile.tscn")
	_effect_resolver = load("res://scripts/cards/effect_resolver.gd").new()
	_find_card_runtime()


## 从父节点取 CardRuntime 并连接 group_played
func _find_card_runtime() -> void:
	var parent_node := get_parent()
	if parent_node != null and parent_node.has_node("CardRuntime"):
		_card_runtime = parent_node.get_node("CardRuntime")
		if _card_runtime != null:
			_card_runtime.group_played.connect(_on_group_played)


## 有 CardRuntime 时不跑旧自动射击；否则倒计时射击一次
func _process(delta: float) -> void:
	if _card_runtime != null:
		return
	
	if not _can_attack():
		return

	_time_until_attack_seconds -= delta
	if _time_until_attack_seconds > 0.0:
		return

	_time_until_attack_seconds = max(attack_interval_seconds, 0.05)
	_attack_once(base_attack_damage)


## 要求父场景存在 Player 与 EnemyManager
func _can_attack() -> bool:
	var parent_node := get_parent()
	if parent_node == null:
		return false
	if not parent_node.has_node("Player"):
		return false
	if not parent_node.has_node("EnemyManager"):
		return false
	return true


## 对最近敌发射弹道或直接扣血
func _attack_once(damage: int) -> void:
	var parent_node := get_parent()
	var player := parent_node.get_node_or_null("Player") as CombatPlayer
	var enemy_manager := parent_node.get_node_or_null("EnemyManager") as EnemyManager
	if not is_instance_valid(player) or not is_instance_valid(enemy_manager):
		return

	var target := _pick_target(enemy_manager, player.global_position)
	if target == null:
		return

	if _projectile_scene != null:
		_spawn_projectile(player.global_position, target, damage)
	else:
		target.apply_damage(damage)
		print("[combat] auto_attack | target=%s damage=%d" % [target.name, damage])


## 实例化弹道并设目标与伤害
func _spawn_projectile(start_pos: Vector2, target: Node2D, damage: int) -> void:
	var projectile := _projectile_scene.instantiate() as Node2D
	projectile.global_position = start_pos
	projectile.set("target", target)
	projectile.set("damage", damage)
	get_parent().add_child(projectile)
	print("[combat] projectile_spawned | target=%s damage=%d" % [target.name, damage])


## 在 enemy_manager 子节点中选距离 from_position 最近的存活敌
func _pick_target(enemy_manager: EnemyManager, from_position: Vector2) -> CombatEnemy:
	var nearest_enemy: CombatEnemy = null
	var nearest_distance_sq := INF
	for child in enemy_manager.get_children():
		var enemy := child as CombatEnemy
		if enemy == null:
			continue
		if enemy.is_dead():
			continue
		var distance_sq := from_position.distance_squared_to(enemy.global_position)
		if distance_sq < nearest_distance_sq:
			nearest_enemy = enemy
			nearest_distance_sq = distance_sq
	return nearest_enemy


## 组牌打出：解析效果并对目标多次生成弹道
func _on_group_played(cards, group_type) -> void:
	var parent_node := get_parent() # 取得父节点（通常为场景主控节点）
	var player := parent_node.get_node_or_null("Player") as CombatPlayer # 获取玩家节点
	var enemy_manager := parent_node.get_node_or_null("EnemyManager") as EnemyManager # 获取敌人管理器
	if not is_instance_valid(player) or not is_instance_valid(enemy_manager):
		return # 节点无效时直接返回，不处理

	var global_suit_counts = _calculate_global_suit_counts() # 统计全局（全手牌）各花色数目，供加成判断
	var result = _effect_resolver.resolve_effects(cards, group_type, global_suit_counts) 
	# 调用效果解析器，确定伤害、弹道数（命中次数）等

	_effect_resolver.debug_print(result) # 调试输出本次解析结果

	var target := _pick_target(enemy_manager, player.global_position) 
	# 选取距离玩家最近的活体敌人作为目标
	if target == null:
		return # 无敌可攻击时直接返回

	var hit_count = result.hit_count # 获取需发射弹道/命中次数
	for i in range(hit_count):
		# 每发一弹道，目标、伤害相同
		_spawn_projectile(player.global_position, target, result.damage)

	emit_signal("group_attacked", group_type, result.damage * hit_count)
	# 发送组攻击信号，参数为组类型、总伤害（单次伤害 * 命中次数）

	var card_names = []
	for card in cards:
		card_names.append(card.get_full_name()) # 将各张卡的完整名收集起来
	emit_signal("card_attacked", ", ".join(card_names), result.damage)
	# 发送 card_attacked 信号，带出本组涉及的所有卡名和单次伤害


## 统计当前手牌各花色张数（供全局花色加成）
func _calculate_global_suit_counts() -> Array:
	if _card_runtime == null:
		return [0, 0, 0, 0]
	
	var counts = [0, 0, 0, 0]
	for card in _card_runtime.cards:
		counts[card.suit] += 1
	return counts


## 开局由 RunScene 调用：启动 CardRuntime 新轮
func start_card_system() -> void:
	if _card_runtime != null:
		_card_runtime.start_new_run()
		print("[combat] card_system_started | hand_size=%d" % _card_runtime.get_hand_size())


## 供外部取 CardRuntime
func get_card_runtime():
	return _card_runtime
