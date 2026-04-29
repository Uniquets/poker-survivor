extends Node
class_name AutoAttackSystem
## 监听 CardRuntime.group_played，解析组牌效果并经 CombatEffectRunner 执行（表现资源由 Runner 侧持有）

const _PlayContextScript = preload("res://scripts/cards/play_context.gd")
const _PlayEffectResolverScript = preload("res://scripts/cards/play_effect_resolver.gd")
const _PlayShapeTableResolverScript = preload("res://scripts/cards/play_shape_table_resolver.gd")
const _CombatEffectRunnerScript = preload("res://scripts/combat/combat_effect_runner.gd")
const _CmdScript = preload("res://scripts/cards/play_effect_command.gd")
const _GlobalAugmentStateScript = preload("res://scripts/cards/global_augment_state.gd")
const _CombatPlayerScript: Variant = preload("res://scripts/combat/player.gd")
const _EnemyManagerScript: Variant = preload("res://scripts/combat/enemy_manager.gd")

## 父场景 CardRuntime（可为 null）
var _card_runtime = null
## 解析为 PlayPlan（管线 + 命令列表）
var _play_resolver = null
## **`GameConfig.GAME_GLOBAL.use_shape_table_effect_pipeline`** 为真时使用
var _shape_table_resolver = null
## 执行 PlayPlan（逻辑相 / 表现相）
var _combat_effect_runner = null
## 局内全局强化（永久拾取 + 规则表）；BOSS 奖励等经 `grant_permanent_volley_plus_one` 写入
var augment_state = null

## 单张牌名参与攻击时（预留）
signal card_attacked(card_name: String, damage: int)
## 一组牌结算后发出总伤害等信息
signal group_attacked(group_type: String, total_damage: int)


## 取得 Autoload **`GlobalAudioManager`**；未注册时返回 null
func _global_audio_service() -> Node:
	return get_tree().root.get_node_or_null("GlobalAudioManager") as Node


## 加载解析器与效果执行器，并尝试绑定 CardRuntime
func _ready() -> void:
	_play_resolver = _PlayEffectResolverScript.new()
	_shape_table_resolver = _PlayShapeTableResolverScript.new()
	_combat_effect_runner = _CombatEffectRunnerScript.new()
	augment_state = _GlobalAugmentStateScript.new()
	_find_card_runtime()


## 从父节点取 CardRuntime 并连接 group_played
func _find_card_runtime() -> void:
	var parent_node := get_parent()
	if parent_node != null and parent_node.has_node("CardRuntime"):
		_card_runtime = parent_node.get_node("CardRuntime")
		if _card_runtime != null:
			_card_runtime.group_played.connect(_on_group_played)


## 组牌打出：解析效果并对目标多次生成弹道
func _on_group_played(cards, group_type) -> void:
	# 播放组牌音效
	var ga: Node = _global_audio_service()
	if ga != null and ga.has_method("play_card_group_played"):
		ga.play_card_group_played()
	
	# 获取父节点（一般为当前场景主控节点）
	var parent_node := get_parent()
	
	# 获取战斗玩家和敌人管理器（全局单例）
	var player: CombatPlayer = _CombatPlayerScript.get_combat_player() as CombatPlayer
	var enemy_manager: EnemyManager = _EnemyManagerScript.get_enemy_manager() as EnemyManager
	
	# 若核心对象未有效注册，直接退出
	if not is_instance_valid(player) or not is_instance_valid(enemy_manager):
		return 
	
	# 统计当前所有手牌的花色数量
	var global_suit_counts: Array = _calculate_global_suit_counts()
	
	# 构造效果解析上下文 PlayContext（传入当前牌组、花色、玩家数据等）
	var ctx = _PlayContextScript.new()
	ctx.cards = cards
	# group_type: 由字符串转 Enum，方便后续解析与规则处理
	ctx.group_type = group_type
	ctx.global_suit_counts = global_suit_counts
	ctx.player_max_health = player.get_effective_max_health()
	ctx.player_attack_damage_coefficient = player.attack_damage_coefficient
	# 拍个快照，避免计算过程被意外修改
	ctx.player_stats = player.combat_stats.duplicate_snapshot() if player.combat_stats != null else null
	# 汇总本轮局内强化快照（来自永久增益、花色等），供解析器查询弹道数量等
	if augment_state != null:
		ctx.augment_snapshot = augment_state.build_snapshot(ctx)
	else:
		ctx.augment_snapshot = null

	# 解析此次出牌，优先用 shape_table_resolver，否则默认走 play_resolver
	var plan: Variant = _shape_table_resolver.try_resolve(ctx)
	if plan == null:
		plan = _play_resolver.resolve(ctx)
	
	# 调试输出当前 PlayPlan 内容
	_debug_print_play_plan(plan)
	
	# 执行解析好的 PlayPlan，传递父节点关联信息
	var world: Dictionary = {"parent": parent_node}
	_combat_effect_runner.execute(plan, world)
	
	# 广播组牌结算信号（总伤害数等），用于更新UI和音效
	emit_signal("group_attacked", group_type, plan.estimated_enemy_damage)
	
	# 汇总所有卡牌的牌名，用于单牌伤害信号
	var card_names: Array = []
	for card in cards:
		card_names.append(card.get_full_name())
	# 若命令为空，则本轮伤害为0，否则取估算值
	var dmg_hint: int = plan.estimated_enemy_damage
	if plan.commands.is_empty():
		dmg_hint = 0
	# 发射单张牌伤害信号（卡牌名合并，便于日志和动画）
	emit_signal("card_attacked", ", ".join(card_names), dmg_hint)


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


## BOSS 三选一等即时永久强化：全局弹道枚数 +1（整局累加）
func grant_permanent_volley_plus_one() -> void:
	if augment_state != null:
		augment_state.grant_permanent_volley_plus_one()


## 调试：打印 PlayPlan 内命令种类与关键字段
func _debug_print_play_plan(plan) -> void:
	if plan == null:
		return
	print("[effects] play_plan | tags=%s est_dmg=%d cmds=%d" % [str(plan.debug_tags), plan.estimated_enemy_damage, plan.commands.size()])
	for i in range(plan.commands.size()):
		var c = plan.commands[i]
		if c == null or c.get_script() != _CmdScript:
			continue
		var cmd = c
		print("  [%d] kind=%s phase=%s dmg=%d cnt=%d" % [i, str(cmd.kind), cmd.phase, cmd.damage, cmd.count])
