---
name: MeteorAttackDesign
overview: 为卡牌3新增“天外陨石”效果链路，保持现有牌型表驱动架构：牌型解析 -> effect_spec -> command -> runner，新增陨石命令与区域火焰逻辑并可配置。
todos:
  - id: define-meteor-spec-and-command
    content: 定义 ShapeMeteorStormEffectSpec 与 PlayEffectCommand.METEOR_STORM 字段/工厂
    status: completed
  - id: wire-assembler-and-runner
    content: 在装配器与 CombatEffectRunner 接入 METEOR_STORM 执行分支
    status: completed
  - id: implement-meteor-and-fire-zones
    content: 实现陨石动画关键帧伤害、对子二段爆炸、三条椭圆覆盖区、四条包围多边形火焰区
    status: completed
  - id: extract-point-sampler
    content: 将陨石目标点采样抽象到 projectile_tool_singleton 静态工具方法
    status: completed
  - id: update-card-shape-config
    content: 在 card_shape_config 增加 3/33/333/3333 条目（不新增 PlayShapeCatalog 外层陨石默认）
    status: completed
  - id: mcp-validation
    content: 用 Godot MCP 完成四档功能回归验证并检查编辑器错误
    status: completed
isProject: false
---

# 天外陨石实现方案

## 目标与已确认规则

- 默认把点数 `3` 接入新效果（单张/对子/三条/四条）。
- 随机落点区域使用**当前相机可见区域**，且排除墙体阻挡区域。
- 伤害触发采用**动画关键帧事件驱动**（`AnimationPlayer` 事件信号），确保伤害帧与落下动画对齐。

## 架构接入点

- 继续沿用现有链路，不做大重构：
  - 出牌事件 -> `PlayShapeTableResolver` 匹配牌型
  - `PlayShapeEffectAssembler` 把 `effect_spec` 装配为新命令
  - `CombatEffectRunner` 执行新命令，生成陨石节点
- 新增一类 `ShapeEffectSpec` 子类（建议：`ShapeMeteorStormEffectSpec`），在装配器中增加分支处理。
- 新增 `PlayEffectCommand.CmdKind`（建议：`METEOR_STORM`），并为其增加负载字段。
- 新增陨石表现节点脚本（建议：`scripts/combat/meteor_strike.gd`）与对应场景（建议：`scenes/combat/MeteorStrike.tscn`）。
- 职责边界调整：
  - 牌型侧（resolver/assembler/runner）只负责：确定落点、生成并发射陨石实例、把参数包传给陨石实例。
  - 陨石脚本负责：命中帧伤害、二段爆炸、火焰区域 DoT 等核心伤害逻辑。
- 配置复用策略（方案A）：
  - `shape_dic` 的 `"3"`, `"33"`, `"333"`, `"3333"` 可分别保留独立 `PlayShapeEntry`（便于展示名与调试），但 `effect_spec` 统一指向同一个 `ShapeMeteorStormEffectSpec` 子资源。
  - 装配时由 `ctx.cards.size()` 选择分档参数（1/2/3/4），避免四份全量配置重复。

## 具体行为设计（按3的张数）

- `3`（单张3）
  - 在相机可见区域内采样 3 个随机点，满足最小间距/最大间距约束。
  - 每点落 1 颗陨石；在“命中动画关键帧”触发一次圆形 AoE 伤害。
- `33`（两张3）
  - 同样 3 颗陨石。
  - 陨石体型放大（缩放系数）。
  - 每颗陨石结束时再触发一次更大范围爆炸（单次 AoE）。
- `333`（三张3）
  - 保持陨石落地伤害。
  - 额外在每颗陨石处生成圆形/椭圆形火焰覆盖区（DoT，`knockback=0`），持续时间完全跟随陨石持续时间。
- `3333`（四张3）
  - 保持陨石落地伤害。
  - 当陨石数量为3时：以三落点构成三角形，内部生成持续火焰区域（DoT，`knockback=0`）。
  - 当陨石数量超过3（受弹道数量加成）时：按所有落点的外侧包围轮廓连接生成覆盖区（多边形），并在该包围区域内持续施加 DoT（`knockback=0`）；持续时间完全跟随陨石持续时间。

