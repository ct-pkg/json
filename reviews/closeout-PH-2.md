# PH-2 收口报告

- phase：PH-2（需求基线与验收映射）
- 日期：2026-11-17
- 版本：`0.2.0`（MINOR=2，PATCH=0）
- tag：`v0.2.0`（annotated，指向本收口提交）
- 卡片：[docs/phases/PH-2/card.md](../docs/phases/PH-2/card.md)
- 映射：[docs/acceptance-map.md](../docs/acceptance-map.md)

## 1. 交付物 × 退出判据

| 判据 | 交付物 | 结果 | 证据 |
| --- | --- | --- | --- |
| E-P2-1 38 条 R-* 有唯一 ACC、可执行验收与去向；公开符号全覆盖 | `docs/acceptance-map.md`、`test/depth_1m.ct`、`test/perf_20k.ct` | 通过（g2：38 R / 38 ACC / 28 symbols；独立复核后修正 4 条虚标） | §1.1 |
| E-P2-2 g2 负例：删一行即红 | `tools/check.sh`、`tools/negatives/run.sh` | 通过（`red ok g2`，rc=1） | §1.1 |
| E-P2-3 Q-03/05/06/07/08/09 全部裁定 + 6 个 D 记录 | `docs/decisions/D-001…006.md` | 通过 | §1.1 |
| E-P2-4 缺口有 issue、有去向、台账闭合 | `issues/JSON-9/10/11.md` | 通过（g6：11 issue） | §1.1 |
| E-P2-5 任务清单每项可独立验收 | §2 | 通过 | §2 |

### 1.1 原始输出

```console
$ test "$(grep -c 'ACC-' docs/acceptance-map.md)" -ge 38; echo $?
0

$ bash tools/check.sh g2
ok g2 (38 R rows, 38 ACC ids, 28 public symbols)

$ bash tools/negatives/run.sh g2
red ok g2 missing requirement row      gate g2 rc=1 | FAIL g2: acceptance map has 37 R rows, requirements have 38 (one ACC per R-* required)
baseline: 2b9e9c42731e17e03ed0e570d717fb5c7c9d3e34
$ echo $?
0

$ for q in Q-03 Q-05 Q-06 Q-07 Q-08 Q-09; do ! grep -q "$q.*待确认" docs/requirements.md; echo $?; done
0
0
0
0
0
0

$ ls docs/decisions/D-00[1-6].md
docs/decisions/D-001.md
docs/decisions/D-002.md
docs/decisions/D-003.md
docs/decisions/D-004.md
docs/decisions/D-005.md
docs/decisions/D-006.md

$ bash tools/check.sh g6
ok g6 (11 issue(s), statuses and evidence valid)
$ grep -c 'JSON-9' docs/acceptance-map.md
3

$ bash tools/negatives/run.sh g2 g8
red ok g2 missing requirement row      gate g2 rc=1 | FAIL g2: acceptance map has 37 R rows, requirements have 38 (one ACC per R-* required)
red ok g2 public symbol unmapped       gate g2 rc=1 | FAIL g2: public symbol json_decode has no ACC mapping in docs/acceptance-map.md
red ok g8 version move without issue   gate g8 rc=1 | FAIL g8: version move check failed
red ok g8 minor without closed card    gate g8 rc=1 | FAIL g8: version move check failed
$ echo $?
0

$ ct build test/depth_1m.ct -I src -o /tmp/depth1m && /tmp/depth1m
depth1m: rc=-9 empty=1
$ ct build test/perf_20k.ct -I src -o /tmp/perf20k && /tmp/perf20k
perf20k: sum=20000 elapsed=1.707ms
```

## 2. 任务逐项验收

