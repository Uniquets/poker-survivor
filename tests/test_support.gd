extends RefCounted

static var current_runner = null


## 断言条件为真；失败时抛出错误并由 runner 计入失败。
static func assert_true(value: bool, label: String) -> void:
	if not value:
		_mark_failed()
		push_error("[test] assertion failed: %s" % label)


## 断言两个值相等；失败输出实际值和期望值。
static func assert_eq(actual, expected, label: String) -> void:
	if actual != expected:
		var msg := "%s expected=%s actual=%s" % [label, str(expected), str(actual)]
		_mark_failed()
		push_error("[test] assertion failed: %s" % msg)


## 将失败状态回传给 runner；没有 runner 时只输出错误。
static func _mark_failed() -> void:
	if current_runner != null and current_runner.has_method("mark_current_failed"):
		current_runner.mark_current_failed()
