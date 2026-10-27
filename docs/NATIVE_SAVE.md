## 2026-10-27 C8 集成逻辑与跨进程存档验收通过

主工程 167 套回归、15 个独立进程 / 5 条轨迹的保存重开验证全部通过；源码指纹一致。接受边界为 44 夜 / 第45日早晨，或对应源流程失败结局。真实鼠标、视觉、Windows 未验。第45至49日仍在独立候选准备，不能视为整部游戏完成。详见 evidence/CHAPTER_EIGHT_ACCEPTANCE.json。

## 2026-10-27 第八章接入，等待主工程验收

第八章候选40套回归、15个独立进程读档、5条轨迹的隔离控制器检查通过，已本地接入。主工程连续冒烟20起点/84日流程/1052检查通过。167套完整主工程回归及接入后的跨进程读档仍待完成；不能将候选回执当作主工程终验。真实鼠标、视觉和Windows未验。

## 第七章存读档复核

2026-10-26：合入主工程后，5 条轨迹经 17 个独立进程验证（含已提交阶段续接探针），均通过。v1 与 v2 编码及 D11 锚点规则保留，日志上限 1024。此结果不等于 Windows 独立版测试；自动保存和退出未保存保护仍待实现，完整49日负载尚未测。

## 2026-10-26 第六章当前验收边界

主工程已通过98组整合回归与17进程/6轨迹独立读档复核，当前主流程到第32日早晨。包含重复已提交半日的恢复探测；仍不是自动保存或真实GUI/Windows验收。完整游戏、远行、信鸽及退出保护尚未完成。以下旧阶段记录仅供追溯。

# 原生存档候选 v1

范围：当前已迁移的序章、教程、装包、逃难、抵达、前十夜和第十一日清晨，以及已接通的早期白天场景。不是完整多日游戏存档验收；后续阶段在状态校验中明确拒绝。不兼容旧 HTML 存档，不读取或修改旧档。

格式：独立原生 JSON 信封，format=jing-godot-native，revision=1。内部显式类型标签编码 null、bool、int、float64、String、StringName、Array、Dictionary；64 位浮点以 IEEE 原始字节十六进制保存，字典键的顺序和类型保留。拒绝 Object/Resource、非有限数、非文本键、重复键、过深/过大输入。SHA256 用于损坏检测，不是防篡改认证，也不声称能抵御重新计算校验的恶意存档。

写入：编码及状态校验 → 临时文件写入和 flush → 重新读取临时文件校验 → 仅用有效旧主档轮换备份 → rename 主档。旧主档损坏时不污染有效备份。加载先主档、后备份；两者无效时不改变内存状态/RNG。不承诺操作系统突然断电后的目录 fsync 持久性，也未在 Windows 实机测试此候选。

UI：沿批准 UI23 组件布局，浏览器相关文案改为原生本机语义。主菜单可进入保存与恢复；游戏中 F5 打开。保存、读取预览、粘贴校验、确认恢复已接线；输入编辑使旧预览失效。恢复前独立保留当前未保存进度，失败则不恢复。文件导入/导出使用 Godot FileDialog，真实窗口与文件选择交互尚未测试。继续游戏在已有当前周目时转入预览，而不是静默覆盖。

实际验证：
- native_save_regression.gd：668 项；80 份第一夜参考案例的各阶段精确往返、浮点/键类型、错误输入、主备份恢复、失败不改内存。
- native_save_io_faults.gd：5 类注入故障、20 项；临时文件失败/损坏、备份失败、rename 失败，核对实际磁盘主备份字节不变。
- tools/test_save_cold_start.py：19 个真正独立 Godot 进程，12 个实际新开局样本；从第一夜延伸到第四夜，在白天选择、返家、夜间确认、夜间应对、次晨等阶段反复落盘并退出，然后由新进程继续；与不中断结果逐字节比较，重复确认/结算不重复执行。
- controller_flow.gd：检查数以最新日志为准；另有 controller_early_days 的四夜流程检查，旧版曾为 67 项无界面控件调用检查，包含存档预览/输入变化/确认恢复与返回次晨。不是物理鼠标点击或视觉验收。

存档测试全部只使用隔离测试路径；用户实际存档未接触。完整游戏、视觉 1:1、Windows 导出与实机仍未验收。


2026-10-26 补记：长流程实际捕获并修复第四天照料档的 int/float 容器比较误拒绝，保留生成检查点并新增 native_save_repro_care.gd 回归。原生编码仍逐位保留浮点；只对冻结正文/效果模板作精确数值的语义等值比较。

