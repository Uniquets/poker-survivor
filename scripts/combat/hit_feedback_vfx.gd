extends Node2D
## 打击反馈：播放子节点 `AnimatedSprite2D` 首段非循环动画后整节点自毁；与 `boom_vfx.gd` 同约定，根节点为容器


## 职责：启动子节点序列帧首段动画，结束后销毁根节点；帧资源与速度仅在场景中配置
func _ready() -> void:
	var asp := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if asp == null or asp.sprite_frames == null:
		queue_free()
		return
	var anims: PackedStringArray = asp.sprite_frames.get_animation_names()
	if anims.is_empty():
		queue_free()
		return
	var anim_name: String = String(anims[0])
	if not asp.sprite_frames.has_animation(anim_name):
		queue_free()
		return
	if asp.sprite_frames.get_animation_loop(anim_name):
		push_warning("hit_feedback_vfx: SpriteFrames 动画应关闭 loop，否则无法结束自毁")
	asp.play(anim_name)
	asp.animation_finished.connect(queue_free, CONNECT_ONE_SHOT)
