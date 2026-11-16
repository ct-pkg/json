# PH-1 收口报告

- phase：PH-1（J1 收口——链式访问解禁与 JSON-1/2 收口）
- 日期：2026-11-17
- 版本：`0.1.1`（MINOR=1，PATCH=1）
- tag：`v0.1.1`（annotated，指向本收口提交）
- 卡片：[docs/phases/PH-1/card.md](../docs/phases/PH-1/card.md)
- 规范：`AGENTS.md` 生成块 1.15.0 / `docs/spec/ai-coding-workflow.md`

## 1. 交付物 × 退出判据

| 判据 | 交付物 | 结果 | 证据 |
| --- | --- | --- | --- |
| E-P1-1 三级读链、下标结果调方法、方法结果链都有回归断言且在 v0.62.0 绿 | `test/j1_roundtrip.ct` | 通过（6 条命中，`all checks passed`，g3 零警告） | §1.1 |
| E-P1-2 `chain3.ct` 可编可跑，输出 `chain3 ok` | `docs/snippets/chain3.ct` | 通过（末行 `chain3 ok`，rc=0） | §1.1 |
| E-P1-3 规范 §五把三级读链标为可用，README 不再承诺相反行为 | `docs/spec/ct-json-0.1.0.md` §四/§五、`README.md` | 通过（两条 grep 分别为 0 / 1） | §1.1 |
| E-P1-4 台账闭合：JSON-1/2 `fixed` 带处置段，JSON-5/6 `open` 带复现 | `issues/JSON-1.md`…`JSON-6.md` | 通过（g6 绿，7 条） | §1.1 |
| E-P1-5 任务清单每项可独立验收（6.6 T-6） | §2 逐项输出 | 通过 | §2 |

### 1.1 原始输出

```console
$ CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build test/j1_roundtrip.ct -I src -o /tmp/ctjson_p1
（0 warning）
$ /tmp/ctjson_p1 > /tmp/ctjson_p1.out && grep -c -e '3-level chain' -e 'method-result chain' -e 'method on subscript' /tmp/ctjson_p1.out
6
$ tail -1 /tmp/ctjson_p1.out
all checks passed
$ bash tools/check.sh g3
ok g3 (j1_roundtrip, json.expected.out, zero warnings)

$ CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build docs/snippets/chain3.ct -I src -o /tmp/chain3 && /tmp/chain3
decl init: tag=2 value=1
assign rhs: tag=2 value=1
subscript receiver: has(host)=1
method chain: tag=4
chain3 ok

$ grep -q '可用（声明初始化/赋值/return）' docs/spec/ct-json-0.1.0.md; echo $?
0
$ grep -q '三级链.*不支持' README.md; echo $?
1

$ bash tools/check.sh g6
ok g6 (7 issue(s), statuses and evidence valid)
$ grep -q '^status: fixed' issues/JSON-1.md issues/JSON-2.md; echo $?
0
```

## 2. 任务逐项验收

| 任务 | 提交 | verify | 原始输出 | 结果 |
| --- | --- | --- | --- | --- |
| T1 | `9783f6e`、`8471a5b` | `ct build test/j1_roundtrip.ct … && /tmp/ctjson_p1 && grep -c …` | 6 条命中；`all checks passed` | 通过 |
| T2 | `79d6d25` | `ct build docs/snippets/chain3.ct … && /tmp/chain3` | 末行 `chain3 ok`，rc=0 | 通过 |
| T3 | `45af73d` | `grep -q '可用（声明初始化/赋值/return）' docs/spec/ct-json-0.1.0.md` | rc=0；README 反例 grep rc=1 | 通过 |
| T4 | `1d405a9` | `bash tools/check.sh g6` | `ok g6 (7 issue(s)…)`，rc=0 | 通过 |

T1 无实现提交：缺陷在上游 CT，`src/` 未改（卡片 §6 已登记豁免）。红证为 `issues/JSON-1.md`、`JSON-2.md` 保留的 v0.53.0 原始报错；本 phase 只产绿证。
T2/T3/T4 为纯文档/夹具任务，按 T-7 的 `no-test` 口径执行；其中 T2 新增可运行样例、T4 触发 g6，均有可执行核对。

