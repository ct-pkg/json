# Issue 台账

规范依据：[AGENTS.md](../../AGENTS.md) §5.4 与 §6.4 G6，细节见 [docs/spec/ai-coding-workflow.md](../spec/ai-coding-workflow.md)。

## 编号与文件

- 编号 `JSON-<n>`，连续递增，不复用；一条一个文件：`issues/JSON-<n>.md`。
- 既有条目：`JSON-1`（三级下标链，v0.62.0 已 `fixed`）、`JSON-2`（临时值接收者，v0.62.0 已 `fixed`）、`JSON-3`（`char *`→`Str` 诊断分级，`open`）、`JSON-4`（包无法被消费，`fixed`）、`JSON-5`（链式结果作实参/条件）、`JSON-6`（三级写链）、`JSON-7`（g7 负例夹具自命中，`fixed`）、`JSON-8`（g8 把 phase 收口当 fix，`fixed`）、`JSON-9`（NaN 编码）、`JSON-10`（`as_double` 溢出）、`JSON-11`（解析错误无 offset/行列，`open`）、`JSON-12`（控制字节转义多写两位，`fixed`）、`JSON-13`（CT v0.63.0 2^63 字面量 codegen，`fixed` 绕行）、`JSON-14`（对象 Map 头泄漏，`fixed`）。
- 本文件只管模板与状态词，不复制条目正文。

## 条目格式

新条目用 front-matter，缺 `status` 或证据字段即 G6 失败：

```markdown
---
id: JSON-<n>
status: open
priority: P0 | P1 | P2 | P3
owner: 语言层 | 本包 | 构建 | 文档
created: <YYYY-MM-DD>
last-touched: <YYYY-MM-DD>
block: <为空或写阻塞条件；非空必须写复核日期>
evidence: <复现命令 + file:line / 原始输出所在路径>
---

# JSON-<n> <一句话标题>

## 触发条件

## 最小复现

```console
$ <command>
<原始输出>
$ echo $?
<n>
```

## 期望行为

## 处置（仅 fixed 时写，含提交 sha 与验证命令输出）

## 关联
```

14 条均已改为 front-matter；`JSON-1`/`JSON-2` 在 PH-1 由旧「`- status:` 列表」升级为 front-matter，状态与证据内容按 v0.62.0 复跑更新。

## 状态词与分权（5.4）

| 状态词 | 谁能写 | 含义 | 必备证据 |
| --- | --- | --- | --- |
| `open` | REV / REQ | 已立案 | 复现命令或 `file:line` |
| `fixed` | DEV（写处置段，不动状态字段） | 主张已修复 | 提交 sha + 验证命令原始输出 |
| `verified` | REV | 复核通过 | 独立复现 + 逐条对照 |
| `reopened` | REV | 复核未过 | 失败复现 |
| `rejected` | REQ / USER | 不采纳 | 理由；涉及规范时附决策记录 id |
| `deferred` | REQ / USER | 延后 | 触发条件或日期 |
| `wontfix` | USER | 永不修 | 理由 |
| `superseded` | REQ | 被新条目取代 | 新条目 id |

`status` 必须属于上表。**本仓取 front-matter 的 `status: fixed` + 正文处置段**：5.4 判据里「`fixed` 不得写入 `status`」与状态词表本身冲突，`G6` 实现与 PH-1 的 `E-P1-4` 都按状态词表执行；该冲突已在 PH-1 收口报告登记为规范缺陷提案，不在此处改规范。

## 关闭与去向

- 每个 phase 收口时，该 phase 涉及的每个 issue 只能有一个去向：本 phase 修 / 登记到某个未来 phase / 明确拒绝并写理由（无第四种「先放着」）。
- `deferred` 必须写目标 phase 或日期；到期未处理由 G6 `g6-pool` 拦。
- 无结论关闭即失败：状态变更必须带证据。

## 证据要求

- 复现必须是**修复前**的失败输出，含 `baseline: <sha>`、命令、原始输出、退出码（6.6 T-7）。
- 用修好后的代码复跑不算红证。
- 语言层 issue 的归属写「上游 ct <实测版本>」，不得记成本包缺陷；本包只负责登记、复现与在解锁后收口。
