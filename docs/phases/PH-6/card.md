# PH-6 卡：交付、门禁收口与首版发布

- 编号：PH-6
- phase 目录：`docs/phases/PH-6/`
- version-minor：6
- 规范版本：1.15.0
- 状态：in-progress
- criteria-sha256：11e251ba69fca3534ce28951fc786e82ea00f44ca91eee3496b2e432f49e7fac
- tasks-sha256：2718cc79c05fd5512d673f811a91800ed28a9d1263ca3a605700322a0631d8df

## 0. 编号与元信息

| 项 | 值 |
| --- | --- |
| 编号 | PH-6（与目录 `docs/phases/PH-6/` 一致） |
| 对应 roadmap | [roadmap](../planning/roadmap.md) 的 PH-6（交付） |
| 需求 / issue | R-E-02、R-E-03、R-E-04、R-E-05、R-E-06；R-E-01 复核 |
| 版本 | 收口时 `ct.pkg#version` 为 `0.6.0`（MINOR=6，PATCH=0） |
| 不为 | 不做包根迁移（D-003）；不做 C ABI 承诺；不改主规范 |

## 1. 目标

把 `g4`（文档可执行与时效）与 `g5`（测试自证）接入，拆掉超 300 行的文档，重写 README 到树 API，冻结公开导出面，做到 `bash tools/check.sh all` 全绿并打首版 tag。

## 2. 范围

### 2.1 做什么

- 拆分 `docs/spec/ct-json-0.1.0.md`、`docs/review/ct-json-0.1.0-verdict.md`、`docs/review/ct-json-0.1.0-rebuttal.md`，全部 ≤300 行。
- 重写 `README.md`：树 API、安装/import、最小示例、API 索引、限制、版本、许可；加 `applies-to`。
- `g4`：`g4-size`（AGENTS 块与主规范副本豁免）、`g4-snippets`（snippets 可跑 / fail 必失败）、`g4-anchors`（相对链接存在）、`g4-readme`（节标题）、`g4-version`（版本落点/CHANGELOG/tag/applies-to）。
- `g5`：`docs/evidence/red-proofs.md` 登记逐任务红证；校验 baseline 是 HEAD 祖先；校验门禁负例证据覆盖已实现门禁。
- 冻结导出面：`docs/api-surface.txt` + `tools/export-surface.sh`；`src/json.h.ct` 加 `//@ct-requires`。
- README 许可段；`//@ct-requires` 与 `ct.pkg#requires` 一致。

### 2.2 不做什么

- 不把 `g4` 做成“每个行内代码片段都编译”；只编译 `docs/snippets/` 下的完整程序，行内片段由 §3.8/§5 的测试覆盖。
- 不豁免 `docs/review/` 的 300 行限制（历史文档同样分拆；主规范全文副本按 DOC-S8 同理豁免）。
- 不做发布到远端 registry 或对外公告；只打并推 phase tag。

## 3. 交付物清单

| 路径 | 内容 |
| --- | --- |
| `docs/spec/ct-json-0.1.0.md` + `-details.md` | 规范拆分 |
| `docs/review/ct-json-0.1.0-verdict*.md`、`-rebuttal*.md` | 评审记录拆分 + 索引 |
| `README.md` | 树 API、安装、示例、API 索引、限制、版本、许可、`applies-to` |
| `tools/check.sh` | `g4`、`g5` |
| `tools/negatives/run.sh` | g4/g5 负例 |
| `docs/evidence/red-proofs.md` | 逐任务红证登记 |
| `docs/api-surface.txt`、`tools/export-surface.sh` | 导出面冻结 |
| `tools/check-doc-size.sh` | 300 行限制的可复用检查（g4 复用） |
| `src/json.h.ct` | `//@ct-requires` |
| `CHANGELOG.md` | 0.6.0 |

## 4. 任务清单

