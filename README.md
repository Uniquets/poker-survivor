# Poker Survivor

Godot 4.x 项目。玩法以 `docs/RULES_V0_2.md` 为准；设计与目录见 `docs/设计与架构.md`；工程与 Agent 约定见 `docs/工程规范.md`；任务与测试见 `docs/测试与进度.md`。

## 文档一览

| 文件 | 说明 |
|------|------|
| `docs/RULES_V0_2.md` | 冻结玩法与常量 |
| `docs/设计与架构.md` | 愿景、MVP、场景/模块、目录树 |
| `docs/工程规范.md` | 代码约定、工程边界、Agent 交付 |
| `docs/测试与进度.md` | 任务看板、冒烟清单、卡牌用例 |
| `docs/开发环境_Cursor与Godot.md` | 在 Cursor 中安装扩展、运行与调试 Godot |

## 目录骨架

- `scenes/`、`scripts/`（combat / cards / ui / core / meta）、`resources/`、`assets/`、`tests/`  
- `addons/` 为编辑器插件（如 godot_mcp），游戏逻辑请勿依赖其 API。

## Cursor 规则

合并为单文件：`.cursor/rules/cursor-project.mdc`（默认生效）。
