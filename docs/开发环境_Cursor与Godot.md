# 在 Cursor 中运行与调试 Godot 项目

本仓库为 **GDScript / Godot 4.6**，无 npm 等额外依赖；核心是 **Godot 编辑器可执行文件** + **Cursor 扩展** + **工作区配置**。

## 1. 已配置内容

| 项 | 说明 |
|----|------|
| 扩展 | **geequlim.godot-tools**（官方 Godot Tools），已在当前环境执行安装命令；他人克隆仓库后 Cursor 会提示安装 `.vscode/extensions.json` 中的推荐扩展 |
| `.vscode/settings.json` | `godotTools.editorPath.godot4` 指向本机 Godot；`godotTools.lsp.serverPort` 与 Godot 默认 LSP **6005** 对齐 |
| `.vscode/launch.json` | **GDScript: Launch Project** / **Launch Current Scene** / **Attach** |
| `.vscode/tasks.json` | **运行游戏**、**打开 Godot 编辑器并载入本项目**（均使用上述 Godot 路径） |

若你的 Godot 安装路径不同，请只改 `.vscode/settings.json` 里的 `godotTools.editorPath.godot4`（也可用无 `_console` 的 `Godot_*.exe`，用于带窗口启动）。

## 2. 语言服务（补全、跳转）

1. 安装扩展：`geequlim.godot-tools`（命令行：`cursor --install-extension geequlim.godot-tools`）。  
2. **方式 A（推荐）**：用 Godot 打开本项目并保持编辑器运行；扩展会连接 Godot 内置 LSP。  
3. **方式 B**：在 Cursor 设置里将 `godotTools.lsp.headless` 设为 `true`，由扩展拉起无界面 Godot 作 LSP（Godot ≥ 4.2）。  
4. 若状态栏提示无法连接：在 **Godot → 编辑器设置 → 网络 → 语言服务器**，将 **Remote Port** 设为与 `godotTools.lsp.serverPort` 相同（本仓库为 **6005**）。

## 3. 调试 GDScript（F5）

1. 在 Cursor 打开 **运行和调试**，选择 **GDScript: Launch Project**。  
2. 在 `.gd` 中打断点，按 **F5**（或菜单启动调试）。  
3. 扩展会按 `godotTools.editorPath.godot4` 启动引擎并加载 `${workspaceFolder}`；详见扩展 README 中的 *GDScript Debugger*。  
4. **Attach**：若你已在 Godot 里用「远程调试」等方式跑游戏，可选用 **GDScript: Attach**（默认端口与扩展文档一致为 **6007**；若连不上，在 Godot **编辑器设置 → 网络 → Debug Adapter** 核对端口与扩展 `launch.json` 中 `attach` 的 `port` 一致）。

## 4. 不调试、只跑游戏

- **终端 → 运行任务** → **Godot: Run game (main scene)**：按 `project.godot` 的主场景运行。  
- **Godot: Open editor with project**：打开 Godot 并载入本仓库。

## 5. 从 Godot 跳回 Cursor（可选）

在 Godot **编辑器设置 → 文本编辑器 → 外部**，启用外部编辑器，`Exec Path` 填本机 **Cursor** 可执行文件（Windows 一般在 `%LocalAppData%\Programs\cursor\Cursor.exe`），`Exec Flags` 使用 Godot 文档中的：`{project} --goto {file}:{line}:{col}`（Godot 4.5+ 常可自动识别）。

## 6. 与本项目 MCP（Godot MCP Pro）

`addons/godot_mcp` 为 **Godot MCP Pro** 编辑器插件：通过 WebSocket 把 **已打开的 Godot 4 编辑器** 接到 Cursor 的 MCP，供 AI 调用「改场景 / 读脚本 / **跑游戏并看画面**」等工具。**游戏发布包不得依赖 MCP**；仅用于开发与联调测试。

### 6.1 使用前检查

1. **本机 Godot 4.6+** 用「项目 → 打开」载入本仓库根目录（含 `project.godot`）。  
2. **项目 → 项目设置 → 插件**：启用 **Godot MCP Pro**；底部 **MCP** 面板（或插件文档）会显示 **WebSocket 地址**（常见为 `ws://127.0.0.1:9080` 等，以你本机为准）。  
3. **Cursor → Settings → MCP**：按插件官方说明添加对应 MCP 服务器（URL 与 Godot 面板一致）；保存后确认连接状态为已连接。  
4. 在对话里让 Agent **先读 MCP 工具列表/描述再调用**，避免盲调参数。

**Agent 在本机 Cursor 中调用 MCP 时的 `server` 标识**：一般为 **`user-godot-mcp-pro`**（与你在 `~/.cursor/mcp.json` 里配置的键名如 `godot-mcp-pro` 可能不同；以 Cursor 为当前工程生成的 MCP 描述为准）。若 `call_mcp_tool` 报「server does not exist」，请在 Cursor **MCP 面板**查看该 Godot 服务器在列表里的准确 ID。

### 6.2 推荐测试循环（与 `addons/godot_mcp/skills.zh.md` 一致）

适合验证「主场景能跑、出牌、弹道/爆炸/治疗」等，而不仅靠无头命令行：

| 步骤 | MCP 工具（示意名） | 作用 |
|------|-------------------|------|
| 1 | `validate_script` | 改完 `.gd` 后先校验语法，再进游戏。 |
| 2 | `play_scene`（`mode: "main"` 或主场景路径） | 启动运行实例。 |
| 3 | `get_game_screenshot` / `capture_frames` | 看画面、多帧行为。 |
| 4 | `simulate_key`、`simulate_action`、`simulate_mouse_click` | 移动、选牌 UI 等交互。 |
| 5 | `get_game_scene_tree`、`get_game_node_properties` | 查运行时节点与数值（如生命、手牌节点是否存在）。 |
| 6 | `get_editor_errors` | 看运行期报错。 |
| 7 | `stop_scene` | 结束运行，避免与下一次 `play_scene` 冲突。 |

**本仓库与效果管线相关时**：可让 Agent 在 `play_scene` 后关注控制台或 `get_editor_errors`，并对 `RunScene` / `AutoAttackSystem` / `CardRuntime` 等节点用 `get_game_node_properties` 做抽查；**关键张 §10** 仍以 `docs/测试与进度.md` 中手动用例为准，MCP 用于加速「跑起来 + 看状态」而非替代规则文档。

### 6.3 局限

- MCP **不会**替代你在 Godot 里第一次配置插件与 Cursor MCP；未连接时 Agent 无法代为「远程点编辑器」。  
- 无 Godot 窗口/无插件时，请仍用 **§3 任务** 或命令行 `--headless` 等方式验证。
