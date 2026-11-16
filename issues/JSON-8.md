---
id: JSON-8
status: open
priority: P1
owner: 本包（门禁实现）
created: 2026-11-17
last-touched: 2026-11-17
block:
evidence: 基线 `1f0c86b`；克隆里构造合法 phase 收口（`0.1.1`→`0.2.0`、PH-2 卡 closed、tag `v0.2.0`、正文含 `PH-2`）后 `bash tools/check.sh g8` rc=1，报 `moves version without an issue reference (V-3)`
---

# JSON-8 g8 把 phase 收口的 MINOR 移动当成 fix

- 归属：**本包门禁实现**，不是产品实现、不是语言层。
- 优先级：P1（每个 phase 收口都会被误判；B 类缺陷不修就无法诚实收口）。
- 影响面：所有 `PH-<n>` 的收口提交。`g8` 的版本检查只有一条分支：只要 `ct.pkg` 版本变了就要求正文引用 `issues/JSON-<n>.md`，把 V-1 的 phase 收口与 V-3 的 fix 混成同一条规则。
- 关联：`tools/check.sh` g8、6.7 V-1/V-3/V-5、`docs/phases/PH-1/card.md`（首个收口在 0.1.1 起始位上，未触发此缺陷）。

## 触发条件

在一个 phase 收口提交里把 `MINOR` 加一（`PATCH` 归零），正文按 V-5 写收口记录但不引用 issue。

## 最小复现

```console
$ git clone -q . /tmp/json8-red && cd /tmp/json8-red
$ sed -i '' 's/^version = 0\.1\.1$/version = 0.2.0/' ct.pkg
$ mkdir -p docs/phases/PH-2 && printf -- '- 编号：PH-2\n- 状态：closed\n' > docs/phases/PH-2/card.md
$ git add -A && git commit -qm 'chore(release): PH-2 收口（v0.2.0）' -m 'PH-2 收口'
$ git tag -a v0.2.0 -m 'PH-2'
$ bash tools/check.sh g8
commit f8705f6 moves version without an issue reference (V-3)
FAIL g8: version move check failed
$ echo $?
1
```

这是**合法**的 phase 收口：MINOR 2、PATCH 0、PH-2 卡 closed、tag 已建、正文含 `PH-2`。

## 期望行为

- MINOR 移动：`MINOR == 上一版 + 1`、`PATCH == 0`、正文含 `PH-<n>`、同一提交里 `docs/phases/PH-<n>/card.md` 为 `closed`；不要求 issue 引用。
- PATCH 移动：`PATCH == 上一版 + 1`、正文恰好引用一个 `issues/JSON-<n>.md`、提交不是纯 `docs`；不要求 card/tag。
- 其他形状（跳号、同版、MAJOR 移动、版本不动）仍失败。

## 处置（fixed 时写）

2026-11-17：`tools/check.sh` g8 的版本检查按「MINOR 移动 / PATCH 移动」分支，分别校验 V-1 与 V-3/V-4；`tools/negatives/run.sh` 补两个负例（PATCH 缺 issue、MINOR 缺 closed 卡）。

```console
$ # 合法 phase 收口
ok g8 (baseline ad5f1dc, version moves and phase tags valid)   # rc=0
$ # PATCH 移动缺 issue
commit 7c555ec moves version without an issue reference? → fix must reference exactly one issue, got 0 (V-3)   # rc=1
$ # MINOR 移动缺 closed 卡
commit e80eed0 moves MINOR without closing docs/phases/PH-2/card.md (V-1)   # rc=1
```

版本：`0.1.1` → `0.1.2`（V-3 的一次 fix；门禁缺陷按 V-4 例外立案）。
