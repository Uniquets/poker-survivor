extends Node
## Autoload 注册名：**`GlobalAudioManager`**。全局 BGM 与「配置驱动」的 UI/牌面音效；流来自 **`GameConfig.GAME_GLOBAL.global_audio`**。
## **静态薄封装**见 **`GlobalAudio`**；场景内亦可 **`get_node("/root/GlobalAudioManager")`** 调本节点实例方法。


## 单路循环 BGM（菜单与关卡共用通道，互斥切换）
var _bgm_player: AudioStreamPlayer
## 短音效（与 BGM 分轨，避免打断循环）
var _sfx_player: AudioStreamPlayer


## 进树时创建子播放器并挂到本 Autoload 下，保证切场景不销毁
func _enter_tree() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BgmPlayer"
	_bgm_player.bus = &"Master"
	add_child(_bgm_player)
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.name = "GlobalSfxPlayer"
	_sfx_player.bus = &"Master"
	add_child(_sfx_player)


## 读取全局音效表；未配置 **`GameGlobalConfig.global_audio`** 时返回 null
func _audio_cfg():
	var gg: GameGlobalConfig = GameConfig.GAME_GLOBAL
	if gg == null:
		return null
	return gg.global_audio


## 将流设为循环（**`AudioStreamMP3`** 等支持 **`loop`** 的资源）
func _apply_loop_if_supported(stream: AudioStream, loop: bool) -> void:
	if stream == null:
		return
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = loop
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = loop
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED


## 播放一路 BGM：**`stream == null`** 则停播；**`loop`** 为真时尽量打开资源循环标记
func _play_bgm(stream: AudioStream, loop: bool = true) -> void:
	if _bgm_player == null:
		return
	_bgm_player.stop()
	if stream == null:
		_bgm_player.stream = null
		return
	_apply_loop_if_supported(stream, loop)
	_bgm_player.stream = stream
	_bgm_player.play()


## 播放一次性 **`AudioStream`**；空流直接返回
func _play_sfx(stream: AudioStream) -> void:
	if _sfx_player == null or stream == null:
		return
	_sfx_player.stop()
	_sfx_player.stream = stream
	_sfx_player.play()


# --- 对外 API（实例方法，经 Autoload 名调用）--------------------------------------------------------------------


## 播放菜单 / 选卡阶段默认 BGM；**`stream_override`** 非空时优先
func play_menu_bgm(stream_override: AudioStream = null) -> void:
	var cfg: Variant = _audio_cfg()
	var s: AudioStream = stream_override
	if s == null and cfg != null:
		s = cfg.menu_bgm
	_play_bgm(s, true)


## 播放「关卡未配 BGM」时的默认战斗 BGM；**`stream_override`** 非空时优先（供后续关卡脚本传入专属流前占位）
func play_default_level_bgm(stream_override: AudioStream = null) -> void:
	var cfg: Variant = _audio_cfg()
	var s: AudioStream = stream_override
	if s == null and cfg != null:
		s = cfg.default_level_bgm
	_play_bgm(s, true)


## 显式切换关卡 BGM（后续关卡资源应调用本接口）；**`stream == null`** 等价停 BGM
func play_level_bgm(stream: AudioStream) -> void:
	_play_bgm(stream, true)


## 停止 BGM 并清空流
func stop_bgm() -> void:
	_play_bgm(null, true)


## 牌组打出音效（表 **`card_group_played_sfx`**）
func play_card_group_played() -> void:
	var cfg: Variant = _audio_cfg()
	if cfg == null:
		return
	_play_sfx(cfg.card_group_played_sfx)


## 牌库洗牌 / 重洗音效（表 **`deck_reshuffle_sfx`**）
func play_deck_reshuffle() -> void:
	var cfg: Variant = _audio_cfg()
	if cfg == null:
		return
	_play_sfx(cfg.deck_reshuffle_sfx)


## 选卡确认等（表 **`card_pick_confirm_sfx`**）
func play_card_pick_confirm() -> void:
	var cfg: Variant = _audio_cfg()
	if cfg == null:
		return
	_play_sfx(cfg.card_pick_confirm_sfx)


## 通用 UI 按钮（表 **`ui_button_click_sfx`**）
func play_ui_button() -> void:
	var cfg: Variant = _audio_cfg()
	if cfg == null:
		return
	_play_sfx(cfg.ui_button_click_sfx)


## 任意短音效（不受表约束，供临时/调试）
func play_one_shot(stream: AudioStream) -> void:
	_play_sfx(stream)
