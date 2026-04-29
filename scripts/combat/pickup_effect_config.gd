extends Resource
class_name PickupEffectConfig
## 拾取时对 **`CombatPlayer`** 的作用：**单一 `Resource`**，用 **`effect_kind`** 分支，**不**使用多脚本子类继承。


## 与 **`PickupEffectConfig.apply`** 内 **`match`** 分支一一对应
enum EffectKind {
	NONE,
	ADD_EXPERIENCE,
	HEAL_PERCENT_OF_MAX_HEALTH,
}

## 要执行的效果种类
@export var effect_kind: EffectKind = EffectKind.NONE
## **`ADD_EXPERIENCE`**：增加的经验点数（**`≤0`** 时 **`apply`** 忽略）
@export var experience_amount: int = 0
## **`HEAL_PERCENT_OF_MAX_HEALTH`**：相对有效最大生命的治疗比例 **`0～1`**
@export_range(0.0, 1.0, 0.01) var heal_ratio_of_max: float = 0.0


## 对玩家执行本资源配置的效果；**`player`** 须为 **`CombatPlayer`** 且未死亡。
## **参数**：**`player`** — 当前局内玩家。**副作用**：可能改经验/生命并发 **`CombatPlayer`** 既有信号。
func apply(player: CombatPlayer) -> void:
	if player == null or not is_instance_valid(player) or player.is_dead():
		return
	match effect_kind:
		EffectKind.ADD_EXPERIENCE:
			## 中文：加经验 — 非正数不写条，与旧豆行为一致
			if experience_amount > 0:
				player.add_experience(experience_amount)
		EffectKind.HEAL_PERCENT_OF_MAX_HEALTH:
			## 中文：按比例治疗 — 与旧血包一致夹紧到 **`0～1`**
			player.heal_percent_of_max_health(clampf(heal_ratio_of_max, 0.0, 1.0))
		_:
			pass
