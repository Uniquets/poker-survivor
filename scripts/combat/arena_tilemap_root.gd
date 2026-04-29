extends Node2D
## 战斗场地瓦片根节点：分层 **`TileMapLayer`**（地面 / 墙体占位）；可选开局铺满占位格；默认关闭以便 **`DungeonStripEnvironment`** 作为地牢主底图。

## 为真时 **`_ready`** 按地图尺寸铺满 **`Ground`**；地牢主流程可关，仅保留 **`TileMapLayer`** 供手绘墙/地
@export var fill_ground_on_ready: bool = false
## 单格边长（像素），须与 **`TileSet.tile_size`** 一致
@export var cell_size_px: int = 32
## **`TileSet`** 中用于地面的 **`source_id`**（当前图集仅 `0`）
@export var ground_source_id: int = 0
## 占位地面使用的图集坐标（整张 `地面+墙面.png` 顶部可能含标签/留白，若裁歪了可在检查器改此值）
@export var ground_atlas_coords: Vector2i = Vector2i(0, 0)

@onready var _ground: TileMapLayer = $Ground
@onready var _walls: TileMapLayer = $Walls


func _ready() -> void:
	if fill_ground_on_ready:
		_fill_ground_from_config()


## 按全局配置的 **`map_width` / `map_height`** 用 **`ground_atlas_coords`** 单瓦铺满 **`Ground`** 层（占位）；**`Walls`** 留空供后续摆墙或第二套 TileSet。
func _fill_ground_from_config() -> void:
	if _ground == null:
		return
	var gg: GameGlobalConfig = GameConfig.GAME_GLOBAL
	var tw: int = int(ceili(gg.map_width / float(cell_size_px)))
	var th: int = int(ceili(gg.map_height / float(cell_size_px)))
	_ground.clear()
	for x in range(tw):
		for y in range(th):
			_ground.set_cell(Vector2i(x, y), ground_source_id, ground_atlas_coords)
