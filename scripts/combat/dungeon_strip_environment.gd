@tool
extends Node2D
## 地牢条带环境：根节点**保持在世界原点横向**（**`global_position.x` 不跟摄像机**），仅 **`BarriersXFollow`** 子节点每帧对齐摄像机 **X**，条图精灵用摄像机 **X** 做索引平铺，实现横向无限拼接；子节点 **`DefaultStripPreview`** 为编辑器内单块参考贴图。

## 循环底图；与条图竖向缩放一致
@export var dungeon_texture: Texture2D = preload("res://assets/sprites/scene/地牢场景2.png"):
	set(v):
		if dungeon_texture == v:
			return
		dungeon_texture = v
		_request_rebuild_background()
## 横向步长覆盖；**`≤0`** 时用 **`纹理宽 × 等比缩放`**
@export var chunk_step_world_override: float = 0.0:
	set(v):
		if is_equal_approx(chunk_step_world_override, v):
			return
		chunk_step_world_override = v
		_request_rebuild_background()
## 为真时条图竖向撑满 **`map_height`** + overscan
@export var fit_vertical_to_map: bool = true:
	set(v):
		if fit_vertical_to_map == v:
			return
		fit_vertical_to_map = v
		_request_rebuild_background()
## 在 **`map_height`** 上再增加的竖向总 overscan（像素）
@export var vertical_overscan_extra_total_px: float = 160.0:
	set(v):
		if is_equal_approx(vertical_overscan_extra_total_px, v):
			return
		vertical_overscan_extra_total_px = v
		_request_rebuild_background()
## 循环块数（奇数更稳）
@export var chunk_slot_count: int = 5:
	set(v):
		if chunk_slot_count == v:
			return
		chunk_slot_count = v
		_request_rebuild_background()

@export_group("可走区与墙")
## 为真且存在 **`Marker2D`** 时用标记 **Y** 驱动墙
@export var use_walkable_edge_markers: bool = true
## 无上标记时的顶墙碰撞中心本地 **Y**（相对 **`BarriersXFollow`**）
@export var top_barrier_center_y: float = 52.0
## 无下标记时底墙中心：**`map_height − bottom_barrier_offset_from_map_end`**
@export var bottom_barrier_offset_from_map_end: float = 52.0
## 单条碰撞半宽（像素）
@export var barrier_half_width_px: float = 12000.0
## 单条碰撞厚度（像素）
@export var barrier_thickness_px: float = 96.0

var _camera: Camera2D = null
## 仅横向跟随摄像机，承载顶/底 **`StaticBody2D`**，避免整条环境根节点随 **X** 拖动导致条图与 **`cx`** 双重偏移
var _barriers_x_follow: Node2D = null
var _top_body: StaticBody2D = null
var _bottom_body: StaticBody2D = null
## 可走区上/下内侧边线标记（子节点名固定）
var _marker_top: Marker2D = null
var _marker_bottom: Marker2D = null
## 场景内可选 **`Sprite2D`** **`DefaultStripPreview`**：编辑器中单块参考；运行时不参与循环
var _preview_sprite: Sprite2D = null
var _floor_sprites: Array[Sprite2D] = []
## 单块水平步长（缩放后纹理宽或覆盖值）
var _chunk_w: float = 1915.0
## 等比缩放
var _scale_uniform: float = 1.0
## 条图左上角 **Y**（相对本节点）
var _tile_origin_y: float = 0.0
## 顶底墙是否已创建
var _barriers_created: bool = false
## **`GameConfig.GAME_GLOBAL`** 在首帧尚未可用时的延迟建墙重试次数（**`@tool`** 场景下偶发）
var _barrier_init_deferred_attempts: int = 0
## 延迟建墙重试上限，避免永久 **`call_deferred`** 循环
const _BARRIER_INIT_DEFERRED_MAX: int = 32


## 供 **`RunScene`** 绑定摄像机；驱动横向条图索引与 **`BarriersXFollow`**
func setup_follow_camera(cam: Camera2D) -> void:
	_camera = cam


## 兼容旧调用名
func configure_barrier_camera(cam: Camera2D) -> void:
	setup_follow_camera(cam)


## 建议玩家/摄像机初始世界 **X**：单条条图水平中点，避免出生在左右两块竖缝处
func get_spawn_anchor_world_x() -> float:
	_compute_strip_layout()
	if dungeon_texture == null or _chunk_w < 1.0:
		var ggw: GameGlobalConfig = GameConfig.GAME_GLOBAL
		if ggw == null:
			return 0.0
		return ggw.world_width * 0.5
	return _chunk_w * 0.5


func _ready() -> void:
	add_to_group("dungeon_strip_playfield")
	_resolve_markers()
	_rebuild_background_sprites_if_needed()
	_ensure_static_barriers_once()
	_sync_barriers_from_walkable_markers()


