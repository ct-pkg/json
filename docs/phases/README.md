# Phase 卡片与收口

规范依据：[AGENTS.md](../../AGENTS.md) 生成块 §6.2 / §6.6 / §6.7，细节见 [docs/spec/ai-coding-workflow.md](../spec/ai-coding-workflow.md) 全文副本。本目录只放本仓的实参，不复制规范条文。

## 编号与命名

| 项 | 规则 |
| --- | --- |
| 编号 | `PH-<n>`，n 从 1 起连续递增，不跳号、不复用 |
| 目录 | `docs/phases/PH-<n>/`，卡片固定为 `card.md` |
| 别名 | 历史工作线 `J1…J4` 是同一阶段的口语别名，映射在 [roadmap.md](../planning/roadmap.md) 登记；文档正式编号只用 `PH-<n>` |
| 收口回顾 | `reviews/closeout-PH-<n>.md`（复用仓库既有 `docs/review/` 之外的 `reviews/` 目录时，按 6.2 的 `reviews/closeout-<phase>.md`） |

## 开卡必填（10 项，缺一不许立项）

| # | 字段 | 判据 |
| --- | --- | --- |
| 1 | 编号 | `PH-<n>`，与目录名一致 |
| 2 | 目标 | 一句话，可被第三人复述 |
| 3 | 范围 | 明确「做什么 / 不做什么」 |
| 4 | 交付物清单 | 每项一个路径 |
| 5 | 任务清单 | 每项一个交付物、一条验收命令、一次提交、可单独回滚 |
| 6 | 退出判据（冻结） | 每条带命令或可核对锚点，编号 `E-P<n>-*`；正文 digest 写进卡头 `criteria-sha256` |
| 7 | 红证方式 | 基线 sha、复跑方式、原样输出、签字人 |
| 8 | 依赖 | 前置 phase / issue / 外部条件 |
| 9 | 已知风险 | 每条带触发信号 |
| 10 | 元信息 | 卡头含 `version-minor`（等于 n）与开卡时 `规范版本` 快照；任务清单 digest 写进 `tasks-sha256` |

卡片模板见 [_template.md](_template.md)。

## 任务清单的列

任务清单固定 7 列，缺一即不是任务（6.6 T-1…T-7）：

| 列 | 内容 |
| --- | --- |
| `ID` | `T<m>`，与提交信息里的 task-id 一致（跨卡引用写 `PH<n>-T<m>`） |
| `交付物` | 一个主要交付路径；并列且不同目的即退回重切 |
| `提交` | 一个提交；先红后绿时写「test 红 + impl」两笔，并注明 T-7 |
| `回滚` | `git revert` 后哪个门禁或行为回到原状 |
| `verify` | 可复制执行，收口时贴原始输出；不得借用「整个 phase 门禁绿」 |
| `effort` | `S` / `M`；`L` 必须再拆，`XL` 不允许 |
| `覆盖` | 对应 `E-P<n>-*`；一条任务覆盖 ≥2 条即退回重切（T-5） |

## 冻结规则

- 退出判据、任务清单、`version-minor` 在 phase 首个实现提交后不可改；由 `g8-phase-freeze` 拦。
- 需要改判据时关闭当前 phase，另开新 phase；不在原卡上改。
- 任务清单每项四要素不全 → 不许开工；收口有未验收项 → 不许宣称完成（T-6）。

## 退出判据格式

- 至少 3 条，编号 `E-P<n>-<m>`（`PH-<n>` 卡的判据用 `E-P<n>-*`）。
- 每条必须是命令或可核对锚点，写清期望结果（退出码 / 输出片段）。
- 必须有固定一条：「任务清单每项可独立验收（6.6 T-6）」：`E-P<n>-<最后一条>`。
- 语言侧依赖只能登记为 `blocked-by:` 与对应 issue，不得写成「已完成」或「部分完成」。
- 第 5 节正文与第 4 节任务表在开工前算 sha256 写进卡头，之后由 `g1` 与 `g8-phase-freeze` 校验。

## 收口动作

1. 逐条核对退出判据，贴命令与原始输出，不写「已通过」一句话。
2. 核对版本四项（6.7 `g4-version`）：落点互比、`MAJOR.MINOR` 与 `PH-<n>`、PATCH 与本 phase fix 数、CHANGELOG 与 tag。
3. 每个 issue 只有一个去向：本 phase 修 / 未来 phase / 拒绝并写理由。
4. 打 annotated tag `v<MAJOR>.<MINOR>.<PATCH>` 并推送该 tag（6.7 V-7）；分支推送仍须用户指令。
5. 写 `reviews/closeout-PH-<n>.md`，`lessons` 每行有 `landing`（`gate:` / `spec:` / `rejected:`）。
6. 更新 [docs/session-map.md](../session-map.md)。

## 当前清单

立项（开卡）后在此登记；未开卡不预填。

| 编号 | 目标 | 状态 | 卡片 |
| --- | --- | --- | --- |
| PH-1 | J1 收口：链式访问解禁与 JSON-1/2 收口 | closed（2026-11-17，v0.1.1） | [card.md](PH-1/card.md)、[收口报告](../../reviews/closeout-PH-1.md) |
| PH-2 | 需求基线与验收映射（R-* → ACC-*） | closed（2026-11-17，v0.2.0） | [card.md](PH-2/card.md)、[收口报告](../../reviews/closeout-PH-2.md) |
| PH-3 | J3 函数式写入 `json_set` | closed（2026-11-17，v0.3.0） | [card.md](PH-3/card.md)、[收口报告](../../reviews/closeout-PH-3.md) |
| PH-4 | 解码边界（UTF-8、精度、深度、查找、BOM） | 待开卡 | — |
| PH-5 | 编码边界与错误契约 | 待开卡 | — |
| PH-6 | 包交付、发布与验收文档收口 | 待开卡 | — |
