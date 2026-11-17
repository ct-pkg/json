# PH-5 收口报告

- phase：PH-5（编码边界与错误契约）
- 日期：2026-11-17
- 版本：`0.5.0`（MINOR=5，PATCH=0）
- tag：`v0.5.0`（annotated）
- 卡片：[docs/phases/PH-5/card.md](../docs/phases/PH-5/card.md)

## 1. 交付物 × 退出判据

| 判据 | 交付物 | 结果 | 证据 |
| --- | --- | --- | --- |
| E-P5-1 NaN 编码拒绝 | `test/j5_errors.ct`、`j1_enc_double` | 通过（NaN/Inf/-Inf → NULL + RANGE） | §1.1 |
| E-P5-2 位置/文案/失败清理 | `json_error_*`、`json_message`、j5 | 通过（31 ok；位置 3/1:4、8/2:7；ASan 0；leaks 0） | §1.1 |
| E-P5-3 映射与 issue | 映射、JSON-9/11 | 通过（g2 39 R / 34 symbols；两 issue fixed） | §1.1 |
| E-P5-4 任务逐项验收 | §2 | 通过 | §2 |

### 1.1 原始输出

```console
$ CT_STD_DIR=... ct build test/j5_errors.ct -I src -o /tmp/j5 && /tmp/j5 | tail -1
all checks passed
$ /tmp/j5 | grep -c '^ok '
31
$ /tmp/j5 | grep -e 'offset is' -e 'line/col' -e '1:1' -e '2:7'
ok 13 trailing offset is 3
ok 14 trailing line/col is 1:4
ok 17 the missing colon offset is 8
ok 18 the missing colon is 2:7
ok 20 empty input is at 0, 1:1

$ bash tools/check.sh g2
ok g2 (39 R rows, 39 ACC ids, 34 public symbols)
$ grep -q 'status: fixed' issues/JSON-9.md issues/JSON-11.md; echo $?
0
$ bash tools/check.sh g3
ok g3 (j1_roundtrip, json.expected.out, zero warnings)
$ leaks --atExit --nosources -- /tmp/j5 | tail -1
Process: 0 leaks for 0 total leaked bytes.
```

## 2. 任务逐项验收

| 任务 | 提交 | verify | 原始输出 | 结果 |
| --- | --- | --- | --- | --- |
| T1 | `31a6798`（红）、`fdd1b2c`（修） | `ct build test/j5_errors.ct … && /tmp/j5` | 31 ok | 通过 |
| T2 | `f3d37ce`（红）、`4f89a80`（实现） | 同上 | 31 ok；位置 3/1:4、8/2:7 | 通过 |
| T3 | `0757aac`、`b68fbaa` | `bash tools/check.sh g2` | 39 R / 34 symbols | 通过 |

### 2.1 卡片外的小循环（收口前发现）

| Issue | 缺陷 | 红证 | 修复 |
| --- | --- | --- | --- |
| JSON-13 | CT v0.63.0 把 `2^63` 字面量钳成 INT64_MAX；g3 红、`json_as_int(INT64_MIN)` 误报 RANGE | `ea7777e` | `deaa657`（`+1ULL` 绕行，不改 ct-lang） |
| JSON-14 | 每个对象泄漏 32B Map 头 | `leaks` 9 leaks / 288B | `de87c01`（`o->index->h = z.h`，0 leaks） |

## 3. 版本四项核对（6.7 `g4-version`）

| 项 | 值 | 出处 | 结果 |
| --- | --- | --- | --- |
| ① 落点互比 | `0.5.0` | `ct.pkg#version` | 一致 |
| ② `MAJOR.MINOR` 与 `PH-<n>` | `0.5` ↔ `PH-5` | 卡片 `version-minor: 5` | 一致 |
| ③ PATCH 与 fix 数 | `0`（JSON-9/11/13/14 属 phase 内修复并入 0.5.0） | `ct.pkg`、`CHANGELOG.md` | 一致 |
| ④ CHANGELOG 与 tag | `0.5.0` ↔ `v0.5.0` | `CHANGELOG.md`、`git tag` | 一致 |

