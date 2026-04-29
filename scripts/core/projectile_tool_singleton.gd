extends Node
## Autoload：多发弹道/导弹的**发射几何**工具（并行错开、角度扇分布），避免多条弹道起点与朝向完全重合；不含玩法与伤害逻辑。

## 布局字典中与 `compute_parallel_layout` / `compute_angular_fan_layout` 配套使用的键名
const RESULT_KEY_POSITION: String = "position"
## 单位发射方向（归一化）
const RESULT_KEY_DIRECTION: String = "direction"


## 并行弹道：共一条基向 `aim_forward`（通常取玩家→目标），各条**方向相同**，仅起点沿法线平移 `line_spacing` 的整数倍错开
## origin：发射参考点（一般为玩家中心）；count≤0 时按 1 处理；line_spacing≤0 时用极小正值避免除零
static func compute_parallel_layout(origin: Vector2, aim_forward: Vector2, count: int, line_spacing: float) -> Array:
	var n: int = maxi(1, count)
	var f: Vector2 = aim_forward
	if f.length_squared() < 1e-6:
		f = Vector2.RIGHT
	else:
		f = f.normalized()
	var perp: Vector2 = Vector2(-f.y, f.x)
	var spacing: float = maxf(line_spacing, 0.01)
	var out: Array = []
	for i in range(n):
		var idx_off: float = float(i) - float(n - 1) * 0.5
		var lateral: Vector2 = perp * idx_off * spacing
		out.append({
			RESULT_KEY_POSITION: origin + lateral,
			RESULT_KEY_DIRECTION: f,
		})
	return out


## 角度扇：仅一条时方向即 `aim_forward`；多条时在「从 aim_forward 起、绕 CCW 扫过 total_arc_deg」的扇形内**均匀**取向，第 i 条转角为 (i+1)/(n+1)*total_arc_deg（例：90°、2 条 → 30° 与 60°）
## total_arc_deg≤0 时退回为全部沿 aim_forward，避免重叠
static func compute_angular_fan_directions(aim_forward: Vector2, count: int, total_arc_deg: float) -> PackedVector2Array:
	var n: int = maxi(1, count)
	var f: Vector2 = aim_forward
	if f.length_squared() < 1e-6:
		f = Vector2.RIGHT
	else:
		f = f.normalized()
	var dirs := PackedVector2Array()
	if n == 1:
		dirs.append(f)
		return dirs
	var arc_rad: float = deg_to_rad(total_arc_deg)
	if absf(arc_rad) < 1e-5:
		for _j in range(n):
			dirs.append(f)
		return dirs
	for i in range(n):
		var t: float = float(i + 1) / float(n + 1)
		dirs.append(f.rotated(arc_rad * t))
	return dirs


## 角度扇布局：每条共用 `origin` 起点，方向由 `compute_angular_fan_directions` 给出
static func compute_angular_fan_layout(origin: Vector2, aim_forward: Vector2, count: int, total_arc_deg: float) -> Array:
	var dirs: PackedVector2Array = compute_angular_fan_directions(aim_forward, count, total_arc_deg)
	var out: Array = []
	for i in range(dirs.size()):
		out.append({
			RESULT_KEY_POSITION: origin,
			RESULT_KEY_DIRECTION: dirs[i],
		})
	return out


## 从玩家指向目标计算基向；目标重合或无效时返回水平右向
static func aim_forward_from_to(from_pos: Vector2, to_pos: Vector2) -> Vector2:
	var d: Vector2 = to_pos - from_pos
	if d.length_squared() < 1e-6:
		return Vector2.RIGHT
	return d.normalized()


## 在矩形内采样满足最小间距的一组点；若达到尝试上限仍不足，返回当前最优集合（允许少量不足）。
static func sample_points_in_rect_with_distance(
	rect: Rect2,
	count: int,
	min_distance: float,
	max_attempts: int
) -> PackedVector2Array:
	var need: int = maxi(1, count)
	var out := PackedVector2Array()
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		out.append(rect.position + rect.size * 0.5)
		return out
	var min_dist2: float = maxf(0.0, min_distance) * maxf(0.0, min_distance)
	var attempts: int = maxi(max_attempts, need)
	for _i in range(attempts):
		if out.size() >= need:
			break
		var p := Vector2(
			randf_range(rect.position.x, rect.end.x),
			randf_range(rect.position.y, rect.end.y)
		)
		var ok: bool = true
		for e in out:
			if e.distance_squared_to(p) < min_dist2:
				ok = false
				break
		if ok:
			out.append(p)
	if out.is_empty():
		out.append(rect.position + rect.size * 0.5)
	return out