func _process(_delta: float) -> void:
	if dungeon_texture == null:
		return
	var cx: float = 0.0
	if _camera != null and is_instance_valid(_camera):
		cx = _camera.global_position.x
	elif not Engine.is_editor_hint():
		return
	_sync_strip_sprite_positions(cx)
	if Engine.is_editor_hint():
		_sync_barriers_from_walkable_markers()


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _barriers_x_follow == null:
		return
	if _camera != null and is_instance_valid(_camera):
		_barriers_x_follow.global_position = Vector2(_camera.global_position.x, global_position.y)
	else:
		_barriers_x_follow.global_position = Vector2(0.0, global_position.y)


## 纹理或平铺参数变更时延迟重建
func _request_rebuild_background() -> void:
	call_deferred("_rebuild_background_sprites_if_needed")


## 解析标记、参考精灵
func _resolve_markers() -> void:
	_marker_top = get_node_or_null("TopWalkableEdge") as Marker2D
	_marker_bottom = get_node_or_null("BottomWalkableEdge") as Marker2D
	_preview_sprite = get_node_or_null("DefaultStripPreview") as Sprite2D
	if _marker_top != null:
		_marker_top.z_as_relative = false
		_marker_top.z_index = 40
	if _marker_bottom != null:
		_marker_bottom.z_as_relative = false
		_marker_bottom.z_index = 40


## 根据 **`dungeon_texture`** 与导出计算 **`_chunk_w`** 等（不分配精灵）
func _compute_strip_layout() -> void:
	if dungeon_texture == null:
		return
	## 编辑器 `@tool` 可能在 **`GameGlobalConfig`** 尚未成功预加载时即跑布局；缺表时跳过避免 Nil 报错
	var gg_cfg: GameGlobalConfig = GameConfig.GAME_GLOBAL
	if gg_cfg == null:
		return
	var tex_w: float = float(dungeon_texture.get_width())
	var tex_h: float = float(dungeon_texture.get_height())
	var map_h: float = gg_cfg.map_height
	var target_h: float = map_h + maxf(0.0, vertical_overscan_extra_total_px)
	if fit_vertical_to_map and tex_h > 0.01:
		_scale_uniform = target_h / tex_h
	else:
		_scale_uniform = 1.0
	_chunk_w = tex_w * _scale_uniform
	if chunk_step_world_override > 0.01:
		_chunk_w = chunk_step_world_override
	var drawn_h: float = tex_h * _scale_uniform
	_tile_origin_y = -0.5 * (drawn_h - map_h)


## 编辑器内仅显示 **`DefaultStripPreview`** 一块，避免与循环精灵叠画
func _apply_editor_layout_preview_sprite() -> void:
	if _preview_sprite == null or dungeon_texture == null:
		return
	_preview_sprite.texture = dungeon_texture
	_preview_sprite.centered = false
	_preview_sprite.scale = Vector2(_scale_uniform, _scale_uniform)
	_preview_sprite.position = Vector2(0.0, _tile_origin_y)
	_preview_sprite.z_as_relative = false
	_preview_sprite.z_index = -75
	_preview_sprite.visible = true


## 清空并重建循环条图；编辑器且存在 **`DefaultStripPreview`** 时只更新该精灵
func _rebuild_background_sprites_if_needed() -> void:
	for s: Node in _floor_sprites:
		if is_instance_valid(s):
			s.queue_free()
	_floor_sprites.clear()
	if dungeon_texture == null:
		return
	_compute_strip_layout()
	if Engine.is_editor_hint() and _preview_sprite != null and is_instance_valid(_preview_sprite):
		_apply_editor_layout_preview_sprite()
		return
	var n: int = maxi(3, chunk_slot_count | 1)
	for i in range(n):
		var sp := Sprite2D.new()
		sp.texture = dungeon_texture
		sp.centered = false
		sp.position = Vector2(float(i) * _chunk_w, _tile_origin_y)
		sp.scale = Vector2(_scale_uniform, _scale_uniform)
		sp.z_as_relative = false
		sp.z_index = -80
		add_child(sp)
		_floor_sprites.append(sp)
	z_as_relative = false
	z_index = -200
	if _preview_sprite != null:
		_preview_sprite.visible = false


