extends ShapeEffectSpec
class_name ShapeWaypointVolleyEffectSpec
## **`WAYPOINT_VOLLEY`**：圆内随机航点齐射；数值 + **可选航点弹预制体槽**；装配为 **`PlayEffectCommand`**。


@export_group("航点齐射")
## 总发数
@export var volley_count: int = 20
## 每发伤害（点）
@export var damage_per_hit: int = 12
## 随机航点与查询共用圆半径（像素）
@export var random_query_radius: float = 720.0
## 每发首次命中后还可再命中目标数
@export var pierce_extra_per_shot: int = 3
## 航点弹全局并发上限（在场航点弹总数达到上限后，剩余发射请求进入补发队列）
@export var max_concurrent_in_radius: int = 8
## 航点弹批量重选航点间隔（秒）
@export var batch_refresh_sec: float = 3.0
## 非空时：**直接**用该预制体作为航点弹根场景（写入 **`PlayEffectCommand.waypoint_projectile_scene_override`**）；空则回落 `DEFAULT` 牌型与目录外层默认预制体
@export var waypoint_projectile_scene: PackedScene = null
## 非空时：发射瞬间优先播放该音效（写入 **`PlayEffectCommand.sfx_fire`**）
@export var fire_sfx: AudioStream = null
## 命中首段音效（写入命令 **`sfx_hit_first`**）
@export var hit_sfx_first: AudioStream = null
## 命中穿透段音效（写入命令 **`sfx_hit_pierce`**）
@export var hit_sfx_pierce: AudioStream = null
## 命中换向段音效（写入命令 **`sfx_hit_reroute`**）
@export var hit_sfx_reroute: AudioStream = null
