# PH-3 收口报告

- phase：PH-3（函数式路径写入 `json_set`）
- 日期：2026-11-17
- 版本：`0.3.0`（MINOR=3，PATCH=0）
- tag：`v0.3.0`（annotated，指向本收口提交）
- 卡片：[docs/phases/PH-3/card.md](../docs/phases/PH-3/card.md)

## 1. 交付物 × 退出判据

| 判据 | 交付物 | 结果 | 证据 |
| --- | --- | --- | --- |
| E-P3-1 `json_set` 正向、失败契约、所有权与保位由夹具覆盖并绿 | `test/j3_json_set.ct`、`src/json.h.ct` | 通过（55 ok，`all checks passed`；复核后补 8 条畸形路径断言） | §1.1 |
| E-P3-2 API 入规范与映射，g2 覆盖 39 条 R-* | `docs/spec/ct-json-0.1.0.md` §3.8、`R-D-09`、`ACC-39` | 通过（g2：39/39/29） | §1.1 |
| E-P3-3 任务清单每项可独立验收 | §2 | 通过 | §2 |

### 1.1 原始输出

```console
$ CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build test/j3_json_set.ct -I src -o /tmp/j3 && /tmp/j3 | tail -3
ok 53 overwrite the first key
ok 54 overwrite keeps the first key position
ok 55 overwrite keeps the object size
all checks passed
$ /tmp/j3 | grep -c '^ok '
55

$ bash tools/check.sh g2
ok g2 (39 R rows, 39 ACC ids, 29 public symbols)
$ grep -q 'json_set' docs/spec/ct-json-0.1.0.md; echo $?
0

$ bash tools/check.sh g3
ok g3 (j1_roundtrip, json.expected.out, zero warnings)
$ bash tools/check.sh g7
ok g7 (secret scan clean, ASan run clean; detect_leaks unavailable on this platform)
```

## 2. 任务逐项验收

| 任务 | 提交 | verify | 原始输出 | 结果 |
| --- | --- | --- | --- | --- |
| T1 | `b3bd964`/`54ec376`（初版）、`e7503c8`/`0312fc1`（畸形路径修复） | `ct build test/j3_json_set.ct -I src -o /tmp/j3 && /tmp/j3` | 55 ok，`all checks passed`，rc=0 | 通过 |
| T2 | `b6ba7ab` | `bash tools/check.sh g2` | `ok g2 (39 R rows, 39 ACC ids, 29 public symbols)` | 通过 |

T1 红证：基线 `v0.2.0`（`875b0d8`）上夹具编译失败 `call to undeclared function 'json_set'`，rc=1；实现提交紧随 test 提交。

## 3. 版本四项核对（6.7 `g4-version`）

| 项 | 值 | 出处 | 结果 |
| --- | --- | --- | --- |
| ① 落点互比 | `0.3.0` | `ct.pkg#version`（唯一落点） | 一致 |
| ② `MAJOR.MINOR` 与 `PH-<n>` | `0.3` ↔ `PH-3` | 卡片 `version-minor: 3` | 一致 |
| ③ PATCH 与 fix 数 | `0`（本 phase 无 fix） | `ct.pkg`、`CHANGELOG.md` | 一致 |
| ④ CHANGELOG 与 tag | `0.3.0` ↔ `v0.3.0` | `CHANGELOG.md`、`git tag` | 一致 |

## 4. Issue 三去向

| Issue | 状态 | 唯一去向 |
| --- | --- | --- |
| JSON-6 | `open` | 语言层，PH-3 不绕过写链 |
| JSON-9 / JSON-10 / JSON-11 | `open` | PH-5 / PH-4 / PH-5（与 json_set 无关） |
| 其余已 fixed | — | PH-1/PH-2 已登记 |

首轮 VERIFY 发现畸形路径段漏检（`a.`/`a..b` 在缺失子树后静默创建空键），
已在 phase 内按 T-7 红（`e7503c8`）→ 绿（`0312fc1`）修复，不新开 issue；
收口时并入 0.3.0。

## 5. 门禁状态

