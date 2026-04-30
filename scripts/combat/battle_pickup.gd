extends Node2D
class_name BattlePickup
## 战场可拾取物：由 **`PickupCollector`**（玩家子节点）驱动磁力与收集；本节点仅持 **`pickup_kind` 标签**与效果 **`Resource`**（**`pickup_effect_config.gd`**）。


## 用于 UI / 统计 / 音效路由的标签（**权威执行见 `effect`**）
enum PickupKind {
	EXPERIENCE,
	EQUIPMENT,
	ITEM,
}

## 拾取分类标签
@export var pickup_kind: PickupKind = PickupKind.EXPERIENCE
## 拾取时效果（**`PickupEffectConfig`** 资源；**`Variant`** 避免 LSP 跨脚本 **`class_name`** 顺序问题）
@export var effect: Variant = null
## 血包等：非空时显示精灵并隐藏 **`IconLabel`**
@export var icon_texture: Texture2D = null
## 是否允许被 PickupCollector 远距离磁吸；精英奖励卡牌会关闭该选项。
@export var magnet_enabled: bool = true

@onready var _icon_sprite: Sprite2D = get_node_or_null("IconSprite") as Sprite2D
@onready var _icon_label: Label = get_node_or_null("IconLabel") as Label


## 供 **`PickupCollector`** 读取效果资源（须含 **`apply(CombatPlayer)`**）
func get_pickup_effect() -> Variant:
	return effect


## 返回本拾取物是否允许远距离磁吸。
func can_be_magnetized() -> bool:
	return magnet_enabled


## 进组并刷新可选图标（**`HealthPickup`** 等子节点）
func _ready() -> void:
	add_to_group("battle_pickups")
	if effect == null:
		push_warning("BattlePickup: effect 未配置，拾取无效果 | node=%s" % name)
	_apply_icon_texture_visibility()


## 与旧血包一致：有 **`icon_texture`** 则显 Sprite 隐 Label
func _apply_icon_texture_visibility() -> void:
	if _icon_sprite != null and icon_texture != null:
		_icon_sprite.texture = icon_texture
		_icon_sprite.visible = true
		if _icon_label != null:
			_icon_label.visible = false
	else:
		if _icon_sprite != null:
			_icon_sprite.visible = false
		if _icon_label != null:
			_icon_label.visible = true
