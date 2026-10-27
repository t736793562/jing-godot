# 验证范围与未验收边界

## 来源和对照

- 旧基础模块的 RNG、装包、健康、动物、生存等单元对照，验证的是对应基础函数，不单独代表最后 HTML 全栈。
- active_new_game、current_diet、first_night、first_focus、early_focus、second_night、early_lifecycle 等使用实际 index 顺序加载的现行规则栈。源文件只读，保存各模块来源和哈希。
- 当前夜话的独立组合测试排除 HTML 存储传输；它验证正文准备、事件收尾、晨间正文，不替代全夜结算或实际磁盘测试。
- family_prose 检查逐字内容一致性；把源字符串编译为数据并不等于已经接通所有会调用它的剧情路线。
- 早期照料通过源码生成模板，运行时只代入已定义病症文字及既有事件次数，条件、选择和效果仍由原生模型执行。并非把未来结算快照当游戏逻辑。

## 实际做过的检查

- 各专项日志记录本轮实际退出码、失败项和检查次数；不能把历史 first_diff 文件当最新测试结论。
- 原生存档保留数字的类型与 float64 原始位、字典键和顺序；真实临时文件写入后回读，轮换有效备份。
- 五类 I/O 故障注入检查原主档和备份仍可读取且字节未被错误覆盖。
- 长流程恢复从真实新开局出发，在不同阶段保存、退出进程，在下一个进程加载后继续；结果与不中断的同一条模型路径比较。
- 更长的跨进程测试曾发现第四天照料档被误拒绝：内容模板里的 JSON 数字是 float，运行时 priorCount 是 int，Godot 的容器深相等会区分二者。修复只将冻结内容的数值比较改为语义比较；不改变存档的精确编码，不放宽年份键/任意对象等规则。失败检查点保留为内部生成的回归样本。
- 早期危重专项覆盖预警、经此前预警的成年家人健康耗尽死亡、在场知情/精神影响和待办取消，以及失去所有保护者后的清晨警告。并不代表所有明确致命剧情及 C-018 最终失败结算已接入。
- controller_early_days 通过实际原生控制器事件完成一条四夜流程；仍然是无界面事件调用，不是实机鼠标或截图验收。

## 尚不能据此声称

- 尚不是 49 日完整游戏；未接入口会明确禁用或返回开发候选提示，不虚构推进。
- 家人死亡/缺席后的全部页面和剧情、独自生存失败结局、完整后期人物/照片/远行链尚未完成。
- 无真实截图就不能认定 UI 1:1，不能用设计图或自动生成图片冒充运行截图。
- 文件导入/导出对话框及 Windows 原生应用实机操作尚未验证。
- 整轮通过后又修改源码，需要重跑相关检查；报告会记录源哈希，运行中源码改变不计整轮通过。

### 2026-10-26 first-week and night draft guard extensions
D5–D10 home/weather/neighbour content: 480 synthetic all-present source contexts,
6240 state/result/diary comparisons passed. Not continuous later-night gameplay.
Current source night draft guards: 96 contexts, 2688 comparisons passed, covering
editable/locked/non-night/ended phases, stale feed selections, unavailable animals,
module disabled, invalid treatment and pigeon actions, explicit cancellation, and
null pigeon selection. This caught a null-versus-"none" divergence and an incorrect
rejection-message noun; both corrected before passing. No visual test implied.
Latest complete baseline regression is being rerun against current source.

Reselect-before-choice regression: 1020 source contexts (480 home/weather and
540 care), 2040 comparisons. The first run exposed 98 D5/D6 care prose
mismatches: authoritative source applies two wording edits only to fresh events,
not to regenerated fallback after leaving the choice screen. Native selection
now mirrors that exact limited condition, using the original source's two string
pairs; it does not alter the fresh prose, effects, or already settled events.
A targeted rerun is recorded in focus_reselect_parity.log. Full runner now also
fingerprints project data and scenes, not only scripts, to detect mid-test edits.

### D5–D9 missing-adult extension
Supported scope: Luo remains present, at least one adult remains, no one is away
on an expedition. Death/absence helper models use separate source-derived prose
banks; all-present frozen banks are unchanged. Solo and expedition flows remain
explicitly gated. Targeted results: 720 synthetic focus scenarios / 9360 checks;
22 naturally reached missing-adult lifecycle continuations / 302 comparisons;
352 exact codec checks; six household combinations in controller flow / 158
checks. Six separate processes resume all 22 lifecycle samples from actual disk,
comparing source state and uninterrupted native execution. These are headless
checks, not screenshots or visual acceptance. The expanded full suite is rerunning.

### D10 boundary and C018 solo result packets
The D10-to-D11 boundary now preserves the source's initialized story node state
and any C018 warning facts added at dawn. 24 actual source boundary cases passed
348 comparisons (including repeated initialization) and 384 codec checks;
6-process disk continuation and the 257-check ten-night controller route passed.

C018 helper packet parity: 144 synthetic contexts / 2448 checks, covering active
and absent adult protectors, warning/acknowledgment, queue deduplication, settlement
stage guards, survival cancellation, fatal commitment and repeat application.
Natural solo continuation: 16 source-reached checkpoints, 15 terminal results and
1 survivor, 210 state/result comparisons passed. Native disk continuation uses six
independent processes and exact uninterrupted-vs-resumed state equality. Codec
checks: 256; malformed terminal-state rejection checks: 8. The controller's two
outcomes, terminal save-preview/restore and non-destructive return-to-menu passed
65 checks. Expanded full regression is running and must not be called passed yet.