## 4. Issue 三去向

| Issue | 状态 | 唯一去向 |
| --- | --- | --- |
| JSON-9 | `fixed` | 本 phase（`fdd1b2c`） |
| JSON-11 | `fixed` | 本 phase（`4f89a80`） |
| JSON-13 | `fixed`（绕行） | 本 phase（`deaa657`）；上游提案另记 |
| JSON-14 | `fixed` | 本 phase（`de87c01`） |
| JSON-3/5/6 | `open` | 语言层 |
| 其余 | `fixed` | PH-1/PH-2/PH-4 已登记 |

## 5. 门禁状态

| 门禁 | 结果 |
| --- | --- |
| g0 | 收口后 `ok g0 (… version 0.5.0)` |
| g1 | `ok g1 (39 requirement ids, no TBD, 5 phase card(s))` |
| g2 | `ok g2 (39 R rows, 39 ACC ids, 34 public symbols)` |
| g3 | `ok g3 (j1_roundtrip, json.expected.out, zero warnings)`（干净 `.ctbuild`） |
| g4/g5 | 退出 2：归 PH-6 |
| g6 | `ok g6 (14 issue(s), statuses and evidence valid)` |
| g7 | `ok g7 (secret scan clean, ASan run clean; detect_leaks unavailable)` |
| g8 | tag 后通过（见 `docs/evidence/release-PH-5.md`） |
| g9 | `ok g9 (spec 1.15.0 @ 1619a8c37c46)` |

## 6. 回顾（lessons 带 landing）

| # | 教训 | landing |
| --- | --- | --- |
| 1 | **干净构建**才能暴露工具链 codegen 回归；`.ctbuild` 缓存会让 g3 假绿 | `gate:g3`（收口前 `rm -rf .ctbuild`） |
| 2 | ASan 不带 `detect_leaks` 看不到泄漏；macOS 要用 `leaks --atExit` 补 | `gate:g5`（PH-6 加泄漏检查项） |
| 3 | 对象创建里的 `Map z = {}` 会分配 header；把 `h` 清零即泄漏 | `gate:g7`（`leaks` 证据） |
| 4 | 卡面写死的「33 symbols」会与实现漂移；判据应以门禁输出为准，不写估计数 | `gate:g1`（卡面少写估计数） |
| 5 | 冻结卡的 §6 基线写错不会影响摘要，但会误导复核；红证基线要写 test 提交 | `spec:6.6 T-7` |
| 6 | 工具链缺陷只能绕行并登记提案，不能改 `ct-lang` | `spec:9.8 DB-5` + JSON-13 |

## 7. 未覆盖声明

- 本报告由 DEV 出具；独立 VERIFY 签字见 §8。
- g4/g5 未实现；LSan/`detect_leaks` 在 macOS 不可用，泄漏检查用 `leaks` 单机补做。
- 未做 OOM 故障注入；`j1_alloc` abort 路径无运行时用例。
- 未做多线程/跨平台复跑。

## 8. VERIFY 签字

### 8.1 首轮（基线 `0757aac`）：不通过

阻断：① 干净 `g3` rc=1（CT v0.63.0 的 2^63 字面量 codegen）；② 每对象 32B 泄漏
（`leaks` 9 leaks/288B），E-P5-2 的「已建节点释放」不成立。文档偏差 6 处。

处置：JSON-13（`deaa657`）、JSON-14（`de87c01`）；文档与证据按发现修正（`b68fbaa`）。

### 8.2 终验（基线 `767549d`）：通过

```text
VERIFY: 通过 | 复核人: verify-ph5 | 日期: 2026-11-17 | 基线: 767549d
```

- 干净 `git archive` 下 g1/g2/g3/g6/g7 全绿；g2 为 39 R / 39 ACC / 34 symbols。
- `leaks`：j5 / j1 / j3 均 0；ASan j5 0 命中。
- 文档项：卡 §0 已登记 34、§6 父提交 `4474ad0`；CT 版本 `v0.63.2`；R-C-03 行号 `346-364`。
- 收口提交与 tag 的 g8 校验见 `docs/evidence/release-PH-5.md`。