## 创建 **`BarriersXFollow`** 与顶底墙（墙为跟随器子节点）
func _ensure_static_barriers_once() -> void:
	if _barriers_created:
		return
	_barriers_x_follow = Node2D.new()
	_barriers_x_follow.name = "BarriersXFollow"
	add_child(_barriers_x_follow)
	var gg: GameGlobalConfig = GameConfig.GAME_GLOBAL
	if gg == null:
		## 与 `_compute_strip_layout` 一致：全局表未就绪时不创建墙，避免 **Nil**；下一帧再试直至成功或达上限
		_barriers_created = false
		_barriers_x_follow.queue_free()
		_barriers_x_follow = null
		_barrier_init_deferred_attempts += 1
		if _barrier_init_deferred_attempts < _BARRIER_INIT_DEFERRED_MAX:
			call_deferred("_ensure_static_barriers_once")
		return
	var layer: int = gg.world_barrier_collision_layer
	var map_h: float = gg.map_height
	var half_w: float = barrier_half_width_px
	var th: float = barrier_thickness_px
	var shape_top := RectangleShape2D.new()
	shape_top.size = Vector2(half_w * 2.0, th)
	var shape_bot := RectangleShape2D.new()
	shape_bot.size = Vector2(half_w * 2.0, th)
	_top_body = StaticBody2D.new()
	_top_body.name = "TopBarrier"
	_top_body.collision_layer = layer
	_top_body.collision_mask = 0
	_top_body.position = Vector2(0.0, top_barrier_center_y)
	var cs_top := CollisionShape2D.new()
	cs_top.shape = shape_top
	_top_body.add_child(cs_top)
	_barriers_x_follow.add_child(_top_body)
	_bottom_body = StaticBody2D.new()
	_bottom_body.name = "BottomBarrier"
	_bottom_body.collision_layer = layer
	_bottom_body.collision_mask = 0
	_bottom_body.position = Vector2(0.0, map_h - bottom_barrier_offset_from_map_end)
	var cs_bot := CollisionShape2D.new()
	cs_bot.shape = shape_bot
	_bottom_body.add_child(cs_bot)
	_barriers_x_follow.add_child(_bottom_body)
	_barriers_created = true
	_barrier_init_deferred_attempts = 0


## 按标记或导出更新顶底墙 **Y**
func _sync_barriers_from_walkable_markers() -> void:
	if _top_body == null or _bottom_body == null:
		return
	var gg_sync: GameGlobalConfig = GameConfig.GAME_GLOBAL
	if gg_sync == null:
		return
	var half_th: float = barrier_thickness_px * 0.5
	var map_h: float = gg_sync.map_height
	if use_walkable_edge_markers and _marker_top != null:
		var top_inner_y: float = _marker_top.position.y
		top_barrier_center_y = top_inner_y - half_th
		_top_body.position.y = top_barrier_center_y
	else:
		_top_body.position.y = top_barrier_center_y
	if use_walkable_edge_markers and _marker_bottom != null:
		var bottom_inner_y: float = _marker_bottom.position.y
		_bottom_body.position.y = bottom_inner_y + half_th
	else:
		_bottom_body.position.y = map_h - bottom_barrier_offset_from_map_end


## 以世界 **X** 参考 **`cx`**（摄像机）更新各块本地 **X**；根节点世界 **X** 恒为 **0** 时，块世界坐标为 **`idx * chunk_w`**
func _sync_strip_sprite_positions(cx: float) -> void:
	if _chunk_w < 0.01:
		return
	var center_i: int = int(floorf(cx / _chunk_w))
	var n_floor: int = _floor_sprites.size()
	## 用位移避免 **`/`** 在整型上的除法告警，语义仍为「块数的一半」向下取整
	var half_floor: int = n_floor >> 1
	for i in range(n_floor):
		var idx: int = center_i - half_floor + i
		var sp: Sprite2D = _floor_sprites[i]
		if sp != null and is_instance_valid(sp):
			sp.position.x = float(idx) * _chunk_w
			sp.position.y = _tile_origin_y


## 敌人脚点允许 **Y** 区间 **[min,max]**
func get_playable_feet_y_span_world(extra_margin_px: float = 0.0) -> Vector2:
	var gg_play: GameGlobalConfig = GameConfig.GAME_GLOBAL
	if gg_play == null:
		return Vector2.ZERO
	var map_h: float = gg_play.map_height
	var half_th: float = barrier_thickness_px * 0.5
	var y_top_inner: float
	var y_bottom_inner: float
	if use_walkable_edge_markers and _marker_top != null:
		y_top_inner = _marker_top.position.y
	else:
		y_top_inner = top_barrier_center_y + half_th
	if use_walkable_edge_markers and _marker_bottom != null:
		y_bottom_inner = _marker_bottom.position.y
	else:
		y_bottom_inner = (map_h - bottom_barrier_offset_from_map_end) - half_th
	var y_min: float = y_top_inner + extra_margin_px
	var y_max: float = y_bottom_inner - extra_margin_px
	if y_max <= y_min + 8.0:
		return Vector2(maxf(0.0, map_h * 0.25), maxf(y_min + 16.0, map_h * 0.75))
	return Vector2(y_min, y_max)
