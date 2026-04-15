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
func resolve_effects(cards: Array, group_type: String, global_suit_counts: Array) -> EffectResult:
	var result = EffectResult.new()
	
	_calculate_base_damage(cards, result)
	_apply_group_bonus(cards, group_type, result)
	_apply_suit_effect(cards, group_type, result)
	_apply_global_suit_bonus(global_suit_counts, result)
	
	return result


## 组内各牌 damage 求和写入 result
func _calculate_base_damage(cards: Array, result: EffectResult) -> void:
	var total: int = 0
	for card in cards:
		total += card.damage
	result.damage = total
	result.effects.append("base_damage:%d" % total)


## 按组类型字符串应用乘区与命中次数等
func _apply_group_bonus(cards: Array, group_type: String, result: EffectResult) -> void:
	match group_type:
		"SINGLE":
			result.group_bonus = 1.0
		"PAIR":
			result.group_bonus = 1.5
			result.hit_count = 2
			result.effects.append("pair_bonus")
		"THREE_OF_A_KIND":
			result.group_bonus = 2.5
			result.hit_count = 3
			result.effects.append("three_bonus")
		"FOUR_OF_A_KIND":
			result.group_bonus = 4.0
			result.hit_count = 4
			result.is_critical = true
			result.knockback = 15.0
			result.effects.append("four_bonus")
		"STRAIGHT":
			var card_count = len(cards)
			result.group_bonus = 1.2 + (card_count - 3) * 0.3
			result.speed = 1.5 + (card_count - 3) * 0.1
			result.effects.append("straight_bonus")
		"CONSECUTIVE_PAIRS":
			var pair_count = float(len(cards)) / 2.0
			result.group_bonus = 1.3 + (pair_count - 2) * 0.4
			result.hit_count = int(pair_count)
			result.effects.append("consecutive_pairs_bonus")
		"CONSECUTIVE_TRIPS":
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
func _apply_suit_effect(cards: Array, _group_type: String, result: EffectResult) -> void:
	if cards.size() < 2:
		return
	
	var suit_counts: Array = [0, 0, 0, 0]
	for card in cards:
		suit_counts[card.suit] += 1
	
	var max_count: int = 0
	for c in suit_counts:
		max_count = max(max_count, c)
	var has_dominant_suit: bool = max_count >= 2
	
	if has_dominant_suit:
		var dominant_suit: int = suit_counts.find(max_count)
		_apply_specific_suit_effect(dominant_suit, max_count, cards.size(), result)
		
		var is_flush: bool = max_count == cards.size()
		if is_flush:
			result.suit_bonus *= 2.0
			result.effects.append("flush_bonus")


## 黑桃/红心/方块/梅花本地加成细则
func _apply_specific_suit_effect(suit: int, count: int, _total: int, result: EffectResult) -> void:
	var multiplier: float = 1.0 + (count - 1) * 0.2
	
	match suit:
		0:
			result.damage = int(float(result.damage) * multiplier)
			result.effects.append("spades_bonus")
		1:
			result.damage = int(float(result.damage) * multiplier)
			result.is_critical = result.is_critical || (count >= 3)
			result.effects.append("hearts_bonus")
		2:
			result.hit_count += count - 1
			result.effects.append("diamonds_bonus")
		3:
			result.speed *= (1.0 + (count - 1) * 0.15)
			result.heal_amount += count * 5
			result.effects.append("clubs_bonus")


## 全局花色张数阈值档（3/6/9/12）加成
func _apply_global_suit_bonus(global_suit_counts: Array, result: EffectResult) -> void:
	for suit in range(4):
		var count: int = global_suit_counts[suit]
		if count >= 3:
			var bonus: float = 0.1
			if count >= 6:
				bonus = 0.2
			if count >= 9:
				bonus = 0.3
			if count >= 12:
				bonus = 0.4
			
			match suit:
				0:
					result.damage = int(float(result.damage) * (1.0 + bonus))
				1:
					result.damage = int(float(result.damage) * (1.0 + bonus))
				2:
					result.hit_count = int(float(result.hit_count) * (1.0 + bonus))
				3:
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
