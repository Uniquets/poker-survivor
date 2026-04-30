extends RefCounted

var failed: bool = false


## 供 TestSupport 在 MCP/编辑器测试执行期间标记当前用例失败。
func mark_current_failed() -> void:
	failed = true
