extends RefCounted
class_name PlayShapeMatcher
## 牌型表 **匹配**：从 `PlayContext` 生成牌型 key，再由 `PlayShapeCatalog.shape_dic[key]` 取条目。


## 若 **`cards`** 均为同一 **`CardResource.rank`** 则返回该 **rank**（1～13）；否则 **-1**
static func uniform_card_rank(cards: Array) -> int:
	var r0: int = -1
	for c in cards:
		if not c is CardResource:
			return -1
		var cr: CardResource = c
		if r0 < 0:
			r0 = cr.rank
		elif cr.rank != r0:
			return -1
	return r0


## 牌型模板字母序列（不足 26 的玩法规模够用）
const _TEMPLATE_ALPHABET: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
## 并行弹道默认 key
const KEY_DEFAULT: String = "DEFAULT"


## 从 rank 计数字典提取并排序后的 rank 列表（升序）
static func _sorted_ranks_from_counts(rank_counts: Dictionary) -> Array:
	var ranks: Array = rank_counts.keys()
	ranks.sort()
	return ranks


## 判断已排序 rank 是否连续；允许 Q-K-A（12,13,1）
static func _is_consecutive_ranks(sorted_ranks: Array) -> bool:
	if sorted_ranks.size() <= 1:
		return true
	var normal_ok: bool = true
	for i in range(1, sorted_ranks.size()):
		if int(sorted_ranks[i]) - int(sorted_ranks[i - 1]) != 1:
			normal_ok = false
			break
	if normal_ok:
		return true
	## 中文：Q-K-A 特判：顺子顶端允许 A
	return sorted_ranks == [1, 12, 13]


## 构造模板 key（如 n=3,m=2 => AABBCC；n=2,m=3 => AAABBB）
static func _build_template_key(group_count: int, same_rank_count: int) -> String:
	if group_count <= 0 or same_rank_count <= 0:
		return ""
	var key: String = ""
	for i in range(group_count):
		if i >= _TEMPLATE_ALPHABET.length():
			return ""
		var token: String = _TEMPLATE_ALPHABET.substr(i, 1)
		for _j in range(same_rank_count):
			key += token
	return key


## 基于 `PlayContext` 生成牌型 key；失败返回空字符串
static func build_shape_key(ctx) -> String:
	if ctx == null or ctx.cards.is_empty():
		return ""
	var rank_counts: Dictionary = {}
	for c in ctx.cards:
		if not c is CardResource:
			return ""
		var rank: int = int((c as CardResource).rank)
		rank_counts[rank] = int(rank_counts.get(rank, 0)) + 1

	## 中文：同点数组（单张/对子/三条/四条）统一编码成重复点数字符串，如 2/22/222/2222
	var ur: int = uniform_card_rank(ctx.cards)
	if ur > 0:
		var token: String = str(ur)
		var same_key: String = ""
		for _i in range(ctx.cards.size()):
			same_key += token
		return same_key

	var sorted_ranks: Array = _sorted_ranks_from_counts(rank_counts)
	if not _is_consecutive_ranks(sorted_ranks):
		return ""

	## 中文：顺子按 ABCD… 编码；连对按 AABBCC…；连三按 AAABBB…
	match int(ctx.group_type):
		GameRules.GroupType.STRAIGHT:
			if rank_counts.size() != ctx.cards.size():
				return ""
			return _build_template_key(ctx.cards.size(), 1)
		GameRules.GroupType.CONSECUTIVE_PAIRS:
			for rc in rank_counts.values():
				if int(rc) != 2:
					return ""
			return _build_template_key(rank_counts.size(), 2)
		GameRules.GroupType.CONSECUTIVE_TRIPS:
			for rc in rank_counts.values():
				if int(rc) != 3:
					return ""
			return _build_template_key(rank_counts.size(), 3)
		_:
			return ""