Writes now use a cooperative per-path directory lock and expected previous file
fingerprint. Existing locks are not automatically removed; stale-lock recovery is
not yet exposed in UI. Fault tests include held-lock refusal and stale fingerprint
conflicts. These tests do not prove simultaneous independent writer scheduling.

- 首周扩展：native_week_save 对 31 个实际前序样本的 8 个阶段执行 496 项精确类型/位模式编解码检查。test_week_disk.py 以 6 个独立进程续接这 31 个样本，比较源状态以及不中断运行的精确结果；当前记录通过。后续源码变动需重跑。


## 第十一日续接候选：v2 回放校验信封

v1 编码与旧档读取不变。新增 native_continuation_store 使用 v2 信封保存完整的
带类型状态、已通过 v1 校验的第十一日早晨起点，以及受限的操作记录。读取时只调用
白名单中的原生游戏方法重新演算，并要求所得完整状态与保存状态逐字节一致。
记录不能指定脚本、任意方法、路径或系统操作；最多 256 次操作，本版在第十二日
早晨或第十一日 C018 失败结局处停止，不放行尚未接通的下一天。

这避免单纯放宽日期上限就接受任意冻结正文、结果回执或托存物权。SHA256 仍只是
损坏检测，不是身份认证或防作弊签名；起点的真实性也不以密码学证明。后续引擎
变更若使同一操作产生不同状态，会拒绝该续接，而不是默默改写旧结果，兼容迁移须
另行测试。原始输入与用户旧档不因校验失败而被修改。

已验证：24 个现有源流程到达的第十一日样本逐操作精确编解码，720 项检查；
10 类重新计算校验和的坏数据，包括库存、冻结正文、操作名、结果回执、缺失操作、
不受支持的起点以及错误选择索引，均被拒绝且不改变当前状态。随后以 8 个真正独立
Godot 进程在入日、选择、返家、确认夜晚、应对和结算等阶段落盘并退出，24 个样本
最终均与不中断的原生运行逐字节一致，并与源结果语义一致。18 个进入第十二日
早晨，6 个按既有 C018 合同结束。重复确认/结算未重复推进。记录见
native_later_disk.json，运行期间源码未变。

以上是云端无界面的原生进程与文件测试，不是 Windows EXE、真实鼠标或视觉验收。
v2 在控制器中的保存预览、确认恢复、分页与选择入口接线另行测试，不能从模型与
文件测试直接推定界面已经验收。隔离测试文件位于本次测试的 user:// 专用目录。


## Chapter 4 continuation and compatibility (2026-10-26)
Revision-2 action replay now spans D11 through D17, stopping at D18 morning or
a source-approved terminal outcome. The anchor remains a valid D11-morning
revision-1 state. Animal encounter accept/decline is a typed, enumerated action,
not a dynamic method or script. No old format is overwritten or migrated.

The chapter passed a 16-process cold-disk test across eight trajectories, with
exact typed equality to uninterrupted native state and semantic source equality.
Forty-two existing D11/D12 test saves decoded under the staged chapter model.
An additional compatibility test found that old D11 proofs could legitimately
contain a failed confirm/finish attempt made before night. Rejecting these
records during replay invalidated otherwise valid older saves. The minimal fix
retains D11 replay semantics while rejecting out-of-phase repeat actions on
newly opened later days. Targeted tests and a repeated chapter cold test are
required after that fix; consult evidence/chapter_four_compat_fix.json and
evidence/native_chapter_four_promoted_disk.json rather than the earlier logs.
These are headless native-file tests, not Windows EXE or visual acceptance.


## Chapter 5 staged continuation (2026-10-26 14:30 UTC)
The D11 anchor now supports the candidate through D24 and D25 morning. A strict
cold-load test exposed a real compatibility issue that semantic model comparisons
could not detect: storyMorningDays had changed from stored float values to newly
appended integers. The numeric values were equal, but typed replay correctly
rejected the different bytes. The implementation now preserves the existing
state.day + 1 numeric type; the decoder was not weakened or made permissive.
The staged fixed runtime passed 16 processes / 8 trajectories and 35 controller
signal-driven day flows. Promoted-source checks are still pending. Check the
current checkpoint and final acceptance receipt, not stale diagnostic diffs.
Future longer chapters must also review the bounded action-journal budget and
save/load latency. The present 256-action bound is not a full-49-day UX guarantee.

## Remaining persistence UI gap
Current controller inspection confirms that saves are explicit UI/F5 operations
and exports/restores; it does not yet mirror the source game's per-action autosave
or add a native window-close unsaved-progress guard. Cold-process tests explicitly
write their test saves before exit. Do not imply that simply closing an unsaved
candidate guarantees recovery. Complete and test the intended automatic-save / exit
policy before final delivery, with source-compatible behavior and isolated paths.
