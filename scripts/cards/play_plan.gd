extends RefCounted
class_name PlayPlan
## 解析管线输出：有序命令列表 + 可选摘要（HUD / 日志 / 兼容旧信号）

## PlayEffectCommand 实例的有序列表（先 logical 后 presentational 由执行器分相遍历）
var commands: Array = []
## 预估对敌总伤害（治疗不计入），供 group_attacked 等 UI 占位
var estimated_enemy_damage: int = 0
## 人类可读标签，便于调试
var debug_tags: Array = []
