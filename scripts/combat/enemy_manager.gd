extends Node
class_name EnemyManager
## 在玩家周围按间隔生成敌人，并限制场上最大数量

## 进程内当前敌人管理器引用（`_enter_tree` 写入、`_exit_tree` 清空）；本局仅应存在一个 `EnemyManager`；其它脚本经 `preload` 后调用 `get_enemy_manager()` 或读此字段
static var enemy_manager_singleton: EnemyManager = null


## 返回当前已注册的全局敌人管理器；未进树或已出场时为 null（跨脚本请 `preload("enemy_manager.gd")` 再调本方法）
static func get_enemy_manager() -> EnemyManager:
	return enemy_manager_singleton


## 敌人场景预制
@export var enemy_scene: PackedScene
## 生成间隔（秒）
@export var spawn_interval_seconds: float = CombatTuning.ENEMY_SPAWN_INTERVAL_SECONDS
## 场上敌人数量上限
@export var max_alive_enemies: int = CombatTuning.ENEMY_MAX_ALIVE
## 相对目标生成半径（像素）
@export var spawn_radius: float = CombatTuning.ENEMY_SPAWN_RADIUS
## 追击目标节点（通常为玩家）
@export var target: Node2D

## 距上次生成累计秒数
var _spawn_timer := 0.0
## 是否允许生成
var _active := true


## 进入场景树时注册为全局单例（供 `CombatEffectRunner`、索敌等获取）
func _enter_tree() -> void:
	if enemy_manager_singleton != null and is_instance_valid(enemy_manager_singleton) and enemy_manager_singleton != self:
		push_warning("EnemyManager: 重复注册全局单例，将覆盖为当前节点")
	enemy_manager_singleton = self


## 离开场景树时注销单例
func _exit_tree() -> void:
	if enemy_manager_singleton == self:
		enemy_manager_singleton = null


## 初始化随机种子
func _ready() -> void:
	randomize()


## 计时满足且未达上限时生成一只怪
func _process(delta: float) -> void:
	if not _active:
		return
	if enemy_scene == null or not is_instance_valid(target):
		return
	if get_child_count() >= max_alive_enemies:
		return

	_spawn_timer += delta
	if _spawn_timer < spawn_interval_seconds:
		return

	_spawn_timer = 0.0
	_spawn_enemy()


## 开关生成逻辑（选牌阶段可关）
func set_active(active: bool) -> void:
	_active = active


## 在目标周围随机角度摆一只敌人并设 target
func _spawn_enemy() -> void:
	var enemy := enemy_scene.instantiate()
	if enemy == null:
		return

	var random_direction := Vector2.RIGHT.rotated(randf_range(0.0, TAU))
	enemy.global_position = target.global_position + random_direction * spawn_radius
	enemy.target = target
	add_child(enemy)

	print("[spawn] enemy_spawned | count=%d" % get_child_count())
