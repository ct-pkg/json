# PH-4 收口报告

- phase：PH-4（解码边界）
- 日期：2026-11-17
- 版本：`0.4.0`（MINOR=4，PATCH=0）
- tag：`v0.4.0`（annotated）
- 卡片：[docs/phases/PH-4/card.md](../docs/phases/PH-4/card.md)

## 1. 交付物 × 退出判据

| 判据 | 交付物 | 结果 | 证据 |
| --- | --- | --- | --- |
| E-P4-1 实数溢出与精度 | `test/j1_roundtrip.ct`、`json_as_double` | 通过（145 ok，1e999/-1e999 → RANGE） | §1.1 |
| E-P4-2 strict UTF-8 与 BOM | `test/j4_decode.ct`、`json_decode_strict` | 通过（16 ok） | §1.1 |
| E-P4-3 R-A-08/09/12 已满足、JSON-10 fixed | spec §3.1、映射、JSON-10 | 通过（g2：39/30） | §1.1 |
| E-P4-4 深度/性能复核留证 | `docs/evidence/decode-bounds.md` | 通过（10^6 层 DEPTH；20k 6.708 ms） | §1.1 |
| E-P4-5 任务逐项验收 | §2 | 通过 | §2 |

### 1.1 原始输出

```console
$ CT_STD_DIR=... ct build test/j1_roundtrip.ct -I src -o /tmp/j1p4 && /tmp/j1p4 | tail -1
all checks passed
$ /tmp/j1p4 | grep -c '^ok '
145

$ CT_STD_DIR=... ct build test/j4_decode.ct -I src -o /tmp/j4 && /tmp/j4 | tail -1
all checks passed
$ /tmp/j4 | grep -c '^ok '
16

$ bash tools/check.sh g2
ok g2 (39 R rows, 39 ACC ids, 30 public symbols)
$ grep -q 'status: fixed' issues/JSON-10.md; echo $?
0

$ /tmp/depth1m
depth1m: rc=-9 empty=1        # rc=0
$ /tmp/perf20k
perf20k: sum=20000 elapsed=6.708ms   # rc=0（复核三次 2.750–6.056 ms）
```

## 2. 任务逐项验收

| 任务 | 提交 | verify | 原始输出 | 结果 |
| --- | --- | --- | --- | --- |
| T1 | `2b88322`（红）、`a57502b`（修复） | `ct build test/j1_roundtrip.ct … && /tmp/j1p4` | 145 ok | 通过 |
| T2 | `d97c790`（红）、`2a0ee7a`（实现） | `ct build test/j4_decode.ct … && /tmp/j4` | 16 ok | 通过 |
| T3 | `6f8b0ed` | `bash tools/check.sh g2` | 39 R / 30 symbols | 通过 |
| T4 | `36d9cc3` | `test -f docs/evidence/decode-bounds.md` | rc=0 | 通过 |

## 3. 版本四项核对（6.7 `g4-version`）

| 项 | 值 | 出处 | 结果 |
| --- | --- | --- | --- |
| ① 落点互比 | `0.4.0` | `ct.pkg#version` | 一致 |
| ② `MAJOR.MINOR` 与 `PH-<n>` | `0.4` ↔ `PH-4` | 卡片 `version-minor: 4` | 一致 |
| ③ PATCH 与 fix 数 | `0`（JSON-10 属 phase 内修复，并入 0.4.0） | `ct.pkg`、`CHANGELOG.md` | 一致 |
| ④ CHANGELOG 与 tag | `0.4.0` ↔ `v0.4.0` | `CHANGELOG.md`、`git tag` | 一致 |

## 4. Issue 三去向

| Issue | 状态 | 唯一去向 |
| --- | --- | --- |
| JSON-10 | `fixed` | 本 phase（`a57502b`） |
| JSON-11 | `open` | PH-5（错误位置） |
| JSON-9 | `open` | PH-5（NaN 编码） |
| JSON-3/5/6 | `open` | 语言层 |
| 其余 | `fixed` | PH-1/PH-2 已登记 |

## 5. 门禁状态

| 门禁 | 结果 |
| --- | --- |
| g0 | 收口后 `ok g0 (… version 0.4.0)` |
| g1 | `ok g1 (39 requirement ids, no TBD, 4 phase card(s))` |
| g2 | `ok g2 (39 R rows, 39 ACC ids, 30 public symbols)` |
| g3 | `ok g3 (j1_roundtrip, json.expected.out, zero warnings)` |
| g4/g5 | 退出 2：归 PH-6 |
| g6 | `ok g6 (12 issue(s), statuses and evidence valid)` |
| g7 | `ok g7 (secret scan clean, ASan run clean; detect_leaks unavailable on this platform)` |
| g8 | tag 后通过（见 `docs/evidence/release-PH-4.md`） |
| g9 | `ok g9 (spec 1.15.0 @ 1619a8c37c46)` |

## 6. 回顾（lessons 带 landing）

| # | 教训 | landing |
| --- | --- | --- |
| 1 | **流程偏差**：PH-4 卡在 T1/T2 实现提交后才补立，违反「先开卡再开工」 | `gate:g1`（后续 phase 先立卡；本卡内已披露） |
| 2 | 非有限值检查不能只靠范围比较：NaN 比较全为假，必须单列 `d != d` | `gate:g3`（`1e999` 断言） |
| 3 | UTF-8 校验要拿字节序列构造用例，不能只靠源码字面量；overlong/代理/续字节各有边界 | `gate:g3`（`j4_decode.ct`） |
| 4 | 宽松入口的任何改动都必须保证 strict 不改变既有行为；两模式同根要有断言 | `spec:§3.1` |
| 5 | 性能阈值受机器负载影响（0.9–6.7 ms），验收要留区间与复跑命令，不写单次数字 | `gate:g5`（PH-6 的基准登记） |
| 6 | 「out 不变」要用非零哨兵，0.0 哨兵无法区分未写入与写入 0.0 | `gate:g3`（`dv = 42.5` 断言） |

## 7. 未覆盖声明

- 本报告由 DEV 出具；独立 VERIFY 签字见 §8。
- g4/g5 未实现；泄漏检测（detect_leaks）在 macOS 不可用。
- 未做 10^6 个随机数字与 `strtod` 的 bit-exact 对拍（R-A-09 ①）；本轮只覆盖关键边界。
- 未做 BOM 之外的其他 Unicode 规范化；不做 NFC/NFD（非目标）。

## 8. VERIFY 签字

### 8.1 独立复核（基线 `36d9cc3`）：通过

```text
VERIFY: 通过 | 复核人: verify-ph4 | 日期: 2026-11-17 | 基线: 36d9cc3bedca4dab5db064fa793caa73e2fc9876
```

复核环境实测 CT `v0.63.0`（非早前记录的 v0.62.0）。E-P4-1…E-P4-5 全部通过；
自写 23 条（实数边界）与 41 条（UTF-8/键侧/BOM）探针全绿，ASan 0 命中。

非阻断发现与处置：

| # | 发现 | 处置 |
| --- | --- | --- |
| F1 | 「out 不变」用 0.0 哨兵，断言偏弱 | 改为 `dv = 42.5` 哨兵并复跑 |
| F2 | T1 test 提交正文的失败条目号 120/121/122 与实际 121/122/123 差 1 | 在 `docs/evidence/decode-bounds.md` 更正，不改写历史 |
| F3 | 证据文件写 CT v0.62.0，实测 v0.63.0 | 证据与本报告改 v0.63.0 |
| F4 | requirements 的 R-A-08/09 证据仍指 legacy `json.ct` | 改指 `src/json.h.ct` 与 j1/j4 用例 |
