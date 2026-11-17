# PH-<n> 卡：<目标一句话>

- 编号：PH-<n>
- phase 目录：`docs/phases/PH-<n>/`
- version-minor：<n>
- 规范版本：<开卡时 AGENTS.md 生成块头的 version>
- 状态：draft
- criteria-sha256：<对 `## 5. 退出判据（冻结）` 正文算 sha256，冻结后不得变>
- tasks-sha256：<对 `## 4. 任务清单` 正文算 sha256，冻结后不得变>

## 0. 编号与元信息

| 项 | 值 |
| --- | --- |
| 编号 | PH-<n>（与目录 `docs/phases/PH-<n>/` 一致） |
| 对应 roadmap | [roadmap](../planning/roadmap.md) |
| 需求 / issue | <R-* / JSON-*；没有写「无」> |
| 版本 | 收口时 `ct.pkg#version` 的 MINOR 等于 `version-minor`；PATCH 由 fix 数决定，不写进卡 |
| 不为 | <本 phase 明确不碰的范围；语言侧缺口只登记依赖，不绕过、不降级> |

## 1. 目标

<一句话，可被第三人复述；不要写「差不多可用」。>

## 2. 范围

### 2.1 做什么

- <...>

### 2.2 不做什么

- <...>
- 不降低既有门禁的判定阈值；不为了让门禁变绿而改判定逻辑。
- 语言侧未具备的能力（属性访问、数字下标、容器迭代、`char *` 字面量→`Str` 等）只登记为 `blocked-by:` 与 issue。

## 3. 交付物清单

| 路径 | 内容 |
| --- | --- |
| `<path>` | <...> |

## 4. 任务清单

| ID | 交付物 | 提交 | 回滚 | verify | effort | 覆盖 |
| --- | --- | --- | --- | --- | --- | --- |
| T1 | `<path>` | `test(...) 红` + `feat(...)`（T-7）或 `no-test: <理由>` | `git revert` 后 <哪个门禁/行为回到原状> | `<command>` | S/M | E-P<n>-1 |

## 5. 退出判据（冻结）

| 编号 | 判据 | 核对方式 |
| --- | --- | --- |
| E-P<n>-1 | <...> | `<command>`，期望 <退出码 / 输出片段> |
| E-P<n>-2 | <...> | `<command>`，期望 <...> |
| E-P<n>-3 | <...> | `<command>`，期望 <...> |
| E-P<n>-4 | 任务清单每项可独立验收（6.6 T-6） | 逐项贴各任务 `verify` 的原始输出 |

## 6. 红证方式

- 基线：`baseline: <实现前的提交 sha>`；`git merge-base --is-ancestor <baseline> HEAD` 必须为真。
- 复跑：`git archive <baseline> | tar -x -C /tmp/<task-id>` 后按本项目方式构建；不得用工作树当前产物。
- 记录：每条红证写命令、原始输出、退出码；红证由 VERIFY 认定签字（3.6），DEV 不自签。
- `no-test:` 只覆盖纯文档 / 纯配置 / 纯注释，且需评审签字。

## 7. 依赖

| 类型 | 依赖 | 状态 | 说明 |
| --- | --- | --- | --- |
| phase / issue / 外部 | <...> | `open` / `fixed` / `blocked` | <...> |

## 8. 已知风险

| # | 风险 | 触发信号 | 处置 |
| --- | --- | --- | --- |
| 1 | <...> | <...> | <...> |

## 9. 收口动作

| # | 动作 | 证据 |
| --- | --- | --- |
| 1 | 逐条核对第 5 节，贴命令与原始输出 | <...> |
| 2 | 版本四项核对（6.7 `g4-version`） | <...> |
| 3 | 每个 issue 登记唯一去向 | <...> |
| 4 | 打 annotated tag 并推送该 tag（V-7） | `v<MAJOR>.<MINOR>.<PATCH>` |
| 5 | 写 `reviews/closeout-PH-<n>.md`（`lessons` 带 `landing`） | <...> |
| 6 | 更新 `docs/session-map.md` 与本目录清单 | <...> |
