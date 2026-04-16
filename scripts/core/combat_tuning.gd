extends RefCounted
class_name CombatTuning
## 战斗、地图、生成与数值常量集中配置（无逻辑，仅常量）

## -----------------------------------------------------------------------------
## 本文件维护规则（后续增删常量请遵守）
## -----------------------------------------------------------------------------
## 1. 只放 `const` 与分组注释，不写可执行逻辑；命名用 `SCREAMING_SNAKE_CASE`。
## 2. 分区：先「世界 / 实体 / 生成」等通用战斗底架，再「关键张 · 点数 2/8/10」，最后「组牌回落」「弹道锁敌」等横切能力。
## 3. 关键张（2 / 8 / 10）下必须按 **`_fill_rank_*_commands` 里 `n = ctx.cards.size()`** 与玩法分支来写注释，并尽量按下述子档分组（与点数 8 已采用的结构一致）：
##    - **影响所有张数**：任意 `n` 都参与（或 Runner 里凡走该命令即生效）的常量；
##    - **仅单张（n=1） / 仅对子（n=2） / 仅三条（n=3） / 仅四条（n=4）**：只在该 `match n` 分支用到的常量；
##    - 若同一数值被多个 `n` 共用（如 8 点三条与四条共伤害倍率），在「靠前」子档写常量，在靠后子档用一行 `##` 说明「见上」避免重复定义。
## 4. 每个大分区用 `# ==========` 折行；子档用 `## —— … ——`；行尾 `##` 写清单位、公式或与哪段脚本对应。
## 5. 改名或改值后：全局搜索旧符号；关键张数值变更建议对照 `PlayEffectResolver` / `CombatEffectRunner` 冒烟。
## -----------------------------------------------------------------------------

# =============================================================================
## 【视口与地图】设计分辨率与可玩地图范围（像素）
# =============================================================================
## 与 UI/摄像机设计分辨率、可滚动战场尺寸相关；不直接等价于窗口像素比。
const WORLD_WIDTH: float = 1280.0 ## 设计视口宽
const WORLD_HEIGHT: float = 720.0 ## 设计视口高
const MAP_WIDTH: float = 4000.0 ## 可玩地图宽
const MAP_HEIGHT: float = 4000.0 ## 可玩地图高

# =============================================================================
## 【摄像机】跟随死区（相对玩家，像素）
# =============================================================================
## 玩家在死区内移动时摄像机可不平移，超出半宽/半高后再跟随。
const CAMERA_FOLLOW_MARGIN_X: float = 220.0 ## 水平死区半宽
const CAMERA_FOLLOW_MARGIN_Y: float = 140.0 ## 垂直死区半高

# =============================================================================
## 【调试绘制】占位半径与缩放（若场景使用）
# =============================================================================
const PLAYER_DRAW_RADIUS: float = 14.0 ## 玩家 `_draw` 圆半径（像素）
const ENEMY_DRAW_RADIUS: float = 10.0 ## 敌人 `_draw` 圆半径（像素）
const ENEMY_COLLIDER_SCALE: float = 0.2 ## 敌人碰撞体相对默认的缩放系数

# =============================================================================
## 【碰撞层】物理层位与掩码（位标志，与 Godot 层设置一致）
# =============================================================================
const PLAYER_COLLISION_LAYER: int = 1 ## 玩家所在层
const PLAYER_COLLISION_MASK: int = 0 ## 玩家检测哪些层（0 表示由场景细配时可改）
const ENEMY_COLLISION_LAYER: int = 2 ## 敌人所在层
const ENEMY_COLLISION_MASK: int = 2 ## 敌人与哪层发生碰撞

# =============================================================================
## 【玩家】移动、默认生命、受击节奏
# =============================================================================
const PLAYER_MOVE_SPEED: float = 240.0 ## 移动速度（像素/秒）
const PLAYER_MAX_HEALTH: int = 100000 ## 默认最大生命（点）
const PLAYER_CONTACT_DAMAGE_COOLDOWN_SECONDS: float = 0.6 ## 受敌人接触伤害的最短间隔（秒）

# =============================================================================
## 【敌人】单敌体移动与战斗基底（非波次配置）
# =============================================================================
const ENEMY_MOVE_SPEED: float = 120.0 ## 追击速度（像素/秒）
const ENEMY_TOUCH_DAMAGE: int = 10 ## 单次接触对玩家伤害
const ENEMY_MAX_HEALTH: int = 30 ## 默认最大生命（点）

# =============================================================================
## 【敌人生成】波次节奏与场上上限（相对玩家极坐标生成）
# =============================================================================
const ENEMY_SPAWN_INTERVAL_SECONDS: float = 1.5 ## 生成尝试间隔（秒）
const ENEMY_MAX_ALIVE: int = 12 ## 场上敌人数量上限
const ENEMY_SPAWN_RADIUS: float = 340.0 ## 生成位置距玩家的半径（像素）

