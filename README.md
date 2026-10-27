# 京字 · Godot 原生候选：本地 GUI / Windows 验收交接

本包不是视觉验收通过或正式发布版。源工程为 Godot 4.6.3，已接入49日模型、远行、自动保存与退出保护、信鸽求助与取物。

## 当前真实结果

- 主工程完整注册回归：245/245通过；运行期间源码与测试文件哈希保持不变。
- 自动保存/退出保护：55项合并后复测通过。
- 信鸽：6条正常开局路线到D11，436步、1217断言通过；合并后28个独立进程真实存读档通过。
- 尚未通过：真人/实际鼠标 GUI、运行截图、与批准设计逐页1:1比对、Windows独立版、自然49日完整GUI通关。
- 全部以上自动检查均为Linux Godot无界面/控制信号测试，不能替代视觉验收。

## 取文件与启动

代码、测试脚本、文档直接可读。大批量运行资源和批准设计采用原字节ZIP分片，避免将数GB重复文本直接放入Git。不是Git LFS，不需要额外下载站点，也不改图。

1. 使用 Python 3 运行：`python restore_payload.py --group runtime`
2. 使用现有 Godot 4.6.3 打开 `project/project.godot`。主场景 `Main.tscn`。
3. 需要批准的UI设计参考：`python restore_payload.py --group design`
4. 需要本包全部资源：`python restore_payload.py --group all`

恢复器校验分片、归档及全部成员SHA-256；遇到现有不同字节文件立即停止，不覆盖本地修改。默认画布1920×1080、初始窗口1280×720，截图记录实际运行尺寸，不拉伸。

## 验收从哪里开始

请先阅读 `CODEX_LOCAL_ACCEPTANCE.md`。只在独立目录/测试存档上运行；不得覆盖其他版本或玩家存档。主菜单、设置、装包、开局、白天选择/结果/返家/日记、夜间、动物/信鸽、远行、记录、存读档及结局均需要真正操作。

逐页采用 `art_reference/scenes/` 对应的批准UI设计，而不是旧HTML尚未替换的页面。`LayoutInspector.tscn`是布局检查工具，不是主游戏。没有运行截图可冒充通过。

## 回归资料与边界

已直接包含：`evidence/AGGREGATE_SAVE_UX_PIGEON_245.json`、`SAVE_UX_PROMOTED_ACCEPTANCE.json`、`PIGEON_PROMOTED_COLD_ACCEPTANCE.json`。
`docs/SAVE_UX_AND_PIGEON_SCOPE.md`记录曾遗漏的备份警告、前期信鸽日记与冷启动切点问题，保留失败证据。

原 `tools/run_checks.py` 和测试定义仅用于理解既有验证范围。本次 GUI 交接不附834 MB压缩历史回归输入，不能在此精简包中直接重跑245项。需要重跑时另取完整夹具包，不得把缺文件误报为游戏失败。3个合成定点存档见 `fixtures/README.md`，不能当自然通关证据。

源参考和原测试文档中有阶段性旧状态，以本README、交接指令与最新245项回执为准。GitHub是否上传成功以实际远端提交回执为准，不能仅凭此本地文件宣称。
