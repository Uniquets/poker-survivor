extends Resource
class_name SpawnTimelineSegment
## 一段局内刷怪时间窗：控制普通刷怪间隔、批量、压力预算、硬上限与敌人池。

## 时间段起点（局内秒），包含该边界。
@export var start_seconds: float = 0.0
## 时间段终点（局内秒），不包含该边界；最后一段可用较大值覆盖后期。
@export var end_seconds: float = 60.0
## 本段普通刷怪尝试间隔（秒）。
@export_range(0.05, 60.0, 0.05) var spawn_interval_seconds: float = 1.5
## 本段单次普通刷怪最少数量。
@export_range(1, 64, 1) var min_batch_count: int = 1
## 本段单次普通刷怪最多数量。
@export_range(1, 64, 1) var max_batch_count: int = 1
## 本段场上压力预算；达到预算后暂停普通刷怪。
@export_range(1.0, 1000.0, 1.0) var pressure_budget: float = 12.0
## 本段硬性存活上限；用于兜底限制节点数量。
@export_range(1, 1000, 1) var hard_alive_cap: int = 24
## 本段可抽取的敌人池，元素应为 `SpawnEnemyEntry`。
@export var enemy_pool: Array = []


## 判断局内秒数是否落在本段 `[start_seconds, end_seconds)`。
func contains_time(match_seconds: float) -> bool:
	return match_seconds >= start_seconds and match_seconds < end_seconds


## 返回本段单次普通刷怪数量。
func roll_batch_count() -> int:
	var lo: int = maxi(1, min_batch_count)
	var hi: int = maxi(lo, max_batch_count)
	return randi_range(lo, hi)
