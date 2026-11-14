# ADR-0006：引用计数 API 全部公开

- 状态：已采纳（Accepted）
- 日期：2026-11-15
- 裁定者：用户
- 回答：ADR-0003 待定 2（引用计数加减是否公开）
- 前提：[ADR-0003](0003-reference-sharing.md) 引用共享与引用计数
- 影响面：公开 API 面与调用方生命周期责任。本 ADR 不含实现，不改变当前 `json.ct`。

## 决策

1. `json_retain` / `json_release` 都在公开 API 上。
2. `json_free` 等于 `release` 一次。

## 必须写明的约束

- **retain 与 release 必须配对**：一次 retain 对应一次 release；容器析构时释放自己持有的那一份引用。
- **多 retain 会漏**：多 retain 而少 release，计数不归零，内存不释放。
- **多 release 会 double-free**：计数提前归零后仍继续 release，属于未定义行为，库不做额外防护。
- 调用方通过 retain 拿到的引用，在自己 release 之前保证对象存活；release 之后不得再用。

## 后果

- 调用方可以把子对象拿到树外单独持有、跨容器共享，生命周期能力完整。
- 公开面扩大：计数错误（漏配、多配）从库内部问题变成调用方责任，误用成本转移到调用方。
- `json_free` 只是 `release` 一次的便捷入口，不引入第二套语义；文档不能把 `json_free` 写成「销毁整棵树」。
- 与 ADR-0005 的环代价叠加：环上的计数永远不归零，retain/release 再正确也救不回来，成环仍按调用方 bug 处理。

## 不做

- 不写实现、不恢复开发、不新建夹具、不修改 `json.ct`。
- 不定义签名、返回值与错误码（例如对空指针 retain/release 的行为不在本次裁定内）。
