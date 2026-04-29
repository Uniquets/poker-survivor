extends ShapeEffectSpec
class_name ShapeParallelVolleyEffectSpec
## **`PROJECTILE_VOLLEY`**：并行多发弹道数值与**可选预制体槽**；装配为 **`PlayEffectCommand`**（命令内 **`volley_*`** 字段承载穿透与表现绑定）。


@export_group("并行多发弹道")
## 发射总枚数
@export var volley_count: int = 2
## 每发伤害（点）
@export var damage_per_hit: int = 8
## 扇形展开角（度）
@export var spread_deg: float = 6.0
## 每发在首次命中后还可再命中的**额外**敌人数
@export var extra_hit_budget_per_shot: int = 1
## 为真时多发共线、穿透段直线追击（不写链式转向）
@export var straight_volley: bool = true
## 非空时：**直接**用该 **`PackedScene`** 作为弹道根预制体（写入 **`PlayEffectCommand.projectile_scene_override`**），**不再**按 **`COMBAT_PRESENTATION`** 并行主/副槽切换预制
@export var projectile_scene: PackedScene = null
## 非空时：发射瞬间优先播放该音效（写入 **`PlayEffectCommand.sfx_fire`**）；为空再按回落链解析
@export var fire_sfx: AudioStream = null
## 命中首段音效（写入命令 **`sfx_hit_first`**）
@export var hit_sfx_first: AudioStream = null
## 命中穿透段音效（写入命令 **`sfx_hit_pierce`**）
@export var hit_sfx_pierce: AudioStream = null
## 命中换向段音效（写入命令 **`sfx_hit_reroute`**）
@export var hit_sfx_reroute: AudioStream = null
## 锁敌查询半径（像素）
@export var lock_query_radius: float = 1000.0
## 并行多发横向线距（像素）
@export var line_spacing: float = 14.0
## 为真且 **`projectile_scene`** 空时：按 **`GameConfig.COMBAT_PRESENTATION`** 并行槽选预制与发射音（装配器写入命令 **`volley_bind_presentation_slots`** 等）
@export var binding_card_shape_presentation: bool = true
## 为真且走 **`binding_card_shape_presentation`** 时：发射音走并行**主槽**链（装配器映射到 **`volley_use_primary_scene`**）
@export var binding_use_default_shape_fire_slot: bool = false