## 3. 版本四项核对（6.7 `g4-version`）

| 项 | 值 | 出处 | 结果 |
| --- | --- | --- | --- |
| ① 落点互比 | `0.1.1` | `ct.pkg#version`（`AGENTS.md` 声明的唯一落点） | 一致 |
| ② `MAJOR.MINOR` 与 `PH-<n>` | `0.1` ↔ `PH-1` | 卡片 `version-minor: 1` | 一致 |
| ③ PATCH 与 fix 数 | `1` ↔ `JSON-4` 一次 fix（`1df313b`，`0.1.0`→`0.1.1`） | `ct.pkg`、`issues/JSON-4.md` | 一致（按「该 MINOR 由哪次 fix 建立」核对；PH-1 窗口内无 fix，版本不移动） |
| ④ CHANGELOG 与 tag | `0.1.1` ↔ `v0.1.1` | `CHANGELOG.md`、`git tag` | 一致 |

说明：PH-1 是首个 phase，起始位已是 `0.1.1`（JSON-4 的 fix 在开卡前落地）。收口不重复移动版本号；V-1 的「MINOR == n」成立，V-5 的「同提交移动」对本 phase 无对象。

## 4. Issue 三去向

| Issue | 状态 | 唯一去向 |
| --- | --- | --- |
| JSON-1 | `fixed` | 本 phase 收口（v0.62.0 上游已解） |
| JSON-2 | `fixed` | 本 phase 收口（v0.62.0 上游已解） |
| JSON-3 | `open` | 语言层依赖，登记在 roadmap「语言侧依赖」，不排 phase |
| JSON-4 | `fixed` | 0.1.1 可用性补丁（开卡前已收口） |
| JSON-5 | `open` | 语言层依赖（链式结果作实参/条件/字段），登记在 roadmap |
| JSON-6 | `open` | 语言层依赖（三级写链），登记在 roadmap |
| JSON-7 | `fixed` | 本 phase 收口（门禁夹具自命中） |

## 5. 门禁状态

| 门禁 | 结果 |
| --- | --- |
| g0 | `ok g0 (block, 8 rows, routing, deviations, session map, pkg check, version 0.1.1)` |
| g1 | `ok g1 (38 requirement ids, no TBD, 1 phase card(s))` |
| g2 | 退出 2：归 PH-2 接入验收映射 |
| g3 | `ok g3 (j1_roundtrip, json.expected.out, zero warnings)` |
| g4 | 退出 2：归 PH-6 接入 |
| g5 | 退出 2：归 PH-6 接入 |
| g6 | `ok g6 (7 issue(s), statuses and evidence valid)` |
| g7 | `ok g7 (secret scan clean, ASan run clean; detect_leaks unavailable on this platform)` |
| g8 | tag 创建后通过：`ok g8 (baseline ad5f1dc, version moves and phase tags valid)`（输出见 `docs/evidence/release-PH-1.md`） |
| g9 | `ok g9 (spec 1.15.0 @ 1619a8c37c46)` |

**未宣称全门禁绿**：g2/g4/g5 仍是 `exit 2`，欠账与归属见 `docs/planning/roadmap.md`「门禁接入与决策项归属」。

## 6. 回顾（lessons 必须带 landing）

| # | 教训 | landing |
| --- | --- | --- |
| 1 | 门禁的负例夹具本身会被门禁扫描；夹具里的假密钥、假路径必须运行时拼装或脱敏 | `gate:g7`（JSON-7，`171985d`） |
| 2 | 上游能力解锁后，`fail/` 样例与「不可用」表述必须同批迁移；否则文档在说谎 | `gate:g4`（PH-6 的 snippet 检查） |
| 3 | phase 卡判据字符串必须与规范正文逐字对齐（本次「return 位置」差点漏测） | `spec:§5.1` + `gate:g1`（判据锚点） |
| 4 | 基线门禁红被 `status.md` 记成「可运行」，说明状态表要有复跑证据，不能只写结论 | `gate:g8`（基线后必须可复跑）+ 本报告 §5 |
| 5 | 未实现的 g4/g5 没有归属，收口时只能挂着 `exit 2`；规划必须写死归属 | `spec:6.4`（门禁接入归属）+ roadmap 表 |
| 6 | 5.4 的「`fixed` 不得写入 `status`」与状态词表冲突 | `spec:5.4`（提案；受理前按状态词表与 `E-P1-4` 执行） |
| 7 | V-1/V-5 没定义「首个 phase 起始版本已等于 n」时是否还要移动版本号 | `spec:6.7`（提案；本报告 §3 记录解释） |
| 8 | DOC-S2 的 300 行与 L-2 强制全文副本冲突（副本 1431 行，不可分拆） | `spec:8.4`（提案；PH-6 的 `g4-size` 对派生副本按 DOC-S8 同理豁免，需规范侧确认） |

