extends RefCounted
class_name EffectResolver
## 将一组牌与组类型、全局花色计数解析为最终伤害与表现用 EffectResult

## 一次结算的输出结构
class EffectResult:
	var damage: int = 0 ## 最终伤害数值
	var speed: float = 1.0 ## 速度系数
	var hit_count: int = 1 ## 打击次数
	var is_critical: bool = false ## 是否视为暴击
	var group_bonus: float = 1.0 ## 组牌类型乘区
	var suit_bonus: float = 1.0 ## 同花等乘区（当前与 flush 逻辑共用）
	var effects: Array = [] ## 人类可读效果标签列表
	var knockback: float = 0.0 ## 击退距离（占位）
	var heal_amount: int = 0 ## 治疗量（占位）


## 入口：依次叠基础伤害、组牌、本地花色、全局花色
func resolve_effects(cards: Array, group_type: GameRules.GroupType, global_suit_counts: Array) -> EffectResult:
	var result = EffectResult.new()
	
	_calculate_base_damage(cards, result)
	_apply_group_bonus(cards, group_type, result)
	_apply_suit_effect(cards, result)
	_apply_global_suit_bonus(global_suit_counts, result)
	
	return result


## 组内各牌 damage 求和写入 result
func _calculate_base_damage(cards: Array, result: EffectResult) -> void:
	var total: int = 0
	for card in cards:
		total += card.damage
	result.damage = total
	result.effects.append("base_damage:%d" % total)


## 按组类型应用乘区与命中次数等（`GameRules.GroupType`，与检测器字符串经 `group_type_from_detector_string` 对齐）
func _apply_group_bonus(cards: Array, group_type: GameRules.GroupType, result: EffectResult) -> void:
	# 引用玩法分组类型枚举，保证与核心规则一致
	match group_type:
		GameRules.GroupType.NONE, GameRules.GroupType.SINGLE:
			result.group_bonus = 1.0

		GameRules.GroupType.PAIR:
			# 牌型为对子：增加组牌倍数与命中数，并标记效果
			result.group_bonus = 1.5
			result.hit_count = 2
			result.effects.append("pair_bonus")

		GameRules.GroupType.THREE_OF_A_KIND:
			# 牌型为三条：增加组牌倍数与命中数，并标记效果
			result.group_bonus = 2.5
			result.hit_count = 3
			result.effects.append("three_bonus")

		GameRules.GroupType.FOUR_OF_A_KIND:
			# 牌型为四条：高倍数、增加暴击与击退
			result.group_bonus = 4.0
			result.hit_count = 4
			result.is_critical = true
			result.knockback = 15.0
			result.effects.append("four_bonus")

		GameRules.GroupType.STRAIGHT:
			# 牌型为顺子：根据长度递增组牌倍数与速度
			var card_count = len(cards)
			result.group_bonus = 1.2 + (card_count - 3) * 0.3
			result.speed = 1.5 + (card_count - 3) * 0.1
			result.effects.append("straight_bonus")

		GameRules.GroupType.CONSECUTIVE_PAIRS:
			# 连对：计算连对数量影响倍数与命中
			var pair_count = float(len(cards)) / 2.0
			result.group_bonus = 1.3 + (pair_count - 2) * 0.4
			result.hit_count = int(pair_count)
			result.effects.append("consecutive_pairs_bonus")

		GameRules.GroupType.CONSECUTIVE_TRIPS:
			# 连三张：计算组数影响倍数、命中和暴击
			var trip_count = float(len(cards)) / 3.0
			result.group_bonus = 2.0 + (trip_count - 2) * 0.8
			result.hit_count = int(trip_count) * 2
			result.is_critical = true
			result.knockback = 10.0
			result.effects.append("consecutive_trips_bonus")

		_:
			result.group_bonus = 1.0

	result.damage = int(float(result.damage) * result.group_bonus)


