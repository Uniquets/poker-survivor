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

## 6. 与本项目 MCP

`addons/godot_mcp` 为编辑器插件，与 Cursor 内 GDScript 调试无关；不要依赖 MCP 跑正式游戏逻辑。