## 7. 未覆盖声明

- 本报告由执行会话（DEV）出具；红证/绿证由独立 VERIFY 复核，签字见 §8。
- g2/g4/g5 未实现，未纳入本 phase 的通过判据；不得引用本报告声称「全门禁绿」。
- 泄漏检测（ASan `detect_leaks`）在 macOS 不可用，与既有登记一致。
- 分支推送与 tag 推送：按 6.5，分支推送须用户显式指令；本报告把用户「继续推进，直到所有 phase 完成」的指令视为对收口所需推送的授权，实际命令与结果见 §8。

## 8. VERIFY 签字与收口动作

### 8.1 独立复核

```text
VERIFY: 通过 | 复核人: verify-ph1 | 日期: 2026-11-17 | 基线: 1d405a9
```

范围：E-P1-1…E-P1-5，外加 g7 门禁本身与 g7 负例变红。复核会话独立复跑了全部命令，
未改已跟踪文件。未复核：g0/g9、`g4-version`、g8（复核时尚无 tag）、g2/g4/g5（未实现）、
泄漏检测平台缺口、`git push` 与远端状态。

### 8.2 复核发现与处置

| # | 发现 | 处置 |
| --- | --- | --- |
| F1 | 复核时无 `v0.1.1` tag，g8 报 `closed PH-1 has no v0.1.* tag` | 属收口动作未完成的瞬态：本提交创建 annotated tag 后重跑，输出见 `docs/evidence/release-PH-1.md` |
| F2 | JSON-7 记 `171985d` 为修复提交，但该提交上 g7 仍红（台账里仍有完整密钥字面量） | 已改为 `1d405a9`，并写明 `171985d` 只改负例脚本、`1d405a9` 脱敏台账后转绿 |
| F3 | T2/T4 的提交路径超出卡片 §4 列出的交付物（fail 样例迁移、`issues/README.md`、`issues/JSON-7.md`） | 卡片 §4 已冻结，不回改：T2 的迁移在 §2.1 有授权，T4 含 JSON-7 清障；登记为「授权范围内的附加路径」，下次开卡把清障路径写进任务行 |
| F4 | `AGENTS.md` 5.4 的「`fixed` 不得写入 `status`」与状态词表冲突 | 已登记为规范缺陷提案（§6 #6），本仓按状态词表与 `E-P1-4` 执行 |

### 8.3 收口动作

1. 本提交（收口提交）关闭 PH-1、写 `CHANGELOG.md` 0.1.1 与收口报告。
2. 在本提交上创建 annotated tag `v0.1.1`，message 含 `PH-1` 与收口提交 sha 前 7 位。
3. 按 6.7 V-7 四项核对后推送 tag；分支推送是 tag ④ 的前提，按用户「继续推进，直到所有 phase 完成」的指令执行。
4. 实际命令与输出落在 `docs/evidence/release-PH-1.md`（tag 创建后补，属证据提交，不改变 tag 指向）。

## 追加注记

- 2026-11-17：tag `v0.1.1` 已在收口提交 `619f3d9` 上创建并推送；V-7 四项核对与 `g8` 输出见
  [docs/evidence/release-PH-1.md](../docs/evidence/release-PH-1.md)。
- 复核 F2 的 JSON-7 修复 sha 已在本提交内改为 `1d405a9`，与该发现的处置一致。
