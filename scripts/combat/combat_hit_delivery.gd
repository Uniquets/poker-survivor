extends RefCounted
class_name CombatHitDelivery
## 命中盒 → **`CombatHurtbox2D`** 时携带的投递数据；**无玩法判定**，伤害与来源由上游写入。


## 本次结算伤害（点）
var damage: int = 0
## 攻击发起体（投射物根、爆炸根、激光节点等），供统计/反伤扩展；可能已 **`queue_free`**，消费方须 **`is_instance_valid`** 再读
var source: Object = null
## 为 true 且宿主为 **`CombatPlayer`** 时：走 **`receive_contact_damage`**（贴身冷却）；否则走 **`apply_damage`**
var use_player_contact_gate: bool = false
## 击退速度模长（像素/秒），沿 **`normalize(受击参考点 − 命中世界坐标)`** 叠加到宿主击退残留；**`-1`** 经 **`get_effective_knockback_speed`** 读配置；**`0`** 关闭本击击退；**`>0`** 为本次覆盖（供各攻击管线分别配置）
var knockback_speed: float = -1.0
## 击退残留衰减系数（秒⁻¹）；**`>=0`** 强制本击；**`-1`** 经 **`get_effective_knockback_decay_per_second`** 读配置（与上字段语义一致）
var knockback_decay_per_second: float = -1.0


## 解析本击实际击退速度（像素/秒）；**`>= 0`** 为显式值（**`0`** 即不击退）
func get_effective_knockback_speed() -> float:
	if knockback_speed >= 0.0:
		return knockback_speed
	var pres: CombatPresentationDefaults = GameConfig.COMBAT_PRESENTATION as CombatPresentationDefaults
	return maxf(0.0, pres.default_hit_knockback_speed)


## 解析本击写入受击体的击退衰减系数（秒⁻¹）；与 **`exp(-k * delta)`** 相乘；**`knockback_decay_per_second >= 0`** 时优先于配置回落
func get_effective_knockback_decay_per_second() -> float:
	if knockback_decay_per_second >= 0.0:
		return knockback_decay_per_second
	var pres: CombatPresentationDefaults = GameConfig.COMBAT_PRESENTATION as CombatPresentationDefaults
	return maxf(0.0, pres.hit_knockback_decay_per_second)