# =============================================================================
## 【关键张 · 点数 2】`_fill_rank_two_commands`：`n` 为同点数打出张数（1～4）
# =============================================================================
## 下列子档与 `match n` 分支一致；`n=1～3` 为 `PROJECTILE_VOLLEY`，`n=4` 为 `LASER_DUAL_BURST`。

## —— 影响所有使用多发弹道的张数（n=1～3）：每发伤害、基底扇角、Runner 并行线距、`volley` 强化枚数下限 ——
## 并行线距公式见 `ProjectileToolSingleton.compute_parallel_layout`：基数 + `spread_deg` * 系数（与 EffectResolver 回落的同类弹道共用 Runner 路径）。
const RANK_TWO_VOLLEY_DAMAGE_PER_HIT: int = 8 ## 每发弹道伤害
const RANK_TWO_VOLLEY_SPREAD_DEG: float = 6.0 ## 侧向排开发射展开角基底（度）
const RANK_TWO_VOLLEY_PARALLEL_LINE_BASE: float = 14.0 ## 并行线距基数（像素）
const RANK_TWO_VOLLEY_PARALLEL_LINE_PER_SPREAD_DEG: float = 0.35 ## 与展开角相乘的线距增量系数
const RANK_TWO_GLOBAL_AUGMENT_MIN_PROJECTILE_VOLLEY_COUNT: int = 1 ## `volley_count_bonus` 写入后 `PROJECTILE_VOLLEY` 枚数下限（回落管线同类命令共用）
const RANK_TWO_VOLLEY_LOCK_QUERY_RADIUS: float = 1000 ## 弹道锁敌半径（像素）

## —— 仅单张（n=1）：双发弹道总发数与扇角倍率 ——
const RANK_TWO_VOLLEY_COUNT_SINGLE: int = 2
const RANK_TWO_VOLLEY_SPREAD_MUL_SINGLE: float = 1.0 ## 乘在 `RANK_TWO_VOLLEY_SPREAD_DEG` 上

## —— 仅对子（n=2）：四发弹道与扇角倍率 ——
const RANK_TWO_VOLLEY_COUNT_PAIR: int = 4
const RANK_TWO_VOLLEY_SPREAD_MUL_PAIR: float = 1.25

## —— 仅三条（n=3）：六发弹道与扇角倍率 ——
const RANK_TWO_VOLLEY_COUNT_TRIPLE: int = 6
const RANK_TWO_VOLLEY_SPREAD_MUL_TRIPLE: float = 1.5

## —— 仅四条（n=4）：双发激光每跳伤害与持续 ——
const RANK_TWO_LASER_TICK_DAMAGE: int = 22 ## 激光每跳伤害
const RANK_TWO_LASER_DURATION_SECONDS: float = 0.1 ## 激光持续（秒）

## —— 与激光/总伤估算及强化道数下限相关（命令为 `LASER_DUAL_BURST` 时）——
const RANK_TWO_DAMAGE_HINT_LASER_TICK_INTERVAL_SEC: float = 0.1 ## `_recalc_damage_hint` 假定跳间隔（秒），与表现 tick 对齐
const RANK_TWO_DAMAGE_HINT_LASER_TICK_FLOOR_EPSILON: float = 0.001 ## `floor(duration/tick)` 防浮点误差
const RANK_TWO_GLOBAL_AUGMENT_MIN_LASER_DUAL_BURST_BEAMS: int = 2 ## `volley_count_bonus` 写入后激光道数下限

# =============================================================================
## 【关键张 · 点数 8】`_fill_rank_eight_commands` + `CombatEffectRunner`：`n` 为 1～4
# =============================================================================
## 下列按「与张数关系」分组。

## —— 影响所有张数（n=1～4）：扇形布局、载荷速度、展开角随 n、爆炸半径/伤害基底、爆炸连发强化枚数下限 ——
## 扇形弹道总扫角：`compute_angular_fan_layout` = 基数 + `spread_deg` * 系数
const RANK_EIGHT_ANGULAR_FAN_ARC_BASE_DEG: float = 32.0 ## 扇形总角度基数（度）
const RANK_EIGHT_ANGULAR_FAN_ARC_PER_SPREAD_DEG: float = 1.15 ## 与命令中 `spread_deg` 相乘的扫角增量
const RANK_EIGHT_PAYLOAD_SPEED: float = 680.0 ## 红色闪烁载荷飞行速度（像素/秒）
const RANK_EIGHT_PAYLOAD_SPREAD_BASE_DEG: float = 14.0 ## 侧向展开角基数（度）
const RANK_EIGHT_PAYLOAD_SPREAD_EXTRA_PER_CARD: float = 0.15 ## 展开角公式 `(1 + 本系数 * (n-1))` 中每多一张牌的增量
const RANK_EIGHT_EXPLOSION_BASE_RADIUS: float = 92.0 ## 爆炸命中半径基底（像素）；对子再乘下方「一对」倍率
const RANK_EIGHT_EXPLOSION_MIN_DAMAGE: int = 16 ## 爆炸伤害与牌面 damage 取大时的下限
const RANK_EIGHT_GLOBAL_AUGMENT_MIN_EXPLOSIVE_VOLLEY_COUNT: int = 1 ## `EIGHT_EXPLOSIVE_VOLLEY` 叠加强化后枚数下限

