extends Resource
class_name GameGlobalAudioConfig
## 全局音效表：菜单/关卡默认 BGM、牌组与牌库相关 UI 音效；关卡专属 BGM 后续由关卡资源调用 **`GlobalAudio.play_level_bgm(stream)`** 或 Autoload 同名实例方法覆盖


# =============================================================================
@export_group("BGM")
## 开始界面 / 开局选卡等「非战斗关卡」默认循环 BGM；空则跳过播放
@export var menu_bgm: AudioStream
## 进入战斗后、**关卡未配置 BGM** 时使用的默认循环关卡 BGM（例如 **`res://assets/audio/bgm1.mp3`**）
@export var default_level_bgm: AudioStream


# =============================================================================
@export_group("战斗与牌面 · UI 音效")
## 一组牌打出（**`CardRuntime.group_played`**）时播放的一次性音效；空则静音
@export var card_group_played_sfx: AudioStream
## 牌库耗尽重洗、还牌入库洗牌等 **`CardPool`** 内 **`shuffle`** 路径的提示音；空则静音
@export var deck_reshuffle_sfx: AudioStream
## 选卡确认（三选一/加牌点确定）等通用 UI 确认音；空则静音
@export var card_pick_confirm_sfx: AudioStream
## 通用按钮点击（预留，当前可由 UI 按需调用 **`GlobalAudioManager.play_ui_button`**）
@export var ui_button_click_sfx: AudioStream
