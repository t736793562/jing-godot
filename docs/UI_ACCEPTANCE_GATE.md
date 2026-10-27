# UI 交付门槛（用户 2026-10-26 再次明确）

HTML 最终包只作玩法、内容与规则来源。HTML 中没有换好的旧 UI 不是 Godot 的视觉基准。
视觉基准是用户批准的整套设计和最终美术组件；主菜单按已批准保留范围处理。

## 不可替代的验收
- 每个真实游戏页面及适用的选中、禁用、悬停、按下、焦点、长文本状态，运行原生窗口截屏。
- 截图逐项对照设计：构图、面板边界、位置比例、字体字号、颜色、图标和控件状态。
- 核对资源缺失、旧蓝色素材/旧框架残留、层级遮挡、文字溢出、重复按钮。
- 规则/结构/无界面交互 PASS 不能代替截图，也不能标为 1:1 通过。
- 全页设计图不能充当运行截图或作为可玩页面底板冒充控件。

## 当前必须披露的暂态差异
1. 主菜单原背景与标题已用正式资源，但原生按钮风格仍待真实截图核对。
2. 第一夜三选卡当前复用批准 UI18 的三选布局框架，替换不相关的鼠患图标与文字以承载偷窃事件；现有组件包没有单列该偷窃三选状态。此处只能记为待设计对照，不是已确认的像素级通过。
3. 到达/收尾阅读使用已批准阅读纸面组件，但动态正文、日期与字号的实际排版尚未截图验收。
4. 保存 UI23 保留原纸面、图标与位置，浏览器措辞改为实际 Godot 本机语义；原生 TextEdit/FileDialog 的显示、焦点、长文本和遮挡未做视觉验收。
5. 216 个布局状态被编译/加载不等于 216 个游戏入口已接线，更不等于 216 个状态已经目视通过。
6. 字体光栅化、阴影及透明渐变尚未通过实图比对；暂不得以引擎差异自动豁免明显偏差。

最终验收报告要逐页列明通过、偏差、缺件、未测。缺图形环境时保持 NOT_RUN，不降低交付标准。

Reading settings now bind the approved UI22 selected-size / checkbox component
states. Original rule defaults are 19 px and reader mode off (ui-real.js), with
choices 18/19/22/25/29. F6 and main-menu Settings open the same panel; back restores
the prior page. Preferences are separate from gameplay saves. Reader mode dims
background/room portraits without moving controls or mutating game state. The
reference dotted keyboard focus strokes follow the actually focused size control.
54 headless checks passed, including on-disk preference reload, invalid-value
fallback and exact unchanged gameplay/RNG. This is not visual acceptance; default
19 px and focus dimming still require actual runtime screenshots to evaluate.
UI22_approved_reference.jpg is a source component composition, NOT a runtime image.

## Chapter 4 staged animal UI (2026-10-26, not promoted)
The staged controller uses UI17_animals paper, heading, encounter art and button
components at native dimensions, centered as a modal over the current night plan.
Actual source narrative replaces preview explanatory text in a scrollable reading
area. Accept is disabled when the pet slot is occupied. Back does not decide or
advance the encounter; confirming the night without deciding follows source rules.
The animal card adds poultry/pet tabs within its existing bounds. Both feeding
budgets remain independent, and pictures preserve aspect ratio. This tabbed
composition is an implementation adaptation, NOT a verified 1:1 visual match.
Robbery choices paginate at three cards to keep the pet option from overlapping
the footer. All normal, occupied, returned, feeding and pagination states require
actual GUI screenshots and mouse verification. Approved reference images viewed
here are design evidence only, not runtime screenshots.
