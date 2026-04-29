extends RefCounted
class_name GameConfig

## 战斗默认表现（弹道回落预制、默认音画、击退衰减等，`res://config/combat_presentation_defaults.tres`）；**`Resource`** 避免与 **`class_name`** 解析顺序环导致 **`GameConfig`** 自身无法解析
static var COMBAT_PRESENTATION: Resource = preload("res://config/combat_presentation_defaults.tres")
## 战斗数值策划表（并行/航点/爆炸/治疗等，`res://config/combat_mechanics_tuning.tres`）
static var COMBAT_MECHANICS: Resource = preload("res://config/combat_mechanics_tuning.tres")
## 玩家基底数值表（`res://config/player_basics_config.tres`）
static var PLAYER_BASICS: PlayerBasicsConfig = preload("res://config/player_basics_config.tres") as PlayerBasicsConfig
## 全局地图/物理/索敌、抽卡概率、牌面等（`res://config/game_global_config.tres`）；**不含**牌型表（见下项）
static var GAME_GLOBAL: GameGlobalConfig = preload("res://config/game_global_config.tres") as GameGlobalConfig
## 同点数牌型表（`res://config/card_shape_config.tres`）；策划另存 **`.tres`** 后改此处 **`preload`** 路径即可；与 **`GAME_GLOBAL`** 解耦，避免嵌套进全局表资源
static var PLAY_SHAPE_CATALOG: PlayShapeCatalog = preload("res://config/card_shape_config.tres") as PlayShapeCatalog
## 敌人表（`res://config/enemy_config.tres`）
static var ENEMY_CONFIG: EnemyConfig = preload("res://config/enemy_config.tres") as EnemyConfig
