# Poker Survivor

Godot 4.x 项目。**开发与验收以 `docs/详细设计.md` 为准**；工程与 Agent 约定见 `docs/工程规范.md`；任务与测试见 `docs/测试与进度.md`。`docs/RULES_V0_2.md` 已废弃，仅作历史参考。

## 文档一览

| 文件 | 说明 |
|------|------|
| `docs/详细设计.md` | **主权威**：系统与模块（第一部）+ 完全体内容（第二部） |
| `docs/RULES_V0_2.md` | **已废弃**，历史快照，勿作实现依据 |
| `docs/工程规范.md` | 代码约定、工程边界、Agent 交付 |
| `docs/测试与进度.md` | 任务看板、冒烟清单、卡牌用例 |
| `docs/开发环境_Cursor与Godot.md` | 在 Cursor 中安装扩展、运行与调试 Godot |

## 目录骨架

- `scenes/`、`scripts/`（combat / cards / ui / core / meta）、`resources/`、`assets/`、`tests/`  
- `addons/` 为编辑器插件（如 godot_mcp），游戏逻辑请勿依赖其 API。

## Cursor 规则

合并为单文件：`.cursor/rules/cursor-project.mdc`（默认生效）。
