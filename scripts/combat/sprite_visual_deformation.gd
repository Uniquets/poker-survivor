extends Sprite2D
## 弹道等 **Sprite2D** 通用视觉形变：**不**改父节点位移与碰撞，**仅**调整本节点 **`rotation` / `scale` / `skew`**（当前实现里 **`SPIN_Z_CONSTANT`** 只改 **rotation**）。
## 形变类型由 **`deform_kind`** 选择；后续扩展时在 **`match`** 内增加分支及对应 **`@export`** 组。父节点可 **`Node2D`** 读取 **`global_rotation` / `global_position`** 等（本模式暂不需要）。


## 形变模式（按需扩展分支）
enum DeformKind {
	## 不每帧改写姿态，保持场景与美术摆拍
	NONE,
	## 绕自身中心在 2D 平面内恒角速自旋（叠在父节点朝向上）
	SPIN_Z_CONSTANT,
}

## 当前使用的形变逻辑
@export var deform_kind: DeformKind = DeformKind.NONE

@export_group("绕 Z 恒角速自旋（仅 deform_kind = SPIN_Z_CONSTANT 时生效）")
## 自转角速度（弧度/秒）；约 **6.28 ≈ 每秒一整圈**
@export var spin_radians_per_second: float = 18.0
## 为真时 **`_ready`** 随机初相，多发齐射时各实例不同步
@export var randomize_start_phase: bool = true

## 场景里摆好的本地 **rotation**（与累加自旋合成）
var _base_rotation: float = 0.0
## 已累加的自转角（弧度）
var _spin_accum: float = 0.0


## 缓存基线旋转；**`SPIN_Z_CONSTANT`** 下可选随机初相
func _ready() -> void:
	_base_rotation = rotation
	if deform_kind == DeformKind.SPIN_Z_CONSTANT and randomize_start_phase:
		_spin_accum = randf_range(-PI, PI)


## 按 **`deform_kind`** 分支更新本节点视觉（**不写**父 **`position`**）
func _process(delta: float) -> void:
	match deform_kind:
		## 中文：无动态形变，完全交给场景与其它系统
		DeformKind.NONE:
			pass
		## 中文：平面内绕 Z 累加转角，**scale/skew** 不动
		DeformKind.SPIN_Z_CONSTANT:
			_spin_accum += spin_radians_per_second * delta
			rotation = _base_rotation + _spin_accum
