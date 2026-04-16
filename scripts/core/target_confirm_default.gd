extends RefCounted
class_name TargetConfirmDefault
## 索敌结果确认默认实现：方案枚举、`resolve` / `resolve_global` 与内嵌 **`TargetConfirmResult`** 均在此；供弹道首发、激光瞄准等消费。

## **边界**：不包含爆炸圆心、灼地落点等有独立表现规则的锚点（见 `CombatEffectRunner` 与各效果脚本）。

## 索敌方案编号（0~4 为当前管线已消费语义；≥10 为预留扩展）
enum TargetConfirmScheme {
	NEAREST_FROM_POINT = 0, ## 自锚点全图取最近存活敌对
	RANDOM_IN_RADIUS = 1, ## 圆内随机选一敌对
	ALL_IN_RADIUS = 2, ## 圆内全部敌对；主目标取距锚点最近者
	CASTER_ANCHOR_ONLY = 3, ## 仅锚定施法者，无主敌对（直线基准由调用方用速度等决定）
	NEAREST_IN_RADIUS = 4, ## 圆内（`query_radius`）距锚点最近的存活敌对；圆内无人则失败
	LOWEST_HP_IN_RADIUS = 10, ## 预留：同圆内最低当前生命敌对
	FURTHEST_FROM_ANCHOR = 11, ## 预留：全图或圆内距锚点最远敌对
	PRIORITY_TAG_OR_ELSE_NEAREST = 12, ## 预留：按标签/优先级过滤后最近
}

## 进程内共享实例，供战斗执行器等处调用（非 Autoload）
static var _shared_target_confirm: TargetConfirmDefault = null


## 懒取共享的默认实现实例，避免每发命令 `new`
static func shared_instance() -> TargetConfirmDefault:
	if _shared_target_confirm == null:
		_shared_target_confirm = TargetConfirmDefault.new()
	return _shared_target_confirm


## 静态便捷入口：等价于共享实例上的 `resolve`，供 `CombatEffectRunner` 等无 Autoload 注册处调用
static func resolve_global(
	scheme: TargetConfirmScheme,
	from_world: Vector2,
	query_radius: float
) -> RefCounted:
	return shared_instance().resolve(scheme, from_world, query_radius)


## 按方案解析；预留方案（≥10）未单独实现时告警并回退 `NEAREST_FROM_POINT`
## scheme：目标选择方案；from_world：查询锚点（世界坐标）；query_radius：查询半径（像素）
func resolve(
	scheme: TargetConfirmScheme,
	from_world: Vector2,
	query_radius: float
) -> RefCounted:
	if scheme >= 10:
		push_warning("TargetConfirmDefault.resolve：方案 %d 尚未实现，回退 NEAREST_FROM_POINT" % scheme)
		scheme = TargetConfirmScheme.NEAREST_FROM_POINT
	var player: CombatPlayer = CombatPlayer.get_combat_player()
	var anchor: Vector2 = from_world
	var hostiles: Array = []
	var primary: CombatEnemy = null
	var used_r: float = maxf(0.0, query_radius)
	var ok: bool = false

	match scheme:
		TargetConfirmScheme.CASTER_ANCHOR_ONLY: # 仅锚点，无敌人，anchor 为施法者位置（若有），返回空目标列表
			if player != null:
				anchor = player.global_position
			return TargetConfirmResult.create(true, null, [], anchor, 0.0, int(scheme))
		TargetConfirmScheme.NEAREST_FROM_POINT: # 最近敌人，忽略半径，仅取 anchor 附近最近一个
			primary = _nearest_hostile(anchor)
			ok = primary != null
			if primary != null:
				hostiles = [primary]
			return TargetConfirmResult.create(ok, primary, hostiles, anchor, 0.0, int(scheme))

		TargetConfirmScheme.RANDOM_IN_RADIUS: # 半径内全部敌人，primary 随机选一，hostiles 全部列出
			hostiles = _hostiles_in_radius(anchor, used_r)
			ok = hostiles.size() > 0
			if ok:
				primary = hostiles[randi() % hostiles.size()] as CombatEnemy
			return TargetConfirmResult.create(ok, primary, hostiles, anchor, used_r, int(scheme))

		TargetConfirmScheme.ALL_IN_RADIUS: # 半径内全部敌人，primary 为最近一个，hostiles 全部列出
			hostiles = _hostiles_in_radius(anchor, used_r)
			ok = hostiles.size() > 0
			if ok:
				primary = _nearest_in_list(hostiles, anchor)
			return TargetConfirmResult.create(ok, primary, hostiles, anchor, used_r, int(scheme))

		TargetConfirmScheme.NEAREST_IN_RADIUS: # 半径内最近敌人，只有一个 primary，hostiles 只含此一项
			hostiles = _hostiles_in_radius(anchor, used_r)
			ok = hostiles.size() > 0
			if ok:
				primary = _nearest_in_list(hostiles, anchor)
				hostiles = [primary]
			return TargetConfirmResult.create(ok, primary, hostiles, anchor, used_r, int(scheme))

		_: # 兜底：等价最近敌人，忽略半径
			primary = _nearest_hostile(anchor)
			ok = primary != null
			if primary != null:
				hostiles = [primary]
			return TargetConfirmResult.create(ok, primary, hostiles, anchor, 0.0, int(scheme))