## 随机落点与“无墙体”约束

- 目标点采样逻辑抽象到 `scripts/core/projectile_tool_singleton.gd`（不放入 `target_confirm_default.gd`，以保持“选敌”与“几何采样”职责分离）。
- 在 `CombatEffectRunner` 中调用工具方法，按当前 `Camera2D` 视口生成候选点。
- 通过物理查询过滤被墙体阻挡/非法点（使用 wall layer mask）。
- 落点采样策略：
  - 最多尝试 N 次
  - 满足点间最小距离与最大距
  - 失败时使用“最近合法候选回退”保证可发射。

建议新增静态方法（第一版）：

- `sample_points_in_rect_with_distance(rect, count, min_dist, max_attempts)`
- `filter_points_by_wall_overlap(points, wall_mask, query_radius)`
- `sample_points_in_camera_view_no_wall(camera, count, min_dist, max_attempts, wall_mask, query_radius)`

## 动画与伤害对齐实现

- `MeteorStrike.tscn` 使用 `AnimationPlayer`，在命中帧发 `impact_frame` 信号。
- `meteor_strike.gd` 监听该信号后调用统一伤害投递（复用 `CombatHitbox2D` / `CombatHitDelivery` 语义或等价范围查询+投递）。
- 通过配置控制：落下时长、伤害数值、DoT tick 间隔与每跳伤害；半径/覆盖形状/事件与音效资源由陨石场景与脚本单一来源控制。
- 场景实现约束：预留明确的场景槽位（陨石本体、预警层、命中层、火焰覆盖层、可选爆炸层），占位素材也优先在 `MeteorStrike.tscn` 内摆好，保证所见即所得。
- 绘制约束：尽量不在代码中动态创建/绘制图形；若必须动态变化，仅对场景中已存在节点做参数驱动（缩放、颜色、点集更新等）。

## card_shape_config 新增配置字段

- 文件：`config/card_shape_config.tres`（对应脚本 `scripts/cards/play_shape_catalog.gd`）

### 一、新增 ShapeMeteorStormEffectSpec 字段（牌型项可覆盖，并原样下发到陨石脚本）

- 基础发射
  - `meteor_count: int`（默认3）  
  中文注释：单次效果生成的陨石数量；当前需求固定为3，保留可调。
  - `projectile_count_bonus_scale: float`（默认0.5）  
  中文注释：投射物数量通用加成映射到陨石数量时的效率倍率；最终增量按 `floor(数量加成 * projectile_count_bonus_scale)` 取整。
  - `meteor_scene: PackedScene`  
  中文注释：陨石实例预制体；由 runner 实例化后交给陨石脚本执行伤害逻辑。
  - `meteor_lifetime_sec: float`（默认5.0）  
  中文注释：陨石完整存在时长；无二段爆炸时到时直接渐隐结束，并驱动火焰覆盖区结束时机。
  - `fall_duration_sec: float`  
  中文注释：陨石从生成到命中帧的下落时长（秒），用于控制手感与节奏。
  - `impact_damage: int`  
  中文注释：命中动画关键帧触发的基础范围伤害值。
- 落点采样
  - `sample_in_camera_view: bool`（固定 true）  
  中文注释：是否限定在当前相机可见区域内采样；本需求固定开启。
  - `point_min_distance: float`  
  中文注释：任意两个落点之间的最小距离约束，避免三个点过度重叠。
  - `point_max_distance: float`  
  中文注释：落点之间允许的最大距离约束，避免三个点过度分散。
  - `sample_max_attempts: int`  
  中文注释：随机采样最大尝试次数；超限后进入回退策略。
  - `wall_collision_mask: int`  
  中文注释：墙体层掩码；用于物理查询过滤不可落点区域。
- 对子增强（两张3）
  - `meteor_scale_mul_pair: float`  
  中文注释：对子3时的陨石体型倍率（相对基础体型）。
  - `enable_end_explosion_pair: bool`  
  中文注释：对子3是否在陨石结束阶段触发二段爆炸。
  - `end_explosion_damage_pair: int`  
  中文注释：对子3二段爆炸的伤害值。
