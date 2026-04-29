extends Resource
class_name CombatPresentationDefaults
## 全局默认表现：命中与爆炸反馈、通用击退衰减；由 **`GameConfig.COMBAT_PRESENTATION`** 预载。


@export_group("命中与爆炸表现")
## 并行/通用命中点打击反馈预制
@export var hit_feedback_vfx_scene: PackedScene
## 爆炸落点序列帧等（历史上 **`rank8_explosion_hit_vfx_scene`**）
@export var explosion_hit_vfx_scene: PackedScene

@export_group("受击退 · 全局默认")
@export var default_hit_knockback_speed: float = 200.0
@export var hit_knockback_decay_per_second: float = 7.0
