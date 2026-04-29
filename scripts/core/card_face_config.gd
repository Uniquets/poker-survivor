extends Resource
class_name CardFaceConfig
## 四档稀有度牌面底图（低→高：绿、蓝、紫、金），与 `CardDrawProbabilityConfig` 稀有度 0～3 一一对应
## 由 `GameGlobalConfig.card_face_config` 引用；`CardPool` 在洗入/造牌时写入 `CardResource.front_texture`

## 四档纹理与稀有度 0～3 一一对应；空则该档无牌面
@export_subgroup("稀有度 0～3（绿 → 蓝 → 紫 → 金）")
## 稀有度 0（最低档）
@export var face_green: Texture2D
## 稀有度 1
@export var face_blue: Texture2D
## 稀有度 2
@export var face_purple: Texture2D
## 稀有度 3（最高档）
@export var face_gold: Texture2D


## 按稀有度档 0～3 取牌面纹理；未配置时返回 null
func get_texture_for_rarity_tier(tier: int) -> Texture2D:
	var t: int = clampi(tier, 0, 3)
	match t:
		0:
			return face_green
		1:
			return face_blue
		2:
			return face_purple
		3:
			return face_gold
		_:
			return null
