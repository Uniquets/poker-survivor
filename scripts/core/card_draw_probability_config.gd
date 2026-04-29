extends Resource
class_name CardDrawProbabilityConfig
## 抽卡展示用：点数→四档稀有度、按玩家等级段的基础概率表（合计 100%）、幸运对权重的指数倾斜
## 由 `GameGlobalConfig.card_draw_probability` 引用；具体抽牌在 `CardPool.draw_cards_for_weighted_offer`

## 每个等级段包含的等级数（如 10 表示 Lv1～10 为第 0 段）
@export var levels_per_segment: int = 10

## 四档稀有度在**比较强度**上的闭区间上界，强度与 `CardResource.get_rank_value()` 一致：**2 最小、A 最大（14）**
## 即 13 个点数从 2→3→…→K→A 单调递增；`rarity_tier_max_strength[i]` 为第 i 档允许的最大强度（含）
## 默认 5,8,11,14 → 档0：2～5；档1：6～8；档2：9～J；档3：Q、K、A
@export var rarity_tier_max_strength: PackedInt32Array = PackedInt32Array([5, 8, 11, 14])

## 每等级段一行：x/y/z/w 分别为稀有度 0～3 的**基础出现百分比**（策划填 0～100，四项之和应为 100）
## 行数不足时最后一行用于更高等级；等级段下标 = floor((level-1)/levels_per_segment)，再 clamp 到行数-1
@export var segment_base_rarity_percent: Array[Vector4] = [
	Vector4(45.0, 30.0, 20.0, 5.0),
	Vector4(40.0, 32.0, 22.0, 6.0),
	Vector4(35.0, 33.0, 24.0, 8.0),
	Vector4(30.0, 34.0, 26.0, 10.0),
	Vector4(25.0, 33.0, 28.0, 14.0),
]

## 幸运参与权重：`adjusted[i] ∝ base[i] * exp(luck * luck_per_tier_index * i)`，再归一化；luck=0 时与基础比例一致
@export var luck_per_tier_index: float = 0.06
## 参与公式前对幸运做夹取下界，避免极端数值导致某一档趋近 0
@export var luck_clamp_min: float = -5.0
## 参与公式前对幸运做夹取上界
@export var luck_clamp_max: float = 50.0


## 校验 `rarity_tier_max_strength` 与概率表行数；异常时打警告但不中断运行
func _validate_configuration() -> void:
	if rarity_tier_max_strength.size() != 4:
		push_warning("[CardDrawProbabilityConfig] rarity_tier_max_strength 须为 4 个整数")
		return
	for i in range(1, 4):
		if rarity_tier_max_strength[i] <= rarity_tier_max_strength[i - 1]:
			push_warning("[CardDrawProbabilityConfig] rarity_tier_max_strength 须严格递增")
			return
	if rarity_tier_max_strength[0] < 2:
		push_warning("[CardDrawProbabilityConfig] 首档上界应 ≥2（最小点数为 2）")
	if rarity_tier_max_strength[3] != 14:
		push_warning("[CardDrawProbabilityConfig] 末档上界应为 14（A 的最大强度）")
	if segment_base_rarity_percent.is_empty():
		push_warning("[CardDrawProbabilityConfig] segment_base_rarity_percent 为空")


## 将 `get_rank_value()`（2～14，A=14）映射到稀有度 0～3；与牌面存储 rank（1=A…13=K）无关
func get_rarity_tier_for_strength(strength: int) -> int:
	var s: int = clampi(strength, 2, 14)
	for i in range(4):
		if s <= rarity_tier_max_strength[i]:
			return i
	return 3


## 对单张牌使用 `get_rank_value()` 分档（供 `CardPool` 筛选）
func get_rarity_tier_for_card(card: CardResource) -> int:
	if card == null:
		return 0
	return get_rarity_tier_for_strength(card.get_rank_value())


## 玩家等级对应的概率表行下标（从 0 起）
func get_segment_index_for_level(level: int) -> int:
	var lv: int = maxi(1, level)
	var seg: int = int(floor(float(lv - 1) / float(maxi(1, levels_per_segment))))
	var rows: int = segment_base_rarity_percent.size()
	if rows <= 0:
		return 0
	return clampi(seg, 0, rows - 1)


## 读取某等级段的基础四维百分比（不保证精确和为 100，后续会归一）
func get_base_rarity_percent_row(level: int) -> Vector4:
	var idx: int = get_segment_index_for_level(level)
	if segment_base_rarity_percent.is_empty():
		return Vector4(25.0, 25.0, 25.0, 25.0)
	return segment_base_rarity_percent[idx]


## 幸运修正后的四维权重，**和为 1**；用于一次随机档位抽取
func get_adjusted_rarity_weights(level: int, luck: float) -> PackedFloat32Array:
	var base: Vector4 = get_base_rarity_percent_row(level)
	var lk: float = clampf(luck, luck_clamp_min, luck_clamp_max)
	var w: Array = [0.0, 0.0, 0.0, 0.0]
	var sum: float = 0.0
	for i in range(4):
		var b: float = maxf(0.0, float(base[i]))
		var mul: float = exp(lk * luck_per_tier_index * float(i))
		w[i] = b * mul
		sum += w[i]
	if sum <= 0.0:
		return PackedFloat32Array([0.25, 0.25, 0.25, 0.25])
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(4)
	for j in range(4):
		out[j] = w[j] / sum
	return out


## 按四维权重随机一档 0～3（均匀随机 roll）
func roll_rarity_index(weights: PackedFloat32Array) -> int:
	var r: float = randf()
	var acc: float = 0.0
	for i in range(4):
		acc += weights[i]
		if r <= acc:
			return i
	return 3
