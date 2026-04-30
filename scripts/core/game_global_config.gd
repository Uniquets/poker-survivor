extends Resource
class_name GameGlobalConfig
## 游戏全局：视口/地图、摄像机、物理层（玩家与敌人统一入口）、其他→索敌方案、抽卡概率、牌面
## 由 `CombatTuning` 薄封装；投射物专用层位后续再接

# =============================================================================
@export_group("视口与地图 · 设计分辨率与可玩范围")
## 设计视口宽度（像素），与 UI/摄像机参考一致
@export var world_width: float = 1280.0
## 设计视口高度（像素）
@export var world_height: float = 720.0
## 可玩地图宽度（像素）；**地牢横向无限**模式下仍可用于非摄像机逻辑（如旧 Tile 铺地），摄像机与玩家横向不限于此值
@export var map_width: float = 2457.6
## 可玩地图高度（像素）；须**大于设计视口高度**（见 **`world_height`** / 窗口 1080）才能让摄像机在 Y 上随玩家跟拍；条图由 **`DungeonStripEnvironment`** 等比放大铺满本高度
@export var map_height: float = 1320.0
## 为真时：玩家与摄像机不在 X 轴夹紧到 **`map_width`**，由 **`DungeonStripEnvironment`** 横向循环拼接场景底图
@export var dungeon_horizontal_infinite: bool = true
## 与 **`assets/sprites/scene/地牢场景2.png`** 单块宽度（像素）一致，用于左右无缝拼接等策划参考
@export var dungeon_chunk_width_px: float = 1915.0

# =============================================================================
@export_group("摄像机 · 跟随死区")
## 水平死区半宽（像素）；玩家在带内移动时可不推动摄像机
@export var camera_follow_margin_x: float = 220.0
## 垂直死区半高（像素）
@export var camera_follow_margin_y: float = 140.0

# =============================================================================
@export_group("物理层 · 统一层级管理")
@export_subgroup("玩家 · 层与掩码")
## 玩家所在层（位标志，与项目物理层设置一致）
@export var player_collision_layer: int = 1
## 玩家碰撞掩码（检测哪些层）；**须含** **`world_barrier_collision_layer`** 才能被地牢上下 StaticBody 阻挡
@export var player_collision_mask: int = 64

@export_subgroup("敌人 · 层与掩码")
## 敌人所在层
@export var enemy_collision_layer: int = 2
## 敌人与哪些层发生碰撞
@export var enemy_collision_mask: int = 2

@export_subgroup("战斗命中盒 · 扫描层")
## `CombatHitbox2D` 自身 `collision_layer`（须与敌人层不同，避免误挡移动）；**`collision_mask`** 由调用方设为「敌受击层」或「玩家受击层」二选一，避免玩家弹道误伤玩家、敌贴近误伤敌
@export var combat_hitbox_collision_layer: int = 8
## **`CombatHurtbox2D`**（挂在 **`CombatEnemy`** 上）所在层（位标志）；玩家弹道/爆炸 Hitbox 的 **`mask`** 指向本层
@export var combat_hurtbox_collision_layer: int = 16
## 挂在 **`CombatPlayer`** 上的受击盒所在层（位标志）；敌人 **`EnemyContactHitbox2D`** 的 **`mask`** 指向本层，与上项分离
@export var combat_player_hurtbox_collision_layer: int = 32

@export_subgroup("世界边界 · 地牢上下墙")
## 地牢上下 **`StaticBody2D`** 阻挡层（位标志）；与玩家 **`player_collision_mask`**、敌人生成 **`PhysicsPointQueryParameters2D.collision_mask`** 对齐
@export var world_barrier_collision_layer: int = 64

# =============================================================================
@export_group("其他")
@export_subgroup("索敌方案 · 弹道锁敌默认")
## `PlayEffectCommand.lock_target_kind < 0` 时 Runner 回退方案；须与 `TargetConfirmDefault.TargetConfirmScheme` 整型一致
@export_subgroup("Debug")
@export var debug_effect_plan_logging: bool = false

@export var ballistic_lock_default_scheme: int = 4
## 出厂 `PROJECTILE_VOLLEY` 写入 `cmd.lock_target_kind` 的推荐值
@export var ballistic_lock_scheme_projectile_volley: int = 4
## 出厂 `EXPLOSIVE_VOLLEY` 写入 `cmd.lock_target_kind` 的推荐值
@export var ballistic_lock_scheme_eight_explosive_volley: int = 4
## 圆查询类方案且 `lock_query_radius <= 0` 时的默认查询半径（像素）
@export var ballistic_lock_default_query_radius: float = 480.0

# =============================================================================
@export_group("音效 · 全局")
## 菜单/默认关卡 BGM、牌组打出与洗牌等；资源脚本为 **`GameGlobalAudioConfig`**（**`config/game_global_audio_config.tres`**）
@export var global_audio: Resource

# =============================================================================
@export_group("抽卡概率配置")
## 升级/开局等「三选一」展示用：按等级段稀有度表 + 幸运倾斜；具体抽牌见 `CardPool.draw_cards_for_weighted_offer`；脚本类型为 `CardDrawProbabilityConfig`
@export var card_draw_probability: Resource

# =============================================================================
@export_group("牌面配置")
## 四档稀有度对应牌面底图（绿→蓝→紫→金）；洗入牌库与测试造牌时由 `CardPool` 写入 `CardResource.front_texture`；脚本类型为 `CardFaceConfig`
@export var card_face_config: CardFaceConfig
