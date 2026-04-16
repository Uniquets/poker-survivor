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
