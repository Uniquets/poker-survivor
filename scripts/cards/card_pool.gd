extends Node
## Autoload 单例：全局 52 张牌池与抽/还/消耗状态

## =============================================================================
## 全局卡牌池（Autoload：project.godot 中注册为 CardPool，路径 /root/CardPool）
##
## 规则：凡「从牌库取牌展示 / 选入玩家手牌 / 从手牌还回牌库」均应通过本单例，
## 不得在业务里随意 CardResource.new() 充当抽牌，以免与牌库张数、已抽状态不一致。
##
## 状态说明：
## - _available_cards：仍在牌库、可被抽到的牌（52 张为一副，可 reset 再洗）。
## - _drawn_cards：已从牌库抽出、尚未「正式消耗」的牌（例如 UI 展示 3 选 1 时，
##   三张都在此集合；未选中的会 return_card 回库；选中的 consume_card 表示入手）。
## =============================================================================

## 仍在牌库、可被抽到的 CardResource 列表
var _available_cards: Array = []
## 已抽出尚未 consume 的牌（展示选牌等阶段）
var _drawn_cards: Array = []


## 初始化：洗入一副牌
func _ready() -> void:
	_reset_pool()


## 与 CardRuntime / 选牌 UI 中伤害公式保持一致，便于组牌结算
func _apply_default_damage(card: CardResource) -> void:
	var base: int = card.get_rank_value() - 1
	if card.suit == 1:
		card.damage = base + 2
	else:
		card.damage = base


## 洗满一副牌并清空「已抽出」追踪
func _reset_pool() -> void:
	_available_cards.clear()
	_drawn_cards.clear()
	for suit in range(4):
		for rank in range(1, 14):
			var c := CardResource.new(suit, rank)
			_apply_default_damage(c)
			_available_cards.append(c)
	_available_cards.shuffle()
	print("[card_pool] pool reset | total=%d" % _available_cards.size())


## 从牌库随机抽一张：从 available 移除并记入 drawn（尚未决定是回库还是入手）
func draw_card() -> CardResource:
	if _available_cards.size() == 0:
		push_warning("[card_pool] 牌库空，重新洗牌")
		_reset_pool()
	if _available_cards.size() == 0:
		return null
	var idx: int = randi() % _available_cards.size()
	var card: CardResource = _available_cards[idx]
	_available_cards.remove_at(idx)
	_drawn_cards.append(card)
	print("[card_pool] drawn | %s | avail=%d" % [card.get_full_name(), _available_cards.size()])
	return card


## 连续抽多张（如选牌 UI 一次展示 3 张）；张数不足时抽到空为止
func draw_cards(count: int) -> Array:
	var out: Array = []
	for i in range(count):
		var c := draw_card()
		if c == null:
			break
		out.append(c)
	return out


## 正式消耗：牌已进入玩家构筑/手牌且不应再出现在 drawn 追踪里（不自动回 available）
func consume_card(card: CardResource) -> void:
	if card == null:
		return
	_drawn_cards.erase(card)


## 将牌还回牌库：若该引用仍在 drawn 中则先核销；再 duplicate 一份放入 available 并洗牌，
## 这样从手牌打出的实例（未必仍在 drawn）也能还库。
func return_card(card: CardResource) -> void:
	if card == null:
		return
	if card in _drawn_cards:
		_drawn_cards.erase(card)
	var back: CardResource = card.duplicate() as CardResource
	_available_cards.append(back)
	_available_cards.shuffle()
	print("[card_pool] returned | %s | avail=%d" % [card.get_full_name(), _available_cards.size()])


## 批量还牌入库
func return_cards(cards: Array) -> void:
	for c in cards:
		return_card(c)


## 当前牌库剩余张数
func get_available_count() -> int:
	return _available_cards.size()


## 当前处于「已抽未消耗」追踪中的张数
func get_drawn_count() -> int:
	return _drawn_cards.size()
