# 路线图

> 本文件只排 phase 的顺序与边界，不自造条目。条目来源是 [docs/requirements.md](../requirements.md)、[docs/spec/ct-json-0.1.0.md](../spec/ct-json-0.1.0.md) 与 [docs/spec/ct-json-delivery-backlog.md](../spec/ct-json-delivery-backlog.md)；与它们冲突时以需求为标。

## 规则

- 每个 phase 对应一张 [卡片](phases/README.md)，编号 `PH-<n>` 连续递增。
- 立项与拆分属**大决定**：必须先核对需求文档与交付待办的大方向；违背方向即停止并报用户，不在路线图里改口径迁就实现现状。
- 语言侧未具备的能力（JS 风格属性访问、数字下标、用户类型容器迭代、`char *` 字面量→`Str` 等）只登记为 `blocked-by:` 依赖与 issue，**不降级需求、不假装完成**。
- 历史工作线 `J1…J4` 是口语别名，正式编号用 `PH-<n>`；映射在下方「阶段清单」登记。

## 阶段清单

尚未立项。立项后按下表登记：阶段编号、别名、目标、依赖、状态。

| 编号 | 别名 | 目标 | 主要依赖 | 状态 |
| --- | --- | --- | --- | --- |
| — | — | 尚未立项 | — | — |
