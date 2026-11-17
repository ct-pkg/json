---
id: JSON-18
status: open
priority: P2
owner: 本包（门禁 g8）
created: 2026-11-18
last-touched: 2026-11-18
block:
evidence: 提交 `7a328d4` 只改 `ct.pkg` 注释，`git diff` 版本行未变；`bash tools/check.sh g8` 报 `touches ct.pkg without a version move (V-5)`，rc=1
---

# JSON-18 g8 把 `ct.pkg` 的注释改动当成版本移动

- 归属：**本包门禁 g8**，不是清单问题。
- 优先级：P2（使合法注释/格式改动永久红；本次由 0.6.1 收口前的注释修正暴露）。
- 影响面：任何只改 `ct.pkg` 注释、空行或末尾空白的提交。
- 关联：V-5、JSON-17、提交 `7a328d4`。

## 触发条件

提交路径含 `ct.pkg`，但只改注释/空白，`version` 行不变。

## 最小复现

```console
$ git show --stat 7a328d4
 ct.pkg | 5 +++--
$ bash tools/check.sh g8
commit 7a328d4 touches ct.pkg without a version move (V-5)
FAIL g8: version move check failed
$ echo $?
1
```

该提交把旧 vendor 注释改成 store 模型注释，`name/version/publisher/ns-root` 均未变。

## 期望行为

- 注释/空白-only 的 `ct.pkg` 改动不触发版本检查（版本声明未变）。
- 任何**语义行**（`name`、`version`、`publisher`、`ns-root`、`requires` 等键值）变化仍必须走 V-3/V-5 的版本检查。

## 修复

在 g8 的逐提交检查里，先比较去掉注释/空行后的 `ct.pkg` 语义行；相同则跳过版本检查，
不同才进入原有的 MINOR/PATCH 分支。负例：改 `requires` 但不改版本必须仍红。

## 处置（fixed 时写）

（待修复）
