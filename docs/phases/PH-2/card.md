# PH-2 卡：需求基线与验收映射（R-* → ACC-*）

- 编号：PH-2
- phase 目录：`docs/phases/PH-2/`
- version-minor：2
- 规范版本：1.15.0
- 状态：closed
- criteria-sha256：8a4914c17c48559cabf954606acb150ce53c9978c50d470328a00063ce9caecf
- tasks-sha256：728cd38ec610a88af939560ef34af485b099f2f830a7bb3bb0ea918286babaf6

## 0. 编号与元信息

| 项 | 值 |
| --- | --- |
| 编号 | PH-2（与目录 `docs/phases/PH-2/` 一致） |
| 对应 roadmap | [roadmap](../../planning/roadmap.md) 的 PH-2（需求基线与验收映射） |
| 需求 / issue | 全部 `R-*`（38 条）；缺口新开 `JSON-9`、`JSON-10`、`JSON-11` |
| 版本 | 收口时 `ct.pkg#version` 为 `0.2.0`（MINOR=2，PATCH=0） |
| 不为 | 不实现 PH-3…PH-6 的功能；不改 `src/` 的行为；不把「需变更」写成「已满足」 |

## 1. 目标

把 38 条 `R-*` 逐条对照当前包实现（`src/json.h.ct`，不是已废止的 `json.ct` 视图实现）、用例与门禁，产出唯一的 `docs/acceptance-map.md`（每条一个 `ACC-*` 与一条可执行验收），接入 `g2`，并落 Q-03/05/06/07/08/09 的裁定。

## 2. 范围

### 2.1 做什么

- 重锚需求基线：以 `src/json.h.ct` 的公开面与 `test/j1_roundtrip.ct` 的实际断言为准，逐条写「已满足 / 需新增 / 需变更 / 不做」。
- 每条 `R-*` 映射到唯一 `ACC-*`，给出验收命令或可核对锚点、当前证据、去向（本 phase / PH-3…PH-6 / issue / 不做）。
- 公开接口索引：`src/json.h.ct` 的每个 `pub` 符号至少出现在一个 `ACC-*` 的验收里。
- 落 Q 项裁定：`docs/decisions/D-001…D-006.md`，同步 `docs/requirements.md` §8 与相关 R 条的状态。
- 缺口立案：`JSON-9`（NaN/Inf 编码）、`JSON-10`（`as_double` 溢出）、`JSON-11`（解析错误无 offset/行列）。

### 2.2 不做什么

- 不修实现：JSON-9/10/11 只立案，分别留给 PH-5 / PH-4 / PH-5。
- 不改 spec 正文的既有裁定；只补「v0.62.0 访问边界」已改的部分。
- 不把 Q 项的「建议口径」写成用户已逐条签字的结论；裁定记录写明授权来源与失效条件。
- 不新增门禁编号；`g2` 是既有编号下的实现。

## 3. 交付物清单

| 路径 | 内容 |
| --- | --- |
| `docs/acceptance-map.md` | 38 条 R-* → ACC-*、接口索引、缺口与去向 |
| `tools/check.sh`、`tools/negatives/run.sh` | `g2` 实现与负例 |
| `docs/decisions/D-001.md`…`D-006.md` | Q-03/05/06/07/08/09 裁定 |
| `docs/requirements.md`、`docs/planning/roadmap.md` | Q 项状态与 phase 归属同步 |
| `issues/JSON-9.md`、`JSON-10.md`、`JSON-11.md` | 缺口条目 |

## 4. 任务清单

| ID | 交付物 | 提交 | 回滚 | verify | effort | 覆盖 |
| --- | --- | --- | --- | --- | --- | --- |
| T1 | `docs/acceptance-map.md` | `docs: PH2-T1 验收映射` | revert 后 g2 无输入、38 条 R 无 ACC | `test "$(grep -c 'ACC-' docs/acceptance-map.md)" -ge 38` | M | E-P2-1 |
| T2 | `tools/check.sh` g2、`tools/negatives/run.sh` | `feat(gate): PH2-T2 接入 g2` | revert 后 g2 退出 2 | `bash tools/check.sh g2 && bash tools/negatives/run.sh g2` | M | E-P2-2 |
| T3 | `docs/decisions/D-001…006.md`、`docs/requirements.md`、`docs/planning/roadmap.md` | `docs: PH2-T3 Q 项裁定` | revert 后 Q-03/05/06/07/08/09 仍「待确认」 | `! grep -q 'Q-03.*待确认' docs/requirements.md && ! grep -q 'Q-05.*待确认' docs/requirements.md && ! grep -q 'Q-06.*待确认' docs/requirements.md && ! grep -q 'Q-07.*待确认' docs/requirements.md && ! grep -q 'Q-08.*待确认' docs/requirements.md && ! grep -q 'Q-09.*待确认' docs/requirements.md` | M | E-P2-3 |
| T4 | `issues/JSON-9.md`…`JSON-11.md` | `docs(issues): PH2-T4 缺口立案` | revert 后缺口无 issue 可追 | `bash tools/check.sh g6` | S | E-P2-4 |

