extends Node
class_name PickupCollector
## 玩家子节点：每物理帧扫描 **`battle_pickups`** 组，在磁力半径内牵引 **`BattlePickup`**，进收集距离则执行其效果 **`Resource.apply`** 并销毁拾取物。


## 与 **`PickupEffectConfig`** 同脚本，用于 **`get_script()`** 校验
const _PickupEffectConfigScript: Variant = preload("res://scripts/combat/pickup_effect_config.gd")
var _player: CombatPlayer = null


## 解析父节点为 **`CombatPlayer`**；非玩家挂载时本组件不工作
func _ready() -> void:
	var p: Node = get_parent()
	if p is CombatPlayer:
		_player = p as CombatPlayer


## 中文：遍历组内 **`BattlePickup`** — 超出磁力半径忽略；达收集距离结算；否则沿径向牵引
func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player) or _player.is_dead():
		return
	var b := GameConfig.PLAYER_BASICS
	var anchor: Vector2 = _player.global_position
	var magnet_r: float = _player.get_effective_combat_pickup_magnet_radius()
	var collect_d: float = b.combat_pickup_collect_distance
	var speed_min: float = b.combat_pickup_magnet_speed_min
	var speed_max: float = b.combat_pickup_magnet_speed_max
	for n in get_tree().get_nodes_in_group("battle_pickups"):
		if not is_instance_valid(n):
			continue
		if not (n is Node2D):
			continue
		var pu: Node2D = n as Node2D
		if not pu.has_method("get_pickup_effect"):
			continue
		var eff: Variant = pu.call("get_pickup_effect")
		if eff == null or eff.get_script() != _PickupEffectConfigScript:
			continue
		var d: float = pu.global_position.distance_to(anchor)
		## 中文：超出磁力圈 — 本帧不牵引、不结算
		if d > magnet_r:
			continue
		var can_magnet: bool = true
		if pu.has_method("can_be_magnetized"):
			can_magnet = bool(pu.call("can_be_magnetized"))
		## 中文：已进入收集距离 — 执行效果并移除拾取物
		if d <= collect_d:
			eff.call("apply", _player)
			pu.queue_free()
			continue
		## 中文：不可磁吸的拾取物只允许贴近拾取，不会被远距离牵引。
		if not can_magnet:
			continue
		## 中文：磁力区内但未贴脸 — 沿径向向玩家牵引
		var dir: Vector2 = (anchor - pu.global_position) / maxf(d, 0.001)
		var t: float = clampf(1.0 - d / maxf(magnet_r, 0.001), 0.0, 1.0)
		var sp: float = lerpf(speed_min, speed_max, t)
		pu.global_position += dir * sp * delta
