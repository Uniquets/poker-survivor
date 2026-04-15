# Changelog

## [Unreleased]

- Cursor / Godot：`geequlim.godot-tools`、`.vscode/launch.json` / `tasks.json` / `extensions.json`、`docs/开发环境_Cursor与Godot.md`；`settings.json` 中 LSP 端口与 Godot 默认 6005 对齐
- `RULES_V0_2.md` 与设计与进度文档：与当前实现对齐（选 3 张开局、连对/飞机、装配时机；§8～§9 标为规划）；任务板勾选 T004～T006、T008、T011
- 文档与规则按类合并：`docs/设计与架构.md`、`docs/工程规范.md`、`docs/测试与进度.md`；Cursor 规则合并为 `.cursor/rules/cursor-project.mdc`，并删除已并入的旧文件
- 初始化文档：`CODE_RULES`、`ARCHITECTURE`、`RULES_V0_2`、`GAME_SPEC`、`TASK_BOARD`、`TEST_CHECKLIST`、`AI_WORKFLOW`
- 建立 `scenes`、`scripts`、`resources`、`assets`、`tests` 目录骨架
- 新增执行级规范与 Cursor 全局规则（`ENGINEERING_RULES`、`AGENT_RULES`、`REVIEW_CHECKLIST`、`TEST_CASES_CARDS`、`.cursor/rules/*`）
- 完成 Round 1: `T001`+`T002`（玩家移动/受伤/死亡、敌人刷怪与追踪、接触伤害冷却、`RunScene` 可运行入口）
- 新增 `scripts/core/combat_tuning.gd`，收敛基础战斗参数，统一日志格式前缀