## 当前打出组内花色多数效果（含同花翻倍）
func _apply_suit_effect(cards: Array, result: EffectResult) -> void:
	# 若组牌数量不足 2，则无花色多数，无需处理，直接返回
	if cards.size() < 2:
		return
	
	# 各花色计数数组，依次为 [黑桃, 红心, 方块, 梅花]
	var suit_counts: Array = [0, 0, 0, 0]
	for card in cards:
		# 累加每张牌的花色计数
		suit_counts[card.suit] += 1
	
	# 改为：只要某花色出现超过 2 张，就都激活并分别应用其效果（允许多花色并行处理），同花判断也一并支持
	var flush_suit: int = -1
	for suit in range(4):
		var count: int = suit_counts[suit]
		if count > 2:
			# 应用每个达标花色的效果
			_apply_specific_suit_effect(suit, count, cards.size(), result)
			# 检查是否同花色
			if count == cards.size():
				flush_suit = suit

	# 若存在同花，则翻倍
	if flush_suit != -1:
		result.suit_bonus *= 2.0
		result.effects.append("flush_bonus")


## 黑桃/红心/方块/梅花本地加成细则
func _apply_specific_suit_effect(suit: int, count: int, _total: int, result: EffectResult) -> void:
	# 计算加成倍率：基础 1.0，每多 1 张（超出首张）+0.2；即 2 张 1.2，3 张 1.4，依此类推
	var multiplier: float = 1.0 + (count - 1) * 0.2
	
	match suit:
		0:
			# 黑桃：提升伤害，乘以倍率，并记录黑桃加成效果
			result.damage = int(float(result.damage) * multiplier)
			result.effects.append("spades_bonus")
		1:
			# 红心：提升伤害，乘以倍率，若 3 张及以上则暴击，记录红心加成效果
			result.damage = int(float(result.damage) * multiplier)
			result.is_critical = result.is_critical || (count >= 3)
			result.effects.append("hearts_bonus")
		2:
			# 方块：提升连击次数，每多 1 张+1，记录方块加成效果
			result.hit_count += count - 1
			result.effects.append("diamonds_bonus")
		3:
			# 梅花：提升速度，每多 1 张 +0.15，额外每张回血 5，记录梅花加成效果
			result.speed *= (1.0 + (count - 1) * 0.15)
			result.heal_amount += count * 5
			result.effects.append("clubs_bonus")


## 全局花色张数阈值档（3/6/9/12）加成
func _apply_global_suit_bonus(global_suit_counts: Array, result: EffectResult) -> void:
	# 遍历 4 种花色（0:黑桃, 1:红心, 2:方块, 3:梅花）
	for suit in range(4):
		# 获取当前花色的累计张数
		var count: int = global_suit_counts[suit]
		# 只有累计达到 3 张及以上才能获得加成
		if count >= 3:
			# 默认档位加成为 0.1，对应 3 张
			var bonus: float = 0.1
			# 6 张及以上提升为 0.2
			if count >= 6:
				bonus = 0.2
			# 9 张及以上提升为 0.3
			if count >= 9:
				bonus = 0.3
			# 12 张及以上提升为 0.4
			if count >= 12:
				bonus = 0.4
			# 根据花色类型分别应用不同字段的加成
			match suit:
				0:
					# 黑桃/红心：提升伤害
					result.damage = int(float(result.damage) * (1.0 + bonus))
				1:
					# 黑桃/红心：提升伤害
					result.damage = int(float(result.damage) * (1.0 + bonus))
				2:
					# 方块：提升连击次数
					result.hit_count = int(float(result.hit_count) * (1.0 + bonus))
				3:
					# 梅花：提升速度
					result.speed *= (1.0 + bonus)



## 将 EffectResult 压缩为简短中文描述
func get_effect_description(result: EffectResult) -> String:
	var parts: Array = []
	if result.is_critical:
		parts.append("暴击")
	if result.hit_count > 1:
		parts.append("多重打击 x%d" % result.hit_count)
	if result.speed > 1.0:
		parts.append("快速")
	if result.group_bonus > 1.0:
		parts.append("组牌加成")
	if result.suit_bonus > 1.0:
		parts.append("同花加成")
	if result.knockback > 0:
		parts.append("击退")
	if result.heal_amount > 0:
		parts.append("生命恢复 +%d" % result.heal_amount)
	
	if parts.size() == 0:
		return "普通攻击"
	return ", ".join(parts)


## 控制台打印结算结果
func debug_print(result: EffectResult) -> void:
	print("[effects] damage=%d hit_count=%d speed=%.2f critical=%s knockback=%.1f heal=%d effects=%s" %
		[result.damage, result.hit_count, result.speed, str(result.is_critical), result.knockback, result.heal_amount, str(result.effects)])
