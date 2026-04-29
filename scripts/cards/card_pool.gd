extends Node
## 策划表访问（见 `enemy.gd` 说明）

## Autoload 单例：全局 52 张牌池与抽/还/消耗状态
## 牌面与抽卡概率资源经 `GameConfig.GAME_GLOBAL` 读取

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


## 取得 Autoload **`GlobalAudioManager`**；未注册时返回 null
func _global_audio_service() -> Node:
	return get_node_or_null("/root/GlobalAudioManager") as Node


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


## 按 `CardDrawProbabilityConfig` 分档与 `CardFaceConfig` 四张贴图，写入 `card.front_texture`（无配置则跳过）
func _apply_card_front_texture(card: CardResource) -> void:
	var gg = GameConfig.GAME_GLOBAL
	if gg == null:
		return
	var face_res: CardFaceConfig = gg.card_face_config
	if face_res == null:
		return
	var draw_cfg = _get_card_draw_probability_config()
	var tier: int = 0
	if draw_cfg != null:
		tier = draw_cfg.get_rarity_tier_for_card(card)
	var tex: Texture2D = face_res.get_texture_for_rarity_tier(tier)
	if tex != null:
		card.front_texture = tex


## 洗满一副牌并清空「已抽出」追踪
func _reset_pool() -> void:
	_available_cards.clear()
	_drawn_cards.clear()
	for suit in range(4):
		for rank in range(1, 14):
			var c := CardResource.new(suit, rank)
			_apply_default_damage(c)
			_apply_card_front_texture(c)
			_available_cards.append(c)
	_available_cards.shuffle()
	print("[card_pool] pool reset | total=%d" % _available_cards.size())
	var ga: Node = _global_audio_service()
	if ga != null and ga.has_method("play_deck_reshuffle"):
		ga.play_deck_reshuffle()


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


## 从配置读取「等级段×稀有度×幸运」权重，在 `_available_cards` 中按稀有度档抽样；用于开局/升级/测试加牌三选一
## `player_level`：当前战斗等级；`luck`：`PlayerCombatStats.luck`，提高高档权重、压低低档（见 `CardDrawProbabilityConfig`）
func draw_cards_for_weighted_offer(count: int, player_level: int, luck: float) -> Array:
	var cfg = _get_card_draw_probability_config()
	if cfg == null:
		return draw_cards(count)
	var out: Array = []
	for _i in range(count):
		if _available_cards.size() == 0:
			push_warning("[card_pool] 牌库空，重新洗牌（加权抽）")
			_reset_pool()
		if _available_cards.size() == 0:
			break
		var c: CardResource = _draw_one_card_for_weighted_offer(cfg, player_level, luck)
		if c == null:
			break
		out.append(c)
	return out


## 返回全局配置中的抽卡概率资源；未配置时返回 null，由调用方回退均匀 `draw_cards`
func _get_card_draw_probability_config():
	var gg = GameConfig.GAME_GLOBAL
	if gg == null:
		return null
	return gg.card_draw_probability


## 单次：先按权重随机稀有度档，再在可用牌中筛 rank 所属档；该档无牌时回退为均匀 `draw_card`
func _draw_one_card_for_weighted_offer(cfg, player_level: int, luck: float) -> CardResource:
	var weights: PackedFloat32Array = cfg.get_adjusted_rarity_weights(player_level, luck)
	var tier: int = cfg.roll_rarity_index(weights)
	var idx: int = _pick_available_index_for_rarity_tier(cfg, tier)
	if idx < 0:
		return draw_card()
	var card: CardResource = _available_cards[idx]
	_available_cards.remove_at(idx)
	_drawn_cards.append(card)
	print("[card_pool] drawn_weighted | %s | tier=%d | avail=%d" % [card.get_full_name(), tier, _available_cards.size()])
	return card


## 在 `_available_cards` 中随机选一张满足稀有度档的牌的下标；无则返回 -1
func _pick_available_index_for_rarity_tier(cfg, tier: int) -> int:
	var candidates: Array = []
	for i in range(_available_cards.size()):
		var c: CardResource = _available_cards[i]
		if cfg.get_rarity_tier_for_card(c) == tier:
			candidates.append(i)
	if candidates.is_empty():
		return -1
	return candidates[randi() % candidates.size()]


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
	var ga: Node = _global_audio_service()
	if ga != null and ga.has_method("play_deck_reshuffle"):
		ga.play_deck_reshuffle()


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


## 测试用：新建一张牌（**不从**牌库 `_available_cards` 抽取，也不记入 `_drawn_cards`），伤害规则与 `_apply_default_damage` 一致，供自选花点直接入手
func create_standalone_test_card(suit: int, rank: int) -> CardResource:
	var su: int = clampi(suit, 0, 3)
	var rk: int = clampi(rank, 1, 13)
	var c := CardResource.new(su, rk)
	_apply_default_damage(c)
	_apply_card_front_texture(c)
	return c
