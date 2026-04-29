extends RefCounted
class_name GlobalAudio
## 全局音效**静态入口**：转发到 Autoload **`/root/GlobalAudioManager`**；场景树未就绪时调用静默失败。


## 解析 Autoload **`GlobalAudioManager`** 节点；无 **`SceneTree`** 或未注册时返回 null
static func _mgr() -> Node:
	var st: SceneTree = Engine.get_main_loop() as SceneTree
	if st == null:
		return null
	return st.root.get_node_or_null("GlobalAudioManager") as Node


## 播放菜单 / 开局选卡默认 BGM
static func play_menu_bgm(stream_override: AudioStream = null) -> void:
	var m: Node = _mgr()
	if m != null and m.has_method("play_menu_bgm"):
		m.play_menu_bgm(stream_override)


## 播放默认关卡 BGM（缺关卡配置时使用 **`GameGlobalAudioConfig.default_level_bgm`**）
static func play_default_level_bgm(stream_override: AudioStream = null) -> void:
	var m: Node = _mgr()
	if m != null and m.has_method("play_default_level_bgm"):
		m.play_default_level_bgm(stream_override)


## 切换为指定关卡 BGM；**`stream == null`** 为停播
static func play_level_bgm(stream: AudioStream) -> void:
	var m: Node = _mgr()
	if m != null and m.has_method("play_level_bgm"):
		m.play_level_bgm(stream)


## 停止 BGM
static func stop_bgm() -> void:
	var m: Node = _mgr()
	if m != null and m.has_method("stop_bgm"):
		m.stop_bgm()


## 牌组打出音效
static func play_card_group_played() -> void:
	var m: Node = _mgr()
	if m != null and m.has_method("play_card_group_played"):
		m.play_card_group_played()


## 牌库洗牌 / 重洗音效
static func play_deck_reshuffle() -> void:
	var m: Node = _mgr()
	if m != null and m.has_method("play_deck_reshuffle"):
		m.play_deck_reshuffle()


## 选卡确认音效
static func play_card_pick_confirm() -> void:
	var m: Node = _mgr()
	if m != null and m.has_method("play_card_pick_confirm"):
		m.play_card_pick_confirm()


## 通用 UI 按钮音效
static func play_ui_button() -> void:
	var m: Node = _mgr()
	if m != null and m.has_method("play_ui_button"):
		m.play_ui_button()


## 任意一次性音效
static func play_one_shot(stream: AudioStream) -> void:
	var m: Node = _mgr()
	if m != null and m.has_method("play_one_shot"):
		m.play_one_shot(stream)