## 5. 退出判据（冻结）

| 编号 | 判据 | 核对方式 |
| --- | --- | --- |
| E-P2-1 | 38 条 `R-*` 每条有唯一 `ACC-*`、可执行验收与去向，且公开 `pub` 符号全部出现在映射中 | `bash tools/check.sh g2` rc=0；`grep -c 'ACC-' docs/acceptance-map.md` 输出 ≥38 |
| E-P2-2 | `g2` 有可失败的负例：删掉一条 R 行即变红 | `bash tools/negatives/run.sh g2` rc=0，输出含 `red ok g2` |
| E-P2-3 | Q-03/05/06/07/08/09 全部有裁定与 `D-*` 记录 | 六条 `! grep -q 'Q-0x.*待确认' docs/requirements.md` 均 rc=0；`ls docs/decisions/D-00[1-6].md` 6 个文件 |
| E-P2-4 | 缺口有 issue、有去向，台账闭合 | `bash tools/check.sh g6` rc=0；`grep -l 'JSON-9\|JSON-10\|JSON-11' docs/acceptance-map.md` 非空 |
| E-P2-5 | 任务清单每项可独立验收（6.6 T-6） | 逐项贴 T1–T4 的 `verify` 原始输出 |

## 6. 红证方式

- 本 phase 不改 `src/`，无实现提交，不产生 T-7 的 `test 红 → impl` 配对。
- 三条缺口条目自带修复前复现：`JSON-9` 的 `{"x":nan}`、`JSON-10` 的 `1e999 → inf`、`JSON-11` 的「无 offset 访问器」。复跑命令与原始输出写进条目。
- `g2` 的负例由 `tools/negatives/run.sh g2` 提供，红证在 T2 提交内。

## 7. 依赖

| 类型 | 依赖 | 状态 | 说明 |
| --- | --- | --- | --- |
| phase | PH-1 | closed | 链式读边界已对齐 v0.62.0 |
| 工具链 | CT v0.62.0 | 已装 | `ct build` 可跑 |
| issue | JSON-8 | fixed | g8 已能识别 phase 收口版本移动 |

## 8. 已知风险

| # | 风险 | 触发信号 | 处置 |
| --- | --- | --- | --- |
| 1 | 把旧 `json.ct` 视图实现的「已满足」直接抄成新基线 | 证据列只写 `json.ct` 行号 | 只认 `src/json.h.ct` 与 `test/j1_roundtrip.ct`；旧文件证据标「视图实现，已废止」 |
| 2 | Q 项裁定被当成用户逐条签字 | D 记录缺授权来源与失效条件 | 写「用户 2026-11-17 指令授权按建议口径」，并写失效条件 |
| 3 | 缺口只写进映射、不立案 | `docs/acceptance-map.md` 有「需变更」但无 issue id | E-P2-4 用 g6 + grep 双向核对 |

## 9. 收口动作

| # | 动作 | 证据 |
| --- | --- | --- |
| 1 | 逐条核对第 5 节，贴 T1–T4 原始输出 | 本卡收口段 |
| 2 | 版本四项核对（6.7 `g4-version`）：`0.2.0`，MINOR=2，PATCH=0 | `ct.pkg`、`CHANGELOG.md` |
| 3 | 每个 issue 登记唯一去向 | `issues/` |
| 4 | 打 annotated tag `v0.2.0` 并推送（V-7） | `git cat-file -t v0.2.0` |
| 5 | 写收口回顾（`lessons` 带 `landing`） | `reviews/closeout-PH-2.md` |
| 6 | 更新 `docs/session-map.md` 与本目录清单 | 同上 |

## 10. 收口记录（2026-11-17）

- 退出判据 E-P2-1…E-P2-5 逐条通过，原始输出见 [reviews/closeout-PH-2.md](../../../reviews/closeout-PH-2.md)。
- 版本四项：`ct.pkg#version = 0.2.0`，MINOR=2=PH-2，PATCH=0（本 phase 无 fix）；JSON-8 的 PATCH 在开卡前的 0.1.2。
- Issue 去向：JSON-9 → PH-5；JSON-10 → PH-4；JSON-11 → PH-5；JSON-8 已在 0.1.2 收口；JSON-12 本 phase 小循环修复（0.1.3）。
- tag：`v0.2.0`（annotated），随收口提交创建并推送（6.7 V-7）。
- 未覆盖：g4/g5 归 PH-6；不宣称全门禁绿。
