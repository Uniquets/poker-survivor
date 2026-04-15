class_name CombatTuning
extends RefCounted
## 战斗、地图、生成与数值常量集中配置（无逻辑，仅常量）

const WORLD_WIDTH: float = 1280.0 ## 设计视口宽（像素）
const WORLD_HEIGHT: float = 720.0 ## 设计视口高（像素）
const MAP_WIDTH: float = 4000.0 ## 可玩地图宽（像素）
const MAP_HEIGHT: float = 4000.0 ## 可玩地图高（像素）
const CAMERA_FOLLOW_MARGIN_X: float = 220.0 ## 摄像机相对玩家水平死区半宽
const CAMERA_FOLLOW_MARGIN_Y: float = 140.0 ## 摄像机相对玩家垂直死区半高
const PLAYER_DRAW_RADIUS: float = 14.0 ## 玩家 _draw 圆圈半径
const ENEMY_DRAW_RADIUS: float = 10.0 ## 敌人 _draw 圆圈半径
const ENEMY_COLLIDER_SCALE: float = 0.2 ## 敌人碰撞体缩放（若场景使用）

const PLAYER_COLLISION_LAYER: int = 1 ## 玩家碰撞层位
const PLAYER_COLLISION_MASK: int = 0 ## 玩家碰撞掩码
const ENEMY_COLLISION_LAYER: int = 2 ## 敌人碰撞层位
const ENEMY_COLLISION_MASK: int = 2 ## 敌人碰撞掩码

const PLAYER_MOVE_SPEED: float = 240.0 ## 玩家移动速度（像素/秒）
const PLAYER_MAX_HEALTH: int = 100000 ## 玩家默认最大生命
const PLAYER_CONTACT_DAMAGE_COOLDOWN_SECONDS: float = 0.6 ## 玩家受接触伤害最短间隔（秒）

const ENEMY_MOVE_SPEED: float = 120.0 ## 敌人追击速度（像素/秒）
const ENEMY_TOUCH_DAMAGE: int = 10 ## 敌人接触玩家单次伤害
const ENEMY_MAX_HEALTH: int = 30 ## 敌人默认最大生命

const PLAYER_AUTO_ATTACK_INTERVAL_SECONDS: float = 0.8 ## 无卡时自动射击间隔（秒）
const PLAYER_AUTO_ATTACK_DAMAGE: int = 10 ## 无卡时自动射击单发伤害

const ENEMY_SPAWN_INTERVAL_SECONDS: float = 1.5 ## 敌人生成间隔（秒）
const ENEMY_MAX_ALIVE: int = 12 ## 场上敌人数量上限
const ENEMY_SPAWN_RADIUS: float = 340.0 ## 敌人生成相对玩家的半径（像素）
