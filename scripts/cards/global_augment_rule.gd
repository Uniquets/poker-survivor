extends RefCounted
class_name GlobalAugmentRule
## 全局强化规则：对单次 `PlayContext` 产出弹道枚数等可加成分；后续新强化可增 `ApplicationKind` 分支或拆资源驱动

## 规则应用方式（同文件内分支，避免多 `class_name` 脚本）
enum ApplicationKind {
	HAND_SUIT_HIGHEST_TIER, ## 当前手牌某花色达档位取最高档弹道 +N
	PLAY_GROUP_SUIT_COUNT, ## 本次打出的一组牌内某花色张数达标则本步弹道 +N
}

## 本规则如何生效
var application: ApplicationKind = ApplicationKind.HAND_SUIT_HIGHEST_TIER
## 花色 `CardResource.suit`：0 黑桃、1 红心、2 方块、3 梅花
var suit_index: int = 3
## 升序阈值（仅 `HAND_SUIT_HIGHEST_TIER`），与 `tier_volley_bonuses` 等长
var tier_thresholds: Array = []
## 与阈值一一对应的弹道加成；取**已达成的最高档**一档，不累加低档
var tier_volley_bonuses: Array = []
## 本组牌内至少几张该花色（仅 `PLAY_GROUP_SUIT_COUNT`）
var min_cards_in_play_group: int = 2
## 达标时弹道加成（仅 `PLAY_GROUP_SUIT_COUNT`）
var play_group_volley_bonus: int = 1


## 工厂：手牌花色档位（示例 4/8/12/16 梅花 → +1/+2/+3/+4）
static func create_hand_suit_tier_volley(p_suit: int, p_thresholds: Array, p_bonuses: Array) -> GlobalAugmentRule:
	var r := GlobalAugmentRule.new()
	r.application = ApplicationKind.HAND_SUIT_HIGHEST_TIER
	r.suit_index = clampi(p_suit, 0, 3)
	r.tier_thresholds = p_thresholds.duplicate()
	r.tier_volley_bonuses = p_bonuses.duplicate()
	return r


## 工厂：本组打出牌中含足够张某花色则本步弹道 +N（示例：2 张梅花 → +1）
static func create_play_group_suit_volley(p_suit: int, p_min_in_group: int, p_bonus: int) -> GlobalAugmentRule:
	var r := GlobalAugmentRule.new()
	r.application = ApplicationKind.PLAY_GROUP_SUIT_COUNT
	r.suit_index = clampi(p_suit, 0, 3)
	r.min_cards_in_play_group = maxi(1, p_min_in_group)
	r.play_group_volley_bonus = maxi(0, p_bonus)
	return r


## 本规则对弹道枚数的额外贡献（非负）
func get_extra_volley_count(ctx) -> int:
	match application:
		ApplicationKind.HAND_SUIT_HIGHEST_TIER:
			return _eval_hand_tiers(ctx)
		ApplicationKind.PLAY_GROUP_SUIT_COUNT:
			return _eval_play_group(ctx)
		_:
			return 0


## 手牌档位：从高档向低档扫，取第一个满足的档位加成
func _eval_hand_tiers(ctx) -> int:
	if tier_thresholds.is_empty() or tier_thresholds.size() != tier_volley_bonuses.size():
		return 0
	var n: int = 0
	if ctx != null and ctx.global_suit_counts is Array and suit_index < ctx.global_suit_counts.size():
		n = int(ctx.global_suit_counts[suit_index])
	for i in range(tier_thresholds.size() - 1, -1, -1):
		if n >= int(tier_thresholds[i]):
			return maxi(0, int(tier_volley_bonuses[i]))
	return 0


## 本组牌：统计打出序列中指定花色张数
func _eval_play_group(ctx) -> int:
	if ctx == null or ctx.cards.is_empty():
		return 0
	var c: int = 0
	for card in ctx.cards:
		if card is CardResource and (card as CardResource).suit == suit_index:
			c += 1
	if c >= min_cards_in_play_group:
		return play_group_volley_bonus
	return 0
