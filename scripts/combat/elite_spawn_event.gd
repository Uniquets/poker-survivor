extends Resource
class_name EliteSpawnEvent
## 精英刷怪事件：在指定时间生成一个复用普通敌人场景的精英版本。

## 局内经过秒数达到该值时触发。
@export var trigger_seconds: float = 150.0
## 精英敌人场景；为空时回落到 EnemyManager.enemy_scene。
@export var elite_scene: PackedScene = null
## 死亡掉落条目，沿用普通敌人的 EnemyDropEntry 机制。
@export var death_drop_entries: Array = []
## 精英外观缩放倍率。
@export_range(1.0, 5.0, 0.05) var visual_scale_multiplier: float = 1.35
## 精英颜色调制。
@export var elite_modulate: Color = Color(1.45, 0.65, 0.25, 1.0)
## 精英生命倍率。
@export_range(1.0, 20.0, 0.1) var health_multiplier: float = 4.0
## 精英移动速度倍率。
@export_range(0.1, 5.0, 0.1) var move_speed_multiplier: float = 1.1
## 精英接触伤害倍率。
@export_range(0.1, 10.0, 0.1) var touch_damage_multiplier: float = 1.5


## 返回该事件是否可参与触发。
func is_valid_event() -> bool:
	return trigger_seconds >= 0.0
