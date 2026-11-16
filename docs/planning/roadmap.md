# 路线图

> 本文件只排 phase 的顺序与边界，不自造条目。条目来源：[docs/requirements.md](../requirements.md)、[docs/spec/ct-json-0.1.0.md](../spec/ct-json-0.1.0.md)、[docs/spec/ct-json-0.1.0-completion.md](../spec/ct-json-0.1.0-completion.md) §四、[docs/spec/ct-json-delivery-backlog.md](../spec/ct-json-delivery-backlog.md)。与需求冲突时以需求为准。

## 规则

- 每个 phase 一张 [卡片](phases/README.md)，编号 `PH-<n>` 连续递增，`version-minor` 等于 n。
- 立项与拆分属**大决定**：先核对需求与交付待办；违背方向即停止报用户。battle 只解决小事情。
- 语言侧缺口只登记为 `blocked-by:` 与 issue，不降级需求、不假装完成。

## 阶段清单

| 编号 | 别名 | 目标 | 主要需求 | 依赖 | 状态 |
| --- | --- | --- | --- | --- | --- |
| PH-1 | J1 收口 | 把 CT v0.62.0 已支持的三级读链/方法结果链固化进回归与文档，收口 JSON-1/2 | R-D-07、R-A-06/07（已满足项的边界复核） | CT >= 0.62.0（已装） | closed（v0.1.1） |
| PH-2 | — | 需求基线与验收映射：R-A…R-E 逐条对照实现与用例，产出 `docs/acceptance-map.md`（ACC-*），接入 g2，并落 Q 项裁定 | 全部 R-* 的现状锚定 | PH-1 | closed（v0.2.0） |
| PH-3 | J3 写能力 | 纯函数式写入 `json_set`（路径写入）与重复键语义 | R-D-08（已满足，复核）、R-D-03（证据） | PH-2 | 待开卡 |
| PH-4 | — | 解码边界：UTF-8 开关、实数精度、深度硬上限、大容器查找、BOM | R-A-08、R-A-09（JSON-10）、R-A-10、R-A-11、R-A-12 | PH-2（含 Q-05/Q-08 裁定） | 待开卡 |
| PH-5 | — | 编码边界与错误契约：非有限值、错误码/偏移/文案；含 NUL 与往返只做回归复核 | R-A-01、R-B-03（JSON-9）、R-C-01（JSON-11）、R-C-03、R-C-05；R-B-04/R-B-07 已满足 | PH-2（含 Q-03/Q-09 裁定）、PH-3 | 待开卡 |
| PH-6 | 交付 | 包清单/单元根/import 形态、首版发布、验收文档与门禁收口（g4/g5 接入） | R-E-02、R-E-03、R-E-04、R-E-05、R-E-06；R-E-01 已满足；R-B-01/05/06 文档明确不做 | PH-3…PH-5 | 待开卡 |

## 门禁接入与决策项归属

门禁不是"到时候自然会有"的：每道未实现的门禁必须挂在一个 phase 的交付物里，否则收口时只能报 `exit 2`，且没有人负责补。决策项同理，`requirements.md` §8 的 Q 项若不指定归属，PH-4/PH-5/PH-6 的验收判据会停在"待确认"。

| 项 | 归属 phase | 交付物 | 说明 |
| --- | --- | --- | --- |
| `g2` 设计可验收 | PH-2 | `docs/acceptance-map.md` + `tools/check.sh g2` + 负例 | 验收映射与门禁同一提交接入 |
| `Q-03` 错误模型、`Q-05` Unicode/BOM、`Q-06` 包形态、`Q-08` 深度与性能、`Q-09` 编码失败与数字输出 | PH-2 | `docs/decisions/D-<n>.md`；`docs/requirements.md` 状态列同步 | 未裁定的按需求文档「建议口径」先落判据；裁定改动只追加注记 |
| `Q-07` 树形状与所有权细节 | PH-2 | 同上 | 已被 0.1.0 实现与 ADR-0001～0006 回答的部分，只补剩余空白 |
| `g4` 文档可执行与时效 | PH-6 | `tools/check.sh g4` + 负例 + 文档分拆 | PH-1…PH-5 期间按人工核对；不得宣称全门禁绿 |
| `g5` 测试自证 | PH-6 | `tools/check.sh g5` + 红证登记表 + 负例 | 各 phase 的红证先落在 issue/卡片，PH-6 统一机器化 |

**归属变更规则**：门禁实现若在本表之外被提前完成，仍算对应 phase 的交付物，不另立 phase；若某 phase 收口时其名下门禁仍未实现，收口报告必须写明 `exit 2` 与欠账，不得写成"门禁全绿"。

## 已关闭、不占 phase

| 事项 | 结论 | 依据 |
| --- | --- | --- |
| J2 路径助手 `json_get` | **不复活**；访问入口仍是下标协议 + `get_idx` | [ADR-0007](../adr/0007-js-style-access.md) |
| PH-2 判定为「已满足」的 R-* | 不重复实现；逐条锚定到现有用例或探针，清单见 `docs/acceptance-map.md` | `docs/acceptance-map.md` |

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