| ID | 交付物 | 提交 | 回滚 | verify | effort | 覆盖 |
| --- | --- | --- | --- | --- | --- | --- |
| T1 | `docs/spec/ct-json-0.1.0*.md`、`docs/review/*.md`、`tools/check-doc-size.sh` | `docs: PH6-T1 拆分长文档` | 超 300 行文档回来 | `bash tools/check-doc-size.sh` | M | E-P6-1 |
| T2 | `README.md` | `docs: PH6-T2 重写 README` | README 又回旧视图描述 | `grep -q '^## License' README.md && grep -q 'applies-to' README.md` | M | E-P6-2 |
| T3 | `tools/check.sh`、`tools/negatives/run.sh` | `feat(gate): PH6-T3 接入 g4` | g4 退出 2 | `bash tools/check.sh g4 && bash tools/negatives/run.sh g4` | M | E-P6-3 |
| T4 | `tools/check.sh`、`docs/evidence/red-proofs.md` | `feat(gate): PH6-T4 接入 g5` | g5 退出 2 | `bash tools/check.sh g5 && bash tools/negatives/run.sh g5` | M | E-P6-4 |
| T5 | `docs/api-surface.txt`、`tools/export-surface.sh`、`src/json.h.ct` | `feat(pkg): PH6-T5 冻结导出面` | 导出面漂移 | `bash tools/export-surface.sh` | S | E-P6-5 |

## 5. 退出判据（冻结）

| 编号 | 判据 | 核对方式 |
| --- | --- | --- |
| E-P6-1 | 所有非派生文档 ≤300 行（AGENTS 块与主规范副本除外） | `bash tools/check-doc-size.sh` rc=0 |
| E-P6-2 | README 覆盖安装/读取/写入/编码/限制/版本/许可，带 `applies-to` | `grep -q '^## License' README.md && grep -q 'applies-to' README.md` rc=0 |
| E-P6-3 | g4 绿：size/snippets/anchors/readme/version | `bash tools/check.sh g4` rc=0；`bash tools/negatives/run.sh g4` rc=0 |
| E-P6-4 | g5 绿：逐任务红证齐全、baseline 祖先、门禁负例覆盖 | `bash tools/check.sh g5` rc=0；`bash tools/negatives/run.sh g5` rc=0 |
| E-P6-5 | 导出面冻结且与实现一致；`//@ct-requires` 与 `ct.pkg#requires` 一致 | `bash tools/export-surface.sh` rc=0 |
| E-P6-6 | 全门禁绿（tag 后） | `bash tools/check.sh all` rc=0 |
| E-P6-7 | 任务清单每项可独立验收（6.6 T-6） | 逐项贴 T1–T5 的 `verify` 原始输出 |

## 6. 红证方式

- 本 phase 的 g4/g5 是门禁实现，负例随同一提交入库（8.3）。
- T1/T2 为纯文档，`no-test:`（拆分与重写不改变行为）。
- g5 的登记表覆盖 PH-1…PH-5 的任务红证。

## 7. 依赖

| 类型 | 依赖 | 状态 | 说明 |
| --- | --- | --- | --- |
| phase | PH-1…PH-5 | closed | 功能与证据已就绪 |
| 决策 | D-003（包形态）、D-006（编码） | accepted | 交付口径 |

## 8. 已知风险

| # | 风险 | 触发信号 | 处置 |
| --- | --- | --- | --- |
| 1 | 拆文档断链 | g4-anchors 红 | 先拆再跑 g4，逐条修链接 |
| 2 | g4-version 在 tag 前红 | 收口前 `all` 非零 | 版本/tag 在收口动作内一起做 |
| 3 | g5 变成“只查文本” | 负例不能变红 | g5 负例：删任务行/改 baseline 即红 |
| 4 | README 行内代码块被误当完整程序 | g4-snippets 红 | 只编译 `docs/snippets/` 下的文件 |

## 9. 收口动作

| # | 动作 | 证据 |
| --- | --- | --- |
| 1 | 逐条核对第 5 节，贴 T1–T5 原始输出 | 本卡收口段 |
| 2 | 版本四项核对：`0.6.0`，MINOR=6，PATCH=0 | `ct.pkg`、`CHANGELOG.md` |
| 3 | 每个 issue 登记唯一去向 | `issues/` |
| 4 | 打 annotated tag `v0.6.0` 并推送（V-7） | `git cat-file -t v0.6.0` |
| 5 | 写收口回顾（`lessons` 带 `landing`） | `reviews/closeout-PH-6.md` |
| 6 | 更新 `docs/session-map.md` 与本目录清单 | 同上 |
