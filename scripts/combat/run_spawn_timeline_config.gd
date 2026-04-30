extends Resource
class_name RunSpawnTimelineConfig
## 单局刷怪时间轴：普通时间段 + 精英事件时间 + Boss 入场时间。

## 按起始秒排序的普通刷怪时间段。
@export var segments: Array = []
## 精英事件触发时间点（局内秒）；事件确定触发，不用概率控制主节奏。
@export var elite_event_seconds: Array[float] = [150.0, 330.0, 510.0]
## 精英事件资源；优先于旧的 elite_event_seconds，用于配置场景、数值和掉落。
@export var elite_events: Array = []
## Boss 入场时间（局内秒）；到达后普通刷怪停止。
@export var boss_event_seconds: float = 480.0


## 按局内秒数返回当前普通刷怪段；超出所有段时返回最后一段。
func segment_for_time(match_seconds: float) -> Resource:
	var last_valid: Resource = null
	for raw in segments:
		var segment: Resource = raw as Resource
		if segment == null:
			continue
		last_valid = segment
		if segment.has_method("contains_time") and segment.call("contains_time", match_seconds):
			return segment
	return last_valid


## 返回当前时间已到点且尚未触发的第一个精英事件资源。
func elite_event_for_time(match_seconds: float, triggered: Dictionary) -> Resource:
	for raw in elite_events:
		var event: Resource = raw as Resource
		if event == null or not event.has_method("is_valid_event"):
			continue
		if not bool(event.call("is_valid_event")):
			continue
		var trigger_seconds: float = float(event.get("trigger_seconds"))
		if match_seconds >= trigger_seconds and not triggered.has(trigger_seconds):
			return event
	return null
