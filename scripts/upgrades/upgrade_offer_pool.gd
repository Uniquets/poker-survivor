extends Resource
class_name UpgradeOfferPool
## 三选一奖励池：从配置的强化效果里按权重抽取不重复选项。

## 候选强化效果数组，元素应继承 UpgradeEffect。
@export var effects: Array = []


## 按权重抽取 count 个不重复强化效果。
func roll_offer(count: int = 3) -> Array:
	var source: Array = _valid_effects()
	var result: Array = []
	while result.size() < count and not source.is_empty():
		var picked: Resource = _pick_weighted(source)
		if picked == null:
			break
		result.append(picked)
		source.erase(picked)
	return result


## 收集当前可用的强化效果。
func _valid_effects() -> Array:
	var valid: Array = []
	for raw in effects:
		var effect: Resource = raw as Resource
		if effect == null:
			continue
		if effect.has_method("is_valid_effect") and bool(effect.call("is_valid_effect")):
			valid.append(effect)
	return valid


## 从候选数组中按权重抽一个效果。
func _pick_weighted(valid: Array) -> Resource:
	var total: float = 0.0
	for raw in valid:
		var effect: Resource = raw as Resource
		if effect != null:
			total += maxf(0.0, float(effect.get("weight")))
	if total <= 0.0:
		return null
	var roll: float = randf() * total
	for raw in valid:
		var effect: Resource = raw as Resource
		if effect == null:
			continue
		roll -= maxf(0.0, float(effect.get("weight")))
		if roll <= 0.0:
			return effect
	return valid.back() as Resource
