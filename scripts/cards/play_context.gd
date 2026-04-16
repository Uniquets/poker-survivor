extends RefCounted
class_name PlayContext
## 单次组牌解析的只读输入快照，供 PlayEffectResolver 与管线贡献者使用

## 本步打出的 CardResource 数组（与 GroupDetector 结果一致）
var cards: Array = []
## 组类型（与 `GroupDetector` 字符串经 `GameRules.group_type_from_detector_string` 对齐后的枚举）
var group_type: GameRules.GroupType = GameRules.GroupType.NONE
## 全局花色张数 [黑桃,红心,方块,梅花]，与 EffectResolver 约定一致
var global_suit_counts: Array = [0, 0, 0, 0]
## 玩家最大生命（用于按百分比治疗等逻辑相计算）
var player_max_health: int = 100
## 本步全局强化快照（弹道 +N 等）；由 `AutoAttackSystem` 在调用 `PlayEffectResolver.resolve` 前填入，缺省为 null 表示无加成
var augment_snapshot = null
