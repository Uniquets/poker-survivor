extends Resource
class_name SpawnEnemyEntry
## 单个刷怪池条目：配置敌人场景、权重、压力成本与单次生成数量边界。

## 敌人场景预制；为空时该条目不会参与普通刷怪抽取。
@export var enemy_scene: PackedScene = null
## 权重，仅用于同一时间段敌人池内的种类抽取。
@export_range(0.0, 1000.0, 0.1) var weight: float = 1.0
## 场上压力成本；普通怪通常为 1，肉盾/精英可更高。
@export_range(0.1, 100.0, 0.1) var pressure_cost: float = 1.0
## 本条目单批最少生成数量。
@export_range(1, 64, 1) var min_batch_count: int = 1
## 本条目单批最多生成数量。
@export_range(1, 64, 1) var max_batch_count: int = 1


## 返回该条目是否可参与普通刷怪抽取。
func is_valid_for_spawn() -> bool:
	return enemy_scene != null and weight > 0.0 and pressure_cost > 0.0 and max_batch_count >= min_batch_count
