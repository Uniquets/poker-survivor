extends Sprite2D
## 并行直线 **卡牌贴图弹体** 专用：**绕子节点自身中心**在 2D 平面内快速自旋（累加 **rotation**）；**不**改 **`scale` / `skew`**、不改弹道与命中。
## 根节点 **`Projectile`** 仍负责整体对准飞行方向；此处仅叠一层「转得快」的牌面旋转。


## 自转角速度（弧度/秒），越大转得越快；约 **6.28 ≈ 每秒一整圈**
@export var spin_radians_per_second: float = 18.0
## 为真时 **`_ready`** 随机初相，多发齐射时各卡不同步
@export var randomize_start_phase: bool = true

## 场景里摆好的本地 **rotation**（与累加自旋合成）
var _base_rotation: float = 0.0
## 已累加的自转角（弧度），单调变化
var _spin_accum: float = 0.0


## 缓存基线旋转；可选随机初相
func _ready() -> void:
	_base_rotation = rotation
	if randomize_start_phase:
		_spin_accum = randf_range(-PI, PI)


## 每帧累加自转角并写回 **rotation**；**scale/skew** 保持场景设定不动
func _process(delta: float) -> void:
	_spin_accum += spin_radians_per_second * delta
	rotation = _base_rotation + _spin_accum
