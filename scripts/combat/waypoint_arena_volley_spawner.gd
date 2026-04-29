extends RefCounted
class_name WaypointArenaVolleySpawner
## 策划表访问（见 `enemy.gd` 说明）

## **锚点圆航点弹道**的全局并发、补发队列与**对象池**（与具体牌面点数解耦；当前玩法上由四条 2 等效果驱动）。不按「玩家圆内数量」计数（避免玩家位移导致漏计、并发失控）。
## 单局内可存在多批待发（FIFO）；每颗弹体离树时尝试按上限补发；按配置间隔统一下发「锚点圆内新航点」。

## 每批待发：`left` 剩余颗数 + 弱引用玩家/敌管 + 父节点路径 + 命令快照
static var _jobs: Array = []
## 当前在场、已计入全局并发的航点弹体（`register_projectile` / `_exit_tree` 成对维护）
static var _active_projectiles: Array = []
## 已离树待复用的弹体节点（上限随全局并发放大，避免无限增长）
static var _pooled_projectiles: Array = []
## 下次执行「全体航点刷新」的 `Time.get_ticks_msec()` 截止时刻；0 表示尚未初始化
static var _batch_waypoint_refresh_deadline_ms: int = 0
## 当前在场航点弹批量刷新间隔（秒），由最近一次航点命令写入
static var _active_batch_refresh_sec: float = 3.0
## 当前在场航点弹并发上限，由最近一次航点命令写入
static var _active_max_concurrent_in_radius: int = 8


## 由 `WaypointArenaProjectile` 与 `_spawn_instance` 登记；同一实例重复调用无影响
static func register_projectile(proj: Node2D) -> void:
	if proj != null and _active_projectiles.find(proj) < 0:
		_active_projectiles.append(proj)


static func unregister_projectile(proj: Node2D) -> void:
	_active_projectiles.erase(proj)


## 清理失效引用并返回**全局**在场数量（凡已 `register`、尚未离树注销者均计）
static func count_active_globally() -> int:
	var i: int = _active_projectiles.size()
	while i > 0:
		i -= 1
		var p: Node2D = _active_projectiles[i] as Node2D
		if not is_instance_valid(p):
			_active_projectiles.remove_at(i)
	return _active_projectiles.size()


## 由 `CombatEffectRunner` 调用：按**全局**空位将本波补至上限（`min(cmd.count, 上限−当前全局)`），余量入队
## **参数**：`player` / `enemy_manager` / `parent` / `cmd` — 与 Runner 一致；**副作用**：实例化或从池取出弹体与/或写入 `_jobs`
static func begin_volley(player: CombatPlayer, enemy_manager: EnemyManager, parent: Node, cmd) -> void:
	if not is_instance_valid(player) or not is_instance_valid(enemy_manager) or parent == null or cmd == null:
		return
	_active_batch_refresh_sec = maxf(0.05, float(cmd.waypoint_batch_refresh_sec))
	_active_max_concurrent_in_radius = maxi(1, int(cmd.waypoint_max_concurrent_in_radius))
	var max_n: int = _active_max_concurrent_in_radius
	var requested: int = maxi(1, cmd.count)
	var cur: int = count_active_globally()
	var slots: int = maxi(0, max_n - cur)
	var spawn_now: int = mini(requested, slots)
	for __i in range(spawn_now):
		_spawn_instance(player, enemy_manager, parent, cmd)
	var queued: int = requested - spawn_now
	if queued > 0:
		_jobs.append({
			"left": queued,
			"player": weakref(player),
			"enemy_manager": weakref(enemy_manager),
			"parent_path": parent.get_path(),
			"cmd": cmd,
		})


## 全局是否还能再容纳一颗（补发队列用）
static func _can_spawn_one_globally() -> bool:
	var max_n: int = maxi(1, _active_max_concurrent_in_radius)
	return count_active_globally() < max_n


## 对象池容量：至少能覆盖一波补发余量，避免无意义堆积
static func _pool_capacity() -> int:
	var max_n: int = maxi(1, _active_max_concurrent_in_radius)
	return maxi(32, max_n * 4)