## 过滤与墙体重叠/过近的点；用圆查询近似采样点占位检测。
static func filter_points_by_wall_overlap(
	points: PackedVector2Array,
	world_2d: World2D,
	wall_mask: int,
	query_radius: float
) -> PackedVector2Array:
	var out := PackedVector2Array()
	if world_2d == null:
		return points
	var ss: PhysicsDirectSpaceState2D = world_2d.direct_space_state
	for p in points:
		var qp := PhysicsShapeQueryParameters2D.new()
		var c := CircleShape2D.new()
		c.radius = maxf(2.0, query_radius)
		qp.shape = c
		qp.transform = Transform2D(0.0, p)
		qp.collision_mask = wall_mask
		qp.collide_with_areas = true
		qp.collide_with_bodies = true
		var hit: Array = ss.intersect_shape(qp, 1)
		if hit.is_empty():
			out.append(p)
	return out


## 在相机可见区采样并过滤墙体点；必要时放宽最小距离以尽量采满数量。
static func sample_points_in_camera_view_no_wall(
	camera: Camera2D,
	world_2d: World2D,
	count: int,
	min_dist: float,
	max_dist: float,
	max_attempts: int,
	wall_mask: int,
	query_radius: float
) -> PackedVector2Array:
	var need: int = maxi(1, count)
	if camera == null:
		return PackedVector2Array()
	var view_size: Vector2 = camera.get_viewport_rect().size * camera.zoom
	var rect := Rect2(camera.global_position - view_size * 0.5, view_size)
	var cur_min: float = maxf(0.0, min_dist)
	var max_step: int = 6
	var out := PackedVector2Array()
	for _s in range(max_step):
		var raw: PackedVector2Array = sample_points_in_rect_with_distance(rect, need, cur_min, max_attempts)
		var filtered: PackedVector2Array = filter_points_by_wall_overlap(raw, world_2d, wall_mask, query_radius)
		# 中文：限制点间最大距离，避免过度分散导致包围区过大。
		out = PackedVector2Array()
		for p in filtered:
			var ok: bool = true
			for e in out:
				if p.distance_to(e) > max_dist:
					ok = false
					break
			if ok:
				out.append(p)
			if out.size() >= need:
				break
		if out.size() >= need:
			return out
		cur_min *= 0.75
	# 中文：最终兜底，返回已有点；若仍空则退回相机中心。
	if out.is_empty():
		out.append(camera.global_position)
	return out


## 计算二维点集凸包（逆时针）；点数 < 3 时原样返回。
static func compute_convex_hull(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() <= 2:
		return points
	var sorted: Array = []
	for p in points:
		sorted.append(p)
	sorted.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return a.x < b.x if not is_equal_approx(a.x, b.x) else a.y < b.y
	)
	var lower: Array = []
	for p in sorted:
		while lower.size() >= 2 and _cross(lower[lower.size() - 2], lower[lower.size() - 1], p) <= 0.0:
			lower.pop_back()
		lower.append(p)
	var upper: Array = []
	for i in range(sorted.size() - 1, -1, -1):
		var p2: Vector2 = sorted[i]
		while upper.size() >= 2 and _cross(upper[upper.size() - 2], upper[upper.size() - 1], p2) <= 0.0:
			upper.pop_back()
		upper.append(p2)
	lower.pop_back()
	upper.pop_back()
	var hull := PackedVector2Array()
	for p3 in lower:
		hull.append(p3)
	for p4 in upper:
		hull.append(p4)
	return hull


## 三点叉积符号（OA x OB），用于凸包转向判断。
static func _cross(o: Vector2, a: Vector2, b: Vector2) -> float:
	return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