| 任务 | 提交 | verify | 原始输出 | 结果 |
| --- | --- | --- | --- | --- |
| T1 | `3806554`、`28e97ad`、`3d91f91` | `test "$(grep -c 'ACC-' docs/acceptance-map.md)" -ge 38` + 两个夹具 | rc=0；depth1m rc=0；perf20k rc=0 | 通过 |
| T2 | `6780200` | `bash tools/check.sh g2 && bash tools/negatives/run.sh g2` | 38/38/28；负例 rc=1 | 通过 |
| T3 | `fe6bb5a` | 六条 `! grep -q 'Q-0x.*待确认'` + `ls D-00[1-6]` | 6 个 0；6 个文件 | 通过 |
| T4 | `2b9e9c4` | `bash tools/check.sh g6` | `ok g6 (11 issue(s)…)` | 通过 |

## 3. 基线重锚结论

| 判定 | 条数 | 代表条目 |
| --- | --- | --- |
| 已满足 | 23 | R-A-02/03/04/05/06/07/10/11/12、R-B-02/04/07、R-C-02/04、R-D-01…08、R-E-01 |
| 需新增 | 2 | R-A-08（strict UTF-8）、R-E-05（g5） |
| 需变更 | 10 | R-A-01、R-A-09、R-B-03、R-C-01、R-C-03、R-C-05、R-E-02、R-E-03、R-E-04、R-E-06 |
| 不做 | 3 | R-B-01、R-B-05（旧 `JsonOut`）、R-B-06（树 API 取代独立 Map/Vec 编码） |
| 待确认 | 0 | — |

与 `requirements.md` 原状态的主要差异：旧 `json.ct` 视图实现的错误码/offset、`JsonOut` 状态机、短缓冲语义不再作为新基线；`1e999 → inf`、NaN 编码、无 offset 三条已立案；独立复核发现的控制字节转义改值（JSON-12）已在本 phase 小循环修复。

## 4. 版本四项核对（6.7 `g4-version`）

| 项 | 值 | 出处 | 结果 |
| --- | --- | --- | --- |
| ① 落点互比 | `0.2.0` | `ct.pkg#version`（唯一落点） | 一致 |
| ② `MAJOR.MINOR` 与 `PH-<n>` | `0.2` ↔ `PH-2` | 卡片 `version-minor: 2` | 一致 |
| ③ PATCH 与 fix 数 | `0`（PH-2 窗口内无 fix） | `ct.pkg`；JSON-8 的 PATCH 在开卡前的 `0.1.2` | 一致 |
| ④ CHANGELOG 与 tag | `0.2.0` ↔ `v0.2.0` | `CHANGELOG.md`、`git tag` | 一致 |

## 5. Issue 三去向

| Issue | 状态 | 唯一去向 |
| --- | --- | --- |
| JSON-1 / JSON-2 | `fixed` | PH-1 已收口 |
| JSON-3 | `open` | 语言层依赖 |
| JSON-4 | `fixed` | 0.1.1 可用性补丁 |
| JSON-5 / JSON-6 | `open` | 语言层依赖 |
| JSON-7 | `fixed` | PH-1 门禁夹具 |
| JSON-8 | `fixed` | 0.1.2 门禁修复 |
| JSON-9 | `open` | PH-5（NaN 编码） |
| JSON-10 | `open` | PH-4（`as_double` 溢出） |
| JSON-11 | `open` | PH-5（错误位置） |
| JSON-12 | `fixed` | 0.1.3 控制字节转义修复（本 phase 小循环） |

## 6. 门禁状态

| 门禁 | 结果 |
| --- | --- |
| g0 | `ok g0 (block, 8 rows, routing, deviations, session map, pkg check, version 0.2.0)` |
| g1 | `ok g1 (38 requirement ids, no TBD, 2 phase card(s))` |
| g2 | `ok g2 (38 R rows, 38 ACC ids, 28 public symbols)` |
| g3 | `ok g3 (j1_roundtrip, json.expected.out, zero warnings)` |
| g4 | 退出 2：归 PH-6 |
| g5 | 退出 2：归 PH-6 |
| g6 | `ok g6 (11 issue(s), statuses and evidence valid)` |
| g7 | `ok g7 (secret scan clean, ASan run clean; detect_leaks unavailable on this platform)` |
| g8 | `ok g8 (baseline ad5f1dc, version moves and phase tags valid)` |
| g9 | `ok g9 (spec 1.15.0 @ 1619a8c37c46)` |