- 三条增强（三张3）
  - `enable_ring_fire_triple: bool`  
  中文注释：三条3是否在陨石处生成火焰覆盖区（圆形/椭圆形）。
  - `meteor_lifetime_bonus_triple_sec: float`  
  中文注释：三条3对陨石持续时间的额外延长秒数；火焰覆盖区持续时间与陨石同步，不单独配置。
  - `ring_fire_dot_dps: int`  
  中文注释：火焰覆盖区持续伤害强度（DPS语义）。
  - `ring_fire_tick_interval_sec: float`  
  中文注释：火焰覆盖区 DoT 跳伤时间间隔（秒）。
- 四条增强（四张3）
  - `enable_triangle_fire_four: bool`  
  中文注释：四条3是否生成“多落点包围区域火焰”（3点时退化为三角形，>3点时为外轮廓多边形）。
  - `meteor_lifetime_bonus_four_sec: float`  
  中文注释：四条3对陨石持续时间的额外延长秒数；包围区域火焰持续时间与陨石同步，不单独配置。
  - `triangle_fire_dot_dps: int`  
  中文注释：包围区域火焰持续伤害强度（DPS语义）。
  - `triangle_fire_tick_interval_sec: float`  
  中文注释：包围区域火焰 DoT 跳伤时间间隔（秒）。
- 动画关键帧与表现
  - （迁移后不在 `ShapeMeteorStormEffectSpec` 配置）  
  中文注释：`impact_event_name`、`impact_sfx`、`explosion_sfx`、`fire_zone_scene` 统一由 `MeteorStrike.tscn` / `meteor_strike.gd` 内部管理。
- 分档覆盖（避免四份全量 spec）
  - `pair_`*：两张3差异参数（如体型、二段爆炸）
  - `triple_*`：三张3差异参数（如环形火焰）
  - `four_*`：四张3差异参数（如三角火焰）
  - 约定：`single` 使用基础参数；`pair/triple/four` 仅覆盖差异字段，未覆盖项继承基础参数。
  - 落地约束：`fall_duration_sec` 必须在 `meteor_strike.gd` 真实驱动动画时序（如 `AnimationPlayer.speed_scale` 或等价下落时长控制）；若实现阶段无法接入动画，则删除该字段，避免“无效配置”。
  - 职责约束：命中半径不在 `ShapeMeteorStormEffectSpec` 重复声明；由 `MeteorStrike.tscn`/`meteor_strike.gd` 作为单一配置来源控制，避免双配置源漂移。
  - 职责约束：对子二段爆炸半径不在 `ShapeMeteorStormEffectSpec` 重复声明；由 `MeteorStrike.tscn`/`meteor_strike.gd` 作为单一配置来源控制，避免与牌型层参数重复。
  - 职责约束：三条火焰覆盖形状与尺寸不在 `ShapeMeteorStormEffectSpec` 重复声明；直接在 `MeteorStrike.tscn` 内创建并由 `meteor_strike.gd` 驱动（圆形/椭圆形），避免牌型层与场景层双配置。
  - 职责约束：动画事件名与表现资源（命中音效、爆炸音效、火焰区域场景）全部内聚到陨石预制体与脚本，不再由牌型层配置下发。
  - 四条边界约束：若受数量加成导致陨石数 > 3，火焰区域按全部落点计算外侧包围多边形（建议凸包）而非固定三角形；3点时按原三角形处理。
  - 时长统一约束：三条火焰覆盖区与四条包围区域持续时间均完全跟随陨石持续时间，不再独立配置持续时间字段。
  - 升档覆盖约束：当四条效果生效时，陨石持续时间按四条延长规则（`meteor_lifetime_bonus_four_sec`）覆盖三条延长规则，不叠加双重延长。

### 二、shape_dic 新增键（默认作为3的效果）