The source terminal save-validation hook normalizes closedCharacterArcs.Luo's
reason to “死亡存档恢复”. The native terminal transition mirrors that pure state
normalization without claiming that an automatic disk save occurred.

UI16_approved_reference_render.png is a static rendering of the retained approved
SVG using its bundled fonts, not a Godot runtime screenshot or visual acceptance.
The native interruption panel reuses that approved layout and actual failure/photo
state. The complete 49-day story, late photo/expedition flow and visual QA remain
unfinished.

D11–D18 pre-photo plan projection: 640 source scenarios / 1280 comparisons passed.
This is a helper only, not a newly opened gameplay route. It covers routine-work
priority, water/wood/food pressure, weather, illness, missing adults, prior burial
acceptance and pigeon scheduling. Photo employment, expeditions and late crisis
memories are outside this helper's declared scope. D11 player entry remains gated
until event binding, outcomes, night continuation and save validation are ready.

Neighbour admission helpers (not yet opened D11 gameplay): home reception, urgent
care/rest priority and due rope/parcel encounter ordering passed 720 source
contexts / 2880 comparisons. The first run caught GDScript's typed Array membership
rejecting JSON float-valued stage 2.0; stage validation now checks integral numeric
identity before converting for membership. It does not rewrite saved values.
WebR8 custody record validation: 2287 constructed contract records / 6861 checks,
including invalid shapes, deadline/renewal limits, duplicate actions, ownership
and handoff records. These are not played custody chains.
WebR5/6/8 message/custody admission and historical witness derivation: 960 source
contexts / 5760 comparisons, with gameplay state unchanged. Raw knownBy alone is
not substituted for actual encounter and return receipts. Unsupported D11+ memory
contracts are rejected by the current native save validator until the actual event
and outcome path is connected. Expanded full regression is starting.

## 2026-10-26 custody return block (targeted, before player connection)

The native selected-instance custody return now settles bounded D11–D17 resource
work packets, repeat-return handling, source-authored chapter-four paragraphs,
actual teller/witness knowledge, and R6/R8 returned receipts. Exact serialized
public-family replacement snapshots are respected; missing, ambiguous or unknown
snapshots do not silently receive current prose. A separate owner-arrival helper
checks actual due dates, capable identity witnesses, urgent care, fixed scenes,
major outcomes and duplicate physical handoff before changing custody.

Targeted source comparisons passed: 264 chapter-composer contexts, 176 selected
returns, 564 controlled renewal/agent returns, and 168 owner-arrival contexts.
These are deliberately controlled domain fixtures. Renewal/agent contexts begin
with source-accepted intake and then explicitly position a later context; they are
not a completed sequence of naturally played nights. Source persistence is stubbed
where choice/return calls normally save. The owner-arrival oracle exposes the
original private function in VM memory without changing retained HTML files.
No real disk claim, Windows run, mouse check or visual acceptance follows from
these results. Player access remains limited to ten nights and D11 morning.
The full regression including this block is recorded separately in AGGREGATE.json.

## 2026-10-26 pre-photo ordinary and care components

Ordinary D11-D17 choice and return helpers are now in the native model. The
source parity corpus has 490 choice contexts and 339 accepted return contexts.
The outdoor constructor has 531 additional source-generated contexts covering
actual earlier water observations, resource pressure, tools, health, absent
family and burial preparations. This exposed a D12 primary-target invitation
option that the initial constructor omitted; the primary-target distinction is
now preserved and the expanded test passes.

The separate home-care prose component preserves completed-and-known history,
actual patient, speaker, helpers and witnesses. Both decoration and native
care/recovery construction pass 280 controlled contexts; 393 choice-to-return
cases cover available/unavailable treatment choices, repair, lamp use and
medicine exchange (286 source-accepted choices). These source oracles stub saving;
they do not prove native save acceptance, a complete daily loop, UI or Windows.
A healthy-home authored-content layer is staged outside the shipped model and
passes 40 existing source contexts, but is not yet a complete fresh-plan binder.

The 69-suite aggregate at AGGREGATE_CUSTODY_RETURN_69.json precedes these newer
components. The subsequent 75-suite run must finish with unchanged source before
its aggregate can be claimed. Player scope has not changed: first ten nights to
D11 morning only. Source-generated event fixtures are development evidence, not
production artwork or runtime screenshots.

## D11 complete model loop, still behind the UI/save gate

The native fresh-plan binder now covers D11–D12 ordinary outdoor, healthy-home,
care/recovery and R6/R8 admission/displacement order. 240 controlled starts pass
source comparisons through entry and selection. This uncovered and fixed a
StringName resource value in a queued return-water packet, plus preservation of
the original care instance displaced by a recovery offer. Comparisons still check
complete state; no mismatched field was removed from the oracle to obtain a pass.

24 source-reached D11 mornings were continued through selection, choice, return,
night confirmation, night response and settlement with source save validation
active (its transport remains in-memory). 18 finish at D12 morning; 6 correctly
finish at the C018 terminal failure on D11. All 344 comparisons pass. The natural
continuation also exposed the missing committee-work row in custody-return's
supported-row guard; that case is now accepted and its actual return receipt is
compared. The shared night guards and old ten-night controller recheck pass.

This is NOT a newly released playable day. Native save validation still rejects
late focus phases and the controller is still gated at D11 morning. The next gate
is strict frozen-instance validation plus independent-process native save/load,
then controller integration. The latest complete earlier aggregate is 75 suites;
the subsequent 80-suite aggregate is separate and must be read for current status.
