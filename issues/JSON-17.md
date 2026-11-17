---
id: JSON-17
status: open
priority: P1
owner: 本包（包清单）
created: 2026-11-18
last-touched: 2026-11-18
block:
evidence: ct v0.65.1；`ct.pkg` 的 `requires = ct >= 0.53.0`，但 `ct get` 的 store 模型从 v0.62.0 起；v0.6.0 tag 的清单同样写 0.53.0
---

# JSON-17 `requires` 下限仍是 0.53.0，与 `ct get` 的 store 模型不符

- 归属：**本包清单**（不是语言层）。
- 优先级：P1（依赖声明误导；按 v0.53–v0.61 安装的用户没有 `ct get` 的 store 路径）。
- 影响面：所有按 `requires` 选工具链的消费方与共享包库元数据。
- 关联：JSON-4、JSON-15、R-E-04；共享包库契约（publisher/ns-root）。

## 触发条件

`ct get` 从 v0.62.0 起使用 `$CT_HOME/pkg/<publisher>/<name>/<version>/` 与 `ct.lock`，
不再写 `vendor/`；但本包清单与 `//@ct-requires` 仍声明 `ct >= 0.53.0`。

## 实际行为

```console
$ grep -n 'requires' ct.pkg src/json.h.ct
ct.pkg:12:requires = ct >= 0.53.0
src/json.h.ct:1://@ct-requires: ct >= 0.53.0
```

v0.53–v0.61 的工具链没有 store 消费路径；按清单下限安装会得到过期的 vendor 模型。

## 期望行为

`requires = ct >= 0.62.0`，且 `//@ct-requires` 与之一致；新版本 `0.6.1` 的 tag
`v0.6.1` 带同一 `publisher = ct`、`ns-root = src`，可被共享包库索引收录。

## 处置（fixed 时写）

（待修复）
