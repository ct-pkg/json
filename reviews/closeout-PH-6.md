# PH-6 收口报告

- phase：PH-6（交付、门禁收口与首版）
- 日期：2026-11-17
- 版本：`0.6.0`（MINOR=6，PATCH=0）
- tag：`v0.6.0`（annotated）
- 卡片：[docs/phases/PH-6/card.md](../docs/phases/PH-6/card.md)

## 1. 交付物 × 退出判据

| 判据 | 交付物 | 结果 | 证据 |
| --- | --- | --- | --- |
| E-P6-1 所有非派生文档 ≤300 行 | 规范/合论/反证拆分 + `tools/check-doc-size.sh` | 通过（57 个文件） | §1.1 |
| E-P6-2 README 七节 + 许可 + applies-to | `README.md` | 通过 | §1.1 |
| E-P6-3 g4 绿 + 负例 | `tools/check.sh`、`tools/negatives/run.sh` | 通过 | §1.1 |
| E-P6-4 g5 绿 + 负例 | 同上、`docs/evidence/red-proofs.md` | 通过（22 任务） | §1.1 |
| E-P6-5 导出面冻结 + requires 一致 | `docs/api-surface.txt`、`tools/export-surface.sh` | 通过（41 符号） | §1.1 |
| E-P6-6 全门禁绿（tag 后） | `bash tools/check.sh all` | 通过（0 unimplemented） | §1.1 |
| E-P6-7 任务逐项验收 | §2 | 通过 | §2 |

### 1.1 原始输出

```console
$ bash tools/check-doc-size.sh
ok doc-size (57 files <= 300 lines; AGENTS block and spec copy exempt)

$ grep -q '^## 许可' README.md && grep -q 'applies-to' README.md; echo $?
0

$ bash tools/check.sh g4
ok g4 (6 snippets, 2 fail samples, anchors, readme, version 0.6.0)
$ bash tools/negatives/run.sh g4
red ok g4 oversized document           gate g4 rc=1 | FAIL doc-size: ... has 301 lines (max 300)
$ echo $?
0

$ bash tools/check.sh g5
ok g5 (22 tasks, 9 red proofs, gate negatives covered)
$ bash tools/negatives/run.sh g5
red ok g5 missing task row             gate g5 rc=1 | FAIL g5: missing red proof for PH3-T1
red ok g5 baseline not a commit        gate g5 rc=1 | FAIL g5: PH4-T1: baseline deadbee is not a commit
$ echo $?
0

$ bash tools/export-surface.sh
ok export-surface (41 symbols; requires "ct >= 0.53.0")

$ bash tools/check.sh all
=== summary: 0 unimplemented gate(s)
$ echo $?
0
```

## 2. 任务逐项验收

| 任务 | 提交 | verify | 原始输出 | 结果 |
| --- | --- | --- | --- | --- |
| T1 | `27b9069` | `bash tools/check-doc-size.sh` | 57 files ≤300 | 通过 |
| T2 | `66b0cb2` | `grep 许可 && grep applies-to` | rc=0 | 通过 |
| T3 | `e43eaac` | `check.sh g4` + `run.sh g4` | g4 绿；负例 rc=1 | 通过 |
| T4 | `894ade0` | `check.sh g5` + `run.sh g5` | g5 绿；两条负例 rc=1 | 通过 |
| T5 | `0227fd8` | `bash tools/export-surface.sh` | 41 symbols；requires 一致 | 通过 |

## 3. 版本四项核对（6.7 `g4-version`）

| 项 | 值 | 出处 | 结果 |
| --- | --- | --- | --- |
| ① 落点互比 | `0.6.0` | `ct.pkg#version`；README/规范/snippets 的 `applies-to` | 一致 |
| ② `MAJOR.MINOR` 与 `PH-<n>` | `0.6` ↔ `PH-6` | 卡片 `version-minor: 6` | 一致 |
| ③ PATCH 与 fix 数 | `0`（本 phase 无 fix） | `ct.pkg`、`CHANGELOG.md` | 一致 |
| ④ CHANGELOG 与 tag | `0.6.0` ↔ `v0.6.0` | `CHANGELOG.md`、`git tag` | 一致 |

## 4. Issue 三去向

| Issue | 状态 | 唯一去向 |
| --- | --- | --- |
| JSON-1/2/4/7/8/9/10/11/12/13/14 | `fixed` | PH-1…PH-5 已收口 |
| JSON-3/5/6 | `open` | 语言层依赖（roadmap 语言侧） |

## 5. 门禁状态

| 门禁 | 结果 |
| --- | --- |
| g0–g9 | 全绿（`all` 的 0 unimplemented；详见 §1.1） |
| g4 | `ok g4 (6 snippets, 2 fail samples, anchors, readme, version 0.6.0)` |
| g5 | `ok g5 (22 tasks, 9 red proofs, gate negatives covered)` |
| surface | `ok export-surface (41 symbols; requires "ct >= 0.53.0")` |
| g8 | tag 后通过（见 `docs/evidence/release-PH-6.md`） |

## 6. 回顾（lessons 带 landing）

| # | 教训 | landing |
| --- | --- | --- |
| 1 | 文档超过 300 行不会自己变红；g4-size 接入后才发现 3 份超限 | `gate:g4`（doc-size） |
| 2 | 相对链接在拆分/搬目录时最容易断；g4-anchors 一次抓出 9 处 | `gate:g4`（anchors） |
| 3 | 导出面不冻结就会随实现漂移；`api-surface.txt` + 脚本让漂移变红 | `gate:surface` / `g4` |
| 4 | 红证登记不能只写在卡片里；`red-proofs.md` + baseline 祖先校验才可机器核对 | `gate:g5` |
| 5 | 门禁负例必须用真实 `.git` 克隆（g5 走 ancestry），`git archive` 会让它红错原因 | `gate:g5`（负例 clone） |

## 7. 未覆盖声明

- 本报告由 DEV 出具；独立 VERIFY 签字见 §8。
- g4 只编译 `docs/snippets/` 下的完整程序；行内代码片段不逐个编译，由测试覆盖。
- macOS 无 `detect_leaks`，泄漏用 `leaks --atExit` 单机补测。
- 未做 Linux/CI、跨平台、fuzz、性能回归。
- 0.x 不承诺 C ABI；包根迁移不做（D-003）。

## 8. VERIFY 签字

### 8.1 终验

（终验签字待填）
