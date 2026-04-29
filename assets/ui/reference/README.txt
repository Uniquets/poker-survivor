目标 HUD 布局（哥特扑克风）参考说明
=====================================

1. 请将你在 Cursor 里提供的参考截图另存为与本目录同级的图片文件：
   target_hud_layout_reference.png
   （若已存在同名文件，可直接替换。）

2. 主场景 HUD 结构见 scenes/main/RunScene.tscn 内 HUD/LayoutRoot。
   所有以 Slot_ 开头的 TextureRect / TextureButton 均为「仅贴图」占位：
   在检查器中拖入 Texture2D 即可，无需改脚本。

3. 已与玩法绑定的控件路径（run_scene.gd 使用）：
   - HUD/LayoutRoot/TopLeft/HealthBar
   - HUD/LayoutRoot/TopLeft/HealthText
   - HUD/LayoutRoot/TopLeft/LevelLabel
   - HUD/LayoutRoot/TopLeft/ExpBar
   - HUD/LayoutRoot/BottomCenter/CardHandUI

4. 当前未接逻辑的占位（可后续接 AutoLoad / 波次系统等）：
   - TopCenter：波次标题、计时文案、进度条槽位
   - TopRight：金币/击杀计数、暂停键槽位
   - BottomRight：四花色统计槽位
   - TopLeft/BuffRow：Buff 图标槽位
