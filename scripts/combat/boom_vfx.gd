extends AnimatedSprite2D
## 爆炸序列帧表现：播放 `SpriteFrames` 首段动画（须 **非循环**），`animation_finished` 后自毁；与 `explosion_one_shot` 逻辑节点分离挂载，**不在代码里改帧/速度**（所见即所得）


## 绑定首段动画播放结束回调并自毁
func _ready() -> void:
	if sprite_frames == null:
		queue_free()
		return
	var anims: PackedStringArray = sprite_frames.get_animation_names()
	if anims.is_empty():
		queue_free()
		return
	var anim_name: String = String(anims[0])
	if not sprite_frames.has_animation(anim_name):
		queue_free()
		return
	if sprite_frames.get_animation_loop(anim_name):
		push_warning("boom_vfx: SpriteFrames 动画应关闭 loop，否则无法结束自毁")
	play(anim_name)
	animation_finished.connect(queue_free, CONNECT_ONE_SHOT)