**未宣称全门禁绿**：g4/g5 仍 `exit 2`。

## 7. 回顾（lessons 带 landing）

| # | 教训 | landing |
| --- | --- | --- |
| 1 | 实现换过（视图 → 树）后，需求状态会整体过期；基线必须重锚到当前公开入口 | `gate:g2`（映射 + 公开符号覆盖） |
| 2 | 旧 API 的「已满足」不能直接抄；不存在的 API 要明确标「不做」并给理由 | `spec:Q-09`（D-006） |
| 3 | 负例脚本把 `exit 2`（未实现）当红证，会制造假绿 | `gate:g5`（红证必须 rc≠0 且 rc≠2） |
| 4 | 验收映射不含公开符号索引时，新加的 API 不会进验收 | `gate:g2`（28 个 pub 符号逐个查） |
| 5 | 版本移动要按事件分支：MINOR 是 phase 收口，PATCH 是 fix | `gate:g8`（JSON-8） |
| 6 | 「已满足」必须由独立探针/用例证明；映射自证会把 NUL 转义回归放过去 | `gate:g2`（公开符号 + 独立复核）+ `gate:g5`（PH-6） |
| 7 | 控制字节转义 `\u00` + 4 位是树重写时的回归；转义要有 NUL/0x01 的往返断言 | `gate:g3`（`nul_value_contract`） |

## 8. 未覆盖声明

- 本报告由执行会话（DEV）出具；独立 VERIFY 复核见 §9。
- g4/g5 未实现，未纳入本 phase 的通过判据。
- 泄漏检测（ASan `detect_leaks`）在 macOS 不可用；ASan 只覆盖非泄漏项。
- 验收映射的「已满足」以 `test/j1_roundtrip.ct` 与 2026-11-17 的探针为准；探针未全部固化成用例，固化归 PH-6 的 g5。

## 9. VERIFY 签字

### 9.1 首轮复核（2026-11-17，基线 `2b9e9c4`）：不通过

发现：R-B-02/04/07 的 NUL 转义虚标（真实缺陷 JSON-12）、R-E-03「三处一致」不成立、
R-A-11 验收不可执行（bench 只在 /tmp）、g2 负例只覆盖删行、g8 负例写死 0.1.1。

处置：JSON-12 按 T-7 红（`d804224`）→ 绿（`5359fb4`，0.1.3）；补
`test/depth_1m.ct`、`test/perf_20k.ct`（`28e97ad`）；映射改 23/10/2/3；
g2 补「删公开符号」负例；g8 负例改为从 `ct.pkg` 动态读版本（`3d91f91`）。

### 9.2 次轮复核（基线 `3d91f91`）：仅余文档项

P1-1/P1-2/P2-2/P2-3/P2-4 通过；剩余：映射的 depth/perf 命令缺 `CT_STD_DIR`、
§5 PH-4 漏列 R-A-10/11、status/版本/收口状态在收口前自相矛盾、roadmap 归属未对齐。
已在 `f2efc2b` 修正（含 0x1F 断言）；版本与收口状态由本收口提交 + `v0.2.0` tag 一次性解决。

### 9.3 终验（基线 `875b0d8`，tag `v0.2.0`）

```text
VERIFY: 通过 | 复核人: verify-ph2 | 日期: 2026-11-17 | 基线: 875b0d8
```

- `bash tools/check.sh g8` rc=0；tag `v0.2.0` 指向 `875b0d8`，已推送，`origin/main` 含该提交。
- 版本/收口四者一致：`ct.pkg` 0.2.0、`status.md` 0.2.0 已收口、卡片 closed、tag v0.2.0。
- 映射 R-A-10/R-A-11 的命令照抄可跑（`depth1m` rc=0、`perf20k` rc=0，本次 0.942 ms）。
- g2 rc=0；`tools/negatives/run.sh g2 g8` 四条负例均 red，脚本 rc=0。

非阻塞项：roadmap 的 PH-1/PH-2 状态行已在本提交更新；本章 §9 与
`docs/evidence/release-PH-2.md` 同提交入库。
