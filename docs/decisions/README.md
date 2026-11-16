# 决策记录（D-<n>）

本目录按 [AGENTS.md](../../AGENTS.md) 生成块与 [docs/spec/ai-coding-workflow.md](../spec/ai-coding-workflow.md) §7.12 的口径存放**规范形态的决策记录**：battle 判决、对已定口径的修订、以及需要独立锚点的主张裁定。

## 与既有 `docs/adr/`、`DECISIONS.md` 的关系

| 位置 | 内容 | 状态 | 谁来写 |
| --- | --- | --- | --- |
| [docs/adr/](../adr/) | `ADR-0001…0007`：0.1.0 实现期的架构决策 | **只读历史**，不再新增 | 当时的技术池会话 |
| [DECISIONS.md](../../DECISIONS.md) | 0.1.0 实现前的选项辩论与裁决 | **只读历史**，不再新增 | 当时的实现侧 |
| `docs/decisions/`（本目录） | 规范 §7.12 的 `D-<n>` 记录 | 唯一新增入口 | 技术池 / 裁判席 |

**不重复两套裁决**：新决定只写本目录，不回写 `docs/adr/` 与 `DECISIONS.md`。若 `D-<n>` 取代了某条 ADR，在 D 记录的 `scope` 写明被取代的文件与条目，并在该 ADR 文件末尾**追加**一行「已被 `D-<n>` 取代」的注记；原文不删不改。反之，ADR 未被 D 记录取代时继续有效。

## 编号与命名

- `D-<n>`，三位起（`D-001`），连续递增，不复用。
- 一个文件一条记录：`docs/decisions/D-<n>.md`。
- battle 产物：`battle/<battle-id>/` 下的 `claim.md` / `counter.md` / `verify.json` / `verdict.md`，判决落到同编号的 D 记录；庭会话本身不写源码、不写主张。

## 格式

front-matter 与正文段落按 §7.12，模板见 [_template.md](_template.md)。front-matter 十个字段缺一不算登记：

`id`、`date`、`anchor`、`trigger`、`status`、`verdict`、`judge`、`seats`、`scope`、`spec-claim`。

- `status` 只能是 `accepted` / `rejected` / `superseded`。
- `verdict` 只能是 `upheld` / `rejected` / `undecidable` / `escalate`；`escalate` 表示超出 battle 权限，交用户裁定。
- `anchor` 是判决所依据的 HEAD sha，必须能在本仓 `git cat-file -e`。

## 只追加，不回写（A-1…A-3）

结论四段——`verdict`、`判据`、`理由`、`失效条件`——落盘后不得修改；修订只在文件末尾新增「追加注记」，写全三项：

```markdown
## 追加注记
superseded-by: D-<n>
date: <YYYY-MM-DD>
what-changed: <哪个前提/判据/失效条件被证伪，取代了什么>
```

缺任一项按「无结论关闭」处理（G6）。`status` 只在被取代时改为 `superseded`，不得删除 `verdict`。

## battle 的权限边界

- battle 只裁决**小事情**：实现细节、命名、夹具写法、门禁实现方式。
- **大决定不进 battle**：改已定决策、改需求范围或验收项、版本与发布口径、跨包依赖与架构、放弃或推迟验收——先对照 [docs/requirements.md](../requirements.md) 与 [docs/planning/roadmap.md](../planning/roadmap.md) 的大方向；违背大方向即停在原地报用户，battle 不得为违背需求的做法找理由。
- 语言侧缺口只能登记成 `blocked-by:` 与 issue，不得用 battle 把「绕过语言缺口」写成决定。

## 索引

| 编号 | 日期 | 主题 | verdict | 状态 |
| --- | --- | --- | --- | --- |
| D-001 | 2026-11-17 | Q-03 错误模型 | upheld | accepted |
| D-002 | 2026-11-17 | Q-05 Unicode/BOM | upheld | accepted |
| D-003 | 2026-11-17 | Q-06 包形态 | upheld | accepted |
| D-004 | 2026-11-17 | Q-07 树形状与所有权 | upheld | accepted |
| D-005 | 2026-11-17 | Q-08 深度与性能 | upheld | accepted |
| D-006 | 2026-11-17 | Q-09 编码失败与数字输出 | upheld | accepted |