## 在 `center` 半径 `radius` 内收集存活 `CombatEnemy`（`radius` 须 > 0）
func _hostiles_in_radius(center: Vector2, radius: float) -> Array:
	var out: Array = []
	var enemy_manager: EnemyManager = EnemyManager.get_enemy_manager()
	if enemy_manager == null or radius <= 0.0:
		return out
	var r2: float = radius * radius
	for child in enemy_manager.get_children():
		var e := child as CombatEnemy
		if e == null or e.is_dead():
			continue
		if center.distance_squared_to(e.global_position) <= r2:
			out.append(e)
	return out


## 距 `from_world` 最近存活敌对；无则 null
func _nearest_hostile(from_world: Vector2) -> CombatEnemy:
	var enemy_manager: EnemyManager = EnemyManager.get_enemy_manager()
	# 查找距离 `from_world` 最近的存活敌人，返回 CombatEnemy 实例或 null
	if enemy_manager == null:
		return null # 敌人管理器无效，直接返回 null
	var nearest: CombatEnemy = null # 当前最近敌人
	var best: float = INF # 当前最近距离平方（初始为无穷大，便于首次比较）
	for child in enemy_manager.get_children():
		var e := child as CombatEnemy
		if e == null or e.is_dead():
			continue # 非敌人或已死亡，跳过
		var d2: float = from_world.distance_squared_to(e.global_position) # 计算与锚点的距离平方
		if d2 < best:
			best = d2 # 若更近则更新最优距离与最近敌人
			nearest = e
	return nearest # 可能为 null（未找到存活敌人）


## 在列表中取距 `from_world` 最近者
func _nearest_in_list(hostiles: Array, from_world: Vector2) -> CombatEnemy:
	var best_e: CombatEnemy = null
	var best_d2: float = INF
	for item in hostiles:
		var e := item as CombatEnemy
		if e == null or e.is_dead():
			continue
		var d2: float = from_world.distance_squared_to(e.global_position)
		if d2 < best_d2:
			best_d2 = d2
			best_e = e
	return best_e


## 单次索敌解析的强类型负载（替代字符串键字典）；为 `TargetConfirmDefault` 内嵌类，外部队列类型写 **`TargetConfirmDefault.TargetConfirmResult`**
class TargetConfirmResult extends RefCounted:
	## 本方案是否给出可用语义（如圆内无人时随机/全选为 false）
	var ok: bool = false
	## 主目标；允许为 null（无锁敌时调用方仍可按默认朝向发射）
	var primary_hostile: CombatEnemy = null
	## 候选敌对列表（拷贝自解析时的数组，避免外部误改同一引用）
	var hostiles: Array[CombatEnemy] = []
	## 查询锚点世界坐标
	var anchor_world: Vector2 = Vector2.ZERO
	## 本次使用的查询半径（像素）；全图最近类方案可为 0
	var query_radius: float = 0.0
	## 本次方案整型值，与 `TargetConfirmScheme` 枚举一致
	var kind: int = 0


	## 将 `p_hostiles` 中有效 `CombatEnemy` 填入强类型数组并返回新实例
	static func create(
		p_ok: bool,
		p_primary: CombatEnemy,
		p_hostiles: Array,
		p_anchor: Vector2,
		p_query_radius: float,
		p_kind: int
	) -> TargetConfirmResult:
		var r := TargetConfirmResult.new()
		r.ok = p_ok
		r.primary_hostile = p_primary
		var typed: Array[CombatEnemy] = []
		for item in p_hostiles:
			var e := item as CombatEnemy
			if e != null:
				typed.append(e)
		r.hostiles = typed
		r.anchor_world = p_anchor
		r.query_radius = p_query_radius
		r.kind = p_kind
		return r