| 门禁 | 结果 |
| --- | --- |
| g0 | 收口后 `ok g0 (… version 0.3.0)` |
| g1 | `ok g1 (39 requirement ids, no TBD, 3 phase card(s))` |
| g2 | `ok g2 (39 R rows, 39 ACC ids, 29 public symbols)` |
| g3 | `ok g3 (j1_roundtrip, json.expected.out, zero warnings)` |
| g4 | 退出 2：归 PH-6 |
| g5 | 退出 2：归 PH-6 |
| g6 | `ok g6 (12 issue(s), statuses and evidence valid)` |
| g7 | `ok g7 (secret scan clean, ASan run clean; detect_leaks unavailable on this platform)` |
| g8 | 收口 tag 后通过（见 `docs/evidence/release-PH-3.md`） |
| g9 | `ok g9 (spec 1.15.0 @ 1619a8c37c46)` |

## 6. 回顾（lessons 带 landing）

| # | 教训 | landing |
| --- | --- | --- |
| 1 | 路径段不能用借用 `Str`：`Str` 带 Drop，scope 退出会 free 借来的指针 | `gate:g3`（ASan 跑夹具） |
| 2 | 路径写入的原子性要先做只读校验，再做创建/写入；否则类型冲突会留下半棵树 | `spec:§3.8` |
| 3 | 新 API 必须在同一 phase 补需求 ID 与 `ACC-*`，否则 g2 的 38 条口径会把它漏掉 | `gate:g2`（39 R / 39 ACC） |
| 4 | 「实现前编译失败」也是合法红证，但要写清基线、命令与 rc | `gate:g8`（T-7 test 提交是 impl 父提交） |
| 5 | 点号是路径分隔符，含 `.` 的键不能走 `json_set`；能力边界写进规范而不是口头说明 | `spec:§3.8` |
| 6 | 校验 pass 在「首个缺失中间对象」处提前退出，会漏掉其后的空段；校验必须遍历完整路径 | `gate:g3`（`syntax_contract` 的 8 条断言） |
| 7 | MEMORY 承诺要与分配的失败模式一致；`j1_alloc` abort 时不能声称返回 MEMORY | `spec:§3.8` |

## 7. 未覆盖声明

- 本报告由 DEV 出具；独立 VERIFY 签字见 §8。
- g4/g5 未实现；泄漏检测（ASan `detect_leaks`）在 macOS 不可用。
- 路径写入只测对象键；数组下标段、转义点号、深路径分配失败未覆盖，属明确非目标。
- 性能未单独基准：`json_set` 是 O(路径段数 × 容器查找)，未做大对象压测。

## 8. VERIFY 签字

### 8.1 首轮（基线 `b6ba7ab`）：不通过

发现 P1：畸形段位于首个缺失中间对象之后时返回 `JSON_OK` 并创建空字符串键
（`a.`/`a..b`/`a.b.`/`a...b`）。P2：夹具只用「前缀已存在」的树，掩盖了该形态。
P3：§3.8 的 MEMORY 承诺与 `j1_alloc` 的 abort 不一致。

处置：补 `syntax_contract`（8 条断言，独立空树）→ 红 `e7503c8`；修校验/写入两遍 →
绿 `0312fc1`；收紧 §3.8 的 MEMORY 措辞；夹具 55 条全绿，ASan 0 命中。

### 8.2 终验（基线 `0312fc1`）

```text
VERIFY: 通过 | 复核人: verify-ph3 | 日期: 2026-11-17 | 基线: 0312fc1
```

- 畸形路径 21 条穷举 0 mismatch；77 条独立探针全过；ASan 0 命中。
- 夹具 55 ok；修复的 T-7 红证与 `e7503c8` 记录逐条一致。
- g2 / g3 / g7 均 rc=0。
- 非阻断建议：§3.8 的 MEMORY 措辞再细分（容器扩容也返回 MEMORY），已在收口提交采纳。
- 收口提交与 tag 的 g8 校验由收口动作完成后补，见 `docs/evidence/release-PH-3.md`。
