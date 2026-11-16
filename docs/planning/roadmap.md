# 路线图

> 本文件只排 phase 的顺序与边界，不自造条目。条目来源：[docs/requirements.md](../requirements.md)、[docs/spec/ct-json-0.1.0.md](../spec/ct-json-0.1.0.md)、[docs/spec/ct-json-0.1.0-completion.md](../spec/ct-json-0.1.0-completion.md) §四、[docs/spec/ct-json-delivery-backlog.md](../spec/ct-json-delivery-backlog.md)。与需求冲突时以需求为准。

## 规则

- 每个 phase 一张 [卡片](phases/README.md)，编号 `PH-<n>` 连续递增，`version-minor` 等于 n。
- 立项与拆分属**大决定**：先核对需求与交付待办；违背方向即停止报用户。battle 只解决小事情。
- 语言侧缺口只登记为 `blocked-by:` 与 issue，不降级需求、不假装完成。

## 阶段清单

| 编号 | 别名 | 目标 | 主要需求 | 依赖 | 状态 |
| --- | --- | --- | --- | --- | --- |
| PH-1 | J1 收口 | 把 CT v0.62.0 已支持的三级读链/方法结果链固化进回归与文档，收口 JSON-1/2 | R-D-07、R-A-06/07（已满足项的边界复核） | CT >= 0.62.0（已装） | 开卡 |
| PH-2 | — | 需求基线与验收映射：R-A…R-E 逐条对照实现与用例，产出 `docs/acceptance-map.md`（ACC-*），接入 g2 | 全部 R-* 的现状锚定 | PH-1 | 待开卡 |
| PH-3 | J3 写能力 | 纯函数式写入 `json_set`（路径写入）与重复键语义 | R-D-08、R-D-03（证据） | PH-2 | 待开卡 |
| PH-4 | — | 解码边界：UTF-8 开关、实数精度、深度硬上限、大容器查找、BOM | R-A-08、R-A-09、R-A-10、R-A-11、R-A-12 | PH-2；Q-05/Q-08 裁定 | 待开卡 |
| PH-5 | — | 编码边界与错误契约：含 NUL 字符串、截断可判定、原生容器编码、往返、错误码/文案 | R-B-04、R-B-05、R-B-06、R-B-07、R-C-03、R-C-05 | PH-2、PH-3 | 待开卡 |
| PH-6 | 交付 | 包清单/单元根/import 形态、首版发布、验收文档与门禁收口 | R-E-01、R-E-02、R-E-04、R-E-05、R-E-06 | PH-3…PH-5 | 待开卡 |

## 已关闭、不占 phase

| 事项 | 结论 | 依据 |
| --- | --- | --- |
| J2 路径助手 `json_get` | **不复活**；访问入口仍是下标协议 + `get_idx` | [ADR-0007](../adr/0007-js-style-access.md) |
| 已满足的 R-A-01…05、R-B-01…03、R-C-01/02/04、R-D-01…07、R-E-03 | 由 PH-2 的验收映射逐条锚定到现有用例；不重复实现 | `docs/requirements.md`、0.1.0 用例 |

## 语言侧依赖（不排 phase，不假装完成）

以下被 R1–R6 挡住，只登记 issue；CT 侧落地后再评估是否排 phase：

| 能力 | 受阻的需求 / 事项 | 登记 |
| --- | --- | --- |
| 属性访问 `doc.server` | JS 风格 API（ADR-0007 的目标形态） | 待开 issue |
| 数字下标 `v[0]` / 按键类型分派 | R-A-11 之外的下标访问；`get_idx` 仍需显式调用 | 待开 issue / REQ-JSACCESS-1 |
| 三级写链 `doc["a"]["b"]["c"] = x` | 写入口的下标协议 | `JSON-6`（PH-1 开） |
| 用户类型容器迭代 `for x in vec` | JS 风格遍历 | 待开 issue |
| `char *` 字面量 → `Str` | 键参数易用性（JSON-3 已按诊断分级登记） | `JSON-3` |
| J4 错误对象 `{code, offset, message}` | 0.1.0 只返回负错误码；`message` 所有权未裁定 | 待开 issue |

> PH-1 只为「三级读链已解」收口；写链、数字下标、属性访问仍按上表登记，不在 PH-1 内绕过或降级。