## 弹体生命周期结束：优先入池复用；池满则返回假由调用方 `queue_free`
## **返回**：是否已成功离树并进入 `_pooled_projectiles`
static func return_waypoint_volley_to_pool(proj: Node2D) -> bool:
	if proj == null:
		return false
	if _pooled_projectiles.size() >= _pool_capacity():
		return false
	if proj.get_parent() != null:
		proj.get_parent().remove_child(proj)
	_pooled_projectiles.append(proj)
	return true


## 实例化或自池取出并挂树（调用前须已满足全局并发）
static func _spawn_instance(player: CombatPlayer, enemy_manager: EnemyManager, parent: Node, cmd) -> void:
	var proj: Node2D = null
	if _pooled_projectiles.size() > 0:
		proj = _pooled_projectiles.pop_back() as Node2D
	if proj == null:
		## 中文：命令级航点预制覆盖（牌型表 **`ShapeWaypointVolleyEffectSpec.waypoint_projectile_scene`**）为唯一来源
		var ps: PackedScene = cmd.waypoint_projectile_scene_override as PackedScene
		if ps == null:
			push_warning("WaypointArenaVolleySpawner: WAYPOINT_VOLLEY 缺少 waypoint_projectile_scene_override，已跳过本发")
			return
		proj = ps.instantiate() as Node2D
	if proj == null:
		return
	var spawn_pos: Vector2 = player.get_attack_anchor_global()
	if proj.has_method("setup_waypoint_arena_volley"):
		proj.setup_waypoint_arena_volley(player, enemy_manager, cmd, spawn_pos)
	# 须在 `call_deferred(add_child)` 之前登记，否则同帧内全局计数恒为 0
	register_projectile(proj)
	parent.call_deferred("add_child", proj)


## 由 `WaypointArenaProjectile` 在 `_exit_tree` 调用：在全局并发允许下连续补发队首批次
static func notify_projectile_freed() -> void:
	while _jobs.size() > 0:
		var job: Dictionary = _jobs[0]
		var pw: Variant = job.get("player", null)
		var p: CombatPlayer = null
		if pw is WeakRef:
			p = (pw as WeakRef).get_ref() as CombatPlayer
		var ew: Variant = job.get("enemy_manager", null)
		var em: EnemyManager = null
		if ew is WeakRef:
			em = (ew as WeakRef).get_ref() as EnemyManager
		var ppath: NodePath = job.get("parent_path", NodePath())
		var cmd = job.get("cmd", null)
		var left: int = maxi(0, int(job.get("left", 0)))
		if left <= 0 or cmd == null:
			_jobs.remove_at(0)
			continue
		if not is_instance_valid(p) or not is_instance_valid(em):
			_jobs.remove_at(0)
			continue
		var parent: Node = Engine.get_main_loop().root.get_node_or_null(ppath)
		if parent == null:
			_jobs.remove_at(0)
			continue
		if not _can_spawn_one_globally():
			break
		_spawn_instance(p, em, parent, cmd)
		left -= 1
		if left <= 0:
			_jobs.remove_at(0)
		else:
			job["left"] = left
			_jobs[0] = job


## 由任意在场弹体每帧先调：到间隔则对**全部** `_active_projectiles` 调用 `apply_batch_waypoint_refresh_in_player_disk`
static func maybe_periodic_batch_waypoint_refresh() -> void:
	var interval_sec: float = maxf(0.05, _active_batch_refresh_sec)
	var interval_ms: int = int(round(interval_sec * 1000.0))
	var now: int = Time.get_ticks_msec()
	if _batch_waypoint_refresh_deadline_ms == 0:
		_batch_waypoint_refresh_deadline_ms = now + interval_ms
		return
	if now < _batch_waypoint_refresh_deadline_ms:
		return
	_batch_waypoint_refresh_deadline_ms = now + interval_ms
	_execute_batch_waypoint_refresh_to_player_disk()


## 对所有有效实例统一下发圆内新航点（不剔除「已在圆外」的弹体位置，只改目标点）
static func _execute_batch_waypoint_refresh_to_player_disk() -> void:
	count_active_globally()
	var i: int = 0
	while i < _active_projectiles.size():
		var node: Variant = _active_projectiles[i]
		i += 1
		if not is_instance_valid(node):
			continue
		## 避免与 `WaypointArenaProjectile` 的 `class_name` 循环解析；仅以公开方法名派发
		if (node as Node).has_method("apply_batch_waypoint_refresh_in_player_disk"):
			(node as Node).call("apply_batch_waypoint_refresh_in_player_disk")