## —— 仅对子（n=2）：放大爆炸半径，不提高伤害倍率 ——
const RANK_EIGHT_PAIR_RADIUS_MUL: float = 1.45 ## `最终爆炸半径 = 基底半径 * 本倍率`

## —— 三条与四条（n=3、4）：爆炸伤害倍率相同；四条另见下一档灼地 ——
const RANK_EIGHT_TRIPLE_DAMAGE_MUL: float = 2.0 ## `爆炸伤害 = round(基底伤害 * 本倍率)`；常量名沿用「三条」历史命名

## —— 仅四条（n=4）：灼地参数与总伤提示阈值 ——
const RANK_EIGHT_BURN_RADIUS_SCALE: float = 1.05 ## 灼地圈半径 = 当前爆炸命中半径 * 本比例
const RANK_EIGHT_BURN_GROUND_SECONDS: float = 4.0 ## 灼地持续（秒）
const RANK_EIGHT_BURN_GROUND_DPS: int = 6 ## 灼地每秒伤害
const RANK_EIGHT_DAMAGE_HINT_BURN_DURATION_THRESHOLD_SEC: float = 0.05 ## `_recalc_damage_hint`：灼地须超过本时长（秒）才计入
const RANK_EIGHT_DAMAGE_HINT_RADIUS_MUL_FOR_BURN: float = 1.0 ## 且须 `radius_mul > 本值` 才计灼地额外段

# =============================================================================
## 【关键张 · 点数 10】`_fill_rank_ten_commands`：治疗与无敌（逻辑相），`n` 为 1～4
# =============================================================================

## —— 仅单张（n=1）：比例治疗 ——
const RANK_TEN_HEAL_PERCENT_SINGLE: float = 0.10 ## 相对 `player_max_health` 的治疗比例

## —— 仅对子（n=2）：比例治疗 ——
const RANK_TEN_HEAL_PERCENT_PAIR: float = 0.30

## —— 仅三条（n=3）：比例治疗 + 无敌时长 ——
const RANK_TEN_HEAL_PERCENT_TRIPLE: float = 0.50
const RANK_TEN_INVULNERABLE_SECONDS_TRIPLE: float = 2.0 ## 无敌（秒）

## —— 仅四条（n=4）：满额治疗 + 更长无敌 ——
const RANK_TEN_HEAL_PERCENT_FOUR: float = 1.0 ## 相对最大生命的治疗比例（满额）
const RANK_TEN_INVULNERABLE_SECONDS_FOUR: float = 5.0 ## 无敌（秒）

# =============================================================================
## 【组牌回落】非 2/8/10 关键张时 `EffectResolver` 转 `PROJECTILE_VOLLEY` 的默认散布（度）
# =============================================================================
## 当前为 0 表示无扇角；`volley_count_bonus` 枚数下限见点数 2 档「多发弹道」与回落共用常量。
const LEGACY_EFFECT_PROJECTILE_SPREAD_DEG: float = 0.0

# =============================================================================
## 【弹道锁敌】首发方案与查询半径默认值（与 `TargetConfirmDefault.TargetConfirmScheme` 整型一致）
# =============================================================================
## `PlayEffectCommand.lock_target_kind < 0` 时 Runner 回退方案；**数值须与** `TargetConfirmDefault.TargetConfirmScheme.NEAREST_IN_RADIUS` **一致**（当前为 4）。
const BALLISTIC_LOCK_DEFAULT_SCHEME: int = 4
## 出厂 **`PROJECTILE_VOLLEY`**（点数 2 多发与 EffectResolver 回落）时写入 `cmd.lock_target_kind` 的推荐值，与上项同
const BALLISTIC_LOCK_SCHEME_PROJECTILE_VOLLEY: int = 4
## 出厂 **`EIGHT_EXPLOSIVE_VOLLEY`** 时写入 `cmd.lock_target_kind` 的推荐值，与上项同
const BALLISTIC_LOCK_SCHEME_EIGHT_EXPLOSIVE_VOLLEY: int = 4
## 当命令使用圆查询类方案且 `lock_query_radius <= 0` 时使用的查询半径（像素）
const BALLISTIC_LOCK_DEFAULT_QUERY_RADIUS: float = 480.0
