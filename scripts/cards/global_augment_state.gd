extends RefCounted
class_name GlobalAugmentState
## 局内全局强化状态：永久拾取加成 + 若干条可脚本化规则；由 `AutoAttackSystem` 持有，`build_snapshot` 在每次组牌解析前生成快照

const _RuleScript = preload("res://scripts/cards/global_augment_rule.gd")
const _SnapScript = preload("res://scripts/cards/play_augment_snapshot.gd")

## 是否注册示例花色规则（梅花手牌档位 + 本组 2 梅花）；正式流程可关，由数据/关卡驱动注册
const REGISTER_BUILTIN_SUIT_VOLLEY_EXAMPLES: bool = true

## 类型 1：即时选取类永久强化累计值 — 额外弹道枚数（与牌面基础相加）
var permanent_extra_volley_count: int = 0
## 类型 2：按规则列表逐项对当前 `PlayContext` 求和（与永久加成线性相加）
var _rules: Array = []
## 防止重复注册内置示例（例如误多次 `register_builtin`）
var _builtin_examples_registered: bool = false


func _init() -> void:
	if REGISTER_BUILTIN_SUIT_VOLLEY_EXAMPLES:
		register_builtin_example_suit_volley_rules()


## BOSS 奖励等调用：永久弹道 +1（可多次叠加）
func grant_permanent_volley_plus_one() -> void:
	permanent_extra_volley_count += 1


## 追加一条规则（拷贝引用，不 duplicate 规则对象）
func register_rule(rule) -> void:
	if rule != null:
		_rules.append(rule)


## 清空所有「规则型」强化（不影响永久拾取）；便于读档或切局；重置后可再次 `register_builtin_example_suit_volley_rules`
func clear_rules() -> void:
	_rules.clear()
	_builtin_examples_registered = false


## 注册文档示例：梅花手牌 4/8/12/16 → +1~+4；本组 ≥2 梅花 → 本步 +1
func register_builtin_example_suit_volley_rules() -> void:
	if _builtin_examples_registered:
		return
	_builtin_examples_registered = true
	var club: int = 3
	register_rule(
		_RuleScript.create_hand_suit_tier_volley(club, [4, 8, 12, 16], [1, 2, 3, 4])
	)
	register_rule(_RuleScript.create_play_group_suit_volley(club, 2, 1))


## 对当前出牌上下文汇总快照；**不**修改 `ctx` 内牌数据
func build_snapshot(ctx):
	var snap = _SnapScript.new()
	snap.volley_count_bonus += maxi(0, permanent_extra_volley_count)
	for item in _rules:
		var rule = item
		if rule == null:
			continue
		snap.volley_count_bonus += rule.get_extra_volley_count(ctx)
	snap.volley_count_bonus = maxi(0, snap.volley_count_bonus)
	return snap
