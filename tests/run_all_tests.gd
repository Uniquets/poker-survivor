extends SceneTree

const TestSupport = preload("res://tests/test_support.gd")
const TEST_SCRIPTS: Array[String] = [
	"res://tests/cards/test_group_detector.gd",
	"res://tests/cards/test_effect_pipeline.gd",
	"res://tests/cards/test_auto_attack_debug.gd",
	"res://tests/cards/test_meteor_hit_sfx.gd",
	"res://tests/cards/test_card_pick_flow.gd",
	"res://tests/ui/test_run_hud_controller.gd",
]

var _failures: int = 0
var _passes: int = 0
var _current_failed: bool = false


## SceneTree 入口：逐个加载测试脚本并执行所有 `test_` 静态方法。
func _init() -> void:
	for path in TEST_SCRIPTS:
		_run_script(path)
	print("[test] summary | pass=%d fail=%d" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)


## 加载单个测试脚本；脚本缺失或无法加载时记录失败。
func _run_script(path: String) -> void:
	var script: Script = load(path) as Script
	if script == null:
		_failures += 1
		push_error("[test] FAIL %s | script failed to load" % path)
		return
	for method in script.get_script_method_list():
		var name: String = str(method.get("name", ""))
		if not name.begins_with("test_"):
			continue
		_run_case(script, path, name)


## 执行单个测试方法；依靠断言错误和异常退出码暴露失败。
func _run_case(script: Script, path: String, method_name: String) -> void:
	TestSupport.current_runner = self
	_current_failed = false
	script.call(method_name)
	TestSupport.current_runner = null
	if _current_failed:
		_failures += 1
		print("[test] FAIL %s::%s" % [path, method_name])
	else:
		_passes += 1
		print("[test] PASS %s::%s" % [path, method_name])


## 供 TestSupport 标记当前用例失败，避免依赖引擎全局错误计数 API。
func mark_current_failed() -> void:
	_current_failed = true