- `"3"`, `"33"`, `"333"`, `"3333"` -> 四个 `PlayShapeEntry` 建议统一引用同一 `ShapeMeteorStormEffectSpec`（方案A）。
- 不建议为四个键各写一份全量 spec；只在需要彻底分离调参时再拆分为多 spec。

## 代码改动清单（实现时）

- `[scripts/cards/play_effect_command.gd](f:/TRAE_PROJECT/poker-survivor/scripts/cards/play_effect_command.gd)`
  - 新增 `CmdKind.METEOR_STORM`、字段与工厂方法。
- `[scripts/cards/play_shape_effect_assembler.gd](f:/TRAE_PROJECT/poker-survivor/scripts/cards/play_shape_effect_assembler.gd)`
  - 新增 `ShapeMeteorStormEffectSpec` 分支，按 `ctx.cards.size()` 合成“基础+分档覆盖”后的 `METEOR_STORM` 参数并装配命令。
- `[scripts/combat/combat_effect_runner.gd](f:/TRAE_PROJECT/poker-survivor/scripts/combat/combat_effect_runner.gd)`
  - 新增 `_spawn_meteor_storm(...)` 分发与执行。
- `[scripts/core/projectile_tool_singleton.gd](f:/TRAE_PROJECT/poker-survivor/scripts/core/projectile_tool_singleton.gd)`
  - 新增相机可见区随机点采样与墙体过滤静态方法，供陨石效果复用。
- 新增：`scripts/cards/shape_meteor_storm_effect_spec.gd`
- 新增：`scripts/combat/meteor_strike.gd` + `scenes/combat/MeteorStrike.tscn`
- 调整：三条椭圆火焰覆盖区与四条包围区域逻辑优先内聚到 `MeteorStrike.tscn`/`meteor_strike.gd`（直接在陨石场景创建与驱动），默认不新增独立 ring 脚本。
- `[config/card_shape_config.tres](f:/TRAE_PROJECT/poker-survivor/config/card_shape_config.tres)`
  - 新增 3 系列牌型条目，参数直接写在 `ShapeMeteorStormEffectSpec`（不新增 catalog 外层陨石默认字段）。

## 验证计划

- MCP 自动化（必做）
  - 启动 `RunScene`，用测试菜单或脚本构造 `3/33/333/3333`。
  - 断言：
    - 每档都生成 3 个落点且命中帧触发伤害。
    - `33` 有二段爆炸。
    - `333` 出椭圆火焰覆盖区 DoT 且无击退。
    - `3333` 在 3 颗陨石时为三角火焰；在数量加成后 >3 颗时为外轮廓包围多边形火焰，且均无击退。
  - 检查 editor errors 后 `stop_scene`。
- 静态检查
  - 改动脚本 `ReadLints` 无新增报错。

## 第一层通用加成接入规则（新增）

- 仅接入第一层通用加成：攻击力、攻击速度、范围、投射物数量加成；由装配阶段统一换算后下发给陨石实例。
- 投射物数量加成映射规则：  
`final_meteor_count = base_meteor_count + floor(projectile_count_bonus * projectile_count_bonus_scale)`，  
其中 `projectile_count_bonus_scale` 默认 `0.5`。
- 攻击速度映射规则：仅影响陨石下落节奏（`fall_duration_sec` 或等价动画速度），不影响 DoT tick 间隔。
- 范围加成映射规则：分两段生效——  
  1. 落下前：映射到落点采样距离约束（`point_min_distance` / `point_max_distance` 同倍率缩放）；  
  2. 落下后：映射到陨石投射物整体 `scale`（含命中、爆炸、火焰等随陨石节点缩放的覆盖范围）。  
  半径类细节参数仍不在牌型层重复声明。
- 攻击力映射规则：影响命中、二段爆炸、火焰 DoT 的伤害数值（同一乘区规则，避免额外特判）。
- 持续时间加成映射规则：作用于陨石效果全流程时长，直接乘/加到 `meteor_lifetime_sec`（再叠加当前档位的 `meteor_lifetime_bonus_*_sec`）；三条火焰覆盖区与四条包围区域自动跟随该最终时长。

