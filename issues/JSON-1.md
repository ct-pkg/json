---
id: JSON-1
status: fixed
priority: P2
owner: 语言层（上游 ct v0.53.0 → v0.62.0 已放开）
created: 2026-11-15
last-touched: 2026-11-17
block:
evidence: CT v0.62.0 复跑 rc=0；`test/j1_roundtrip.ct` 的 chain 断言（提交 `9783f6e`、`8471a5b`）；样例 `docs/snippets/chain3.ct`
---

# JSON-1 三级下标链不可用（临时值接收者限制）

- 归属: **语言层**（上游 ct v0.53.0），不是本包实现问题
- 优先级: P2（阻塞规范 J11，对应 0.1.1 backlog #3）
- 影响面: 同一表达式连续展开 3 次及以上用户类型下标；声明初始化与赋值右值都不行
- 关联: `docs/spec/ct-json-0.1.0.md` §5.1、§四 J11；样例 `docs/snippets/chain3.ct`

## 触发条件

对同一表达式连续三次下落用户类型下标（`a["b"]["c"]["d"]`）。

## 最小复现

```sh
cat > /tmp/three.ct <<'CT'
#include <string.h>
import json;
int main(void)
{
    JsonRef doc;
    if (json_decode("{\"a\":{\"b\":{\"c\":1}}}", 19, &doc) != JSON_OK) return 1;
    JsonRef c = doc["a"]["b"]["c"];
    json_free(doc);
    return c.p == 0;
}
CT
CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std \
  ct build /tmp/three.ct -I src -o /tmp/three
```

## 实际行为（修复前，CT v0.53.0）

```console
$ CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std \
    ct build docs/snippets/fail/three_level_chain.ct -I src -o /tmp/f_three_level_chain
docs/snippets/fail/three_level_chain.ct:18:1: error: a method call on a temporary is only allowed at the start of a statement or of an assignment
$ echo $?
1
```

## 期望行为

三级链与两级链一致：在声明初始化、赋值右值位置编译通过，返回 `JsonRef` 句柄。

## 本包绕法

拆成局部变量，语义不变：

```ct
JsonRef b = doc["a"]["b"];
JsonRef c = b["c"];
```

## 处置（fixed）

上游 CT v0.62.0 放开了临时值接收者限制，本仓不改 `src/`。修复后用三条断言固定形状
（声明初始化、赋值右值、return），并把原失败样例迁成可运行的 `docs/snippets/chain3.ct`。

```console
$ CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std \
    ct build test/j1_roundtrip.ct -I src -o /tmp/ctjson_p1
（0 warning）
$ /tmp/ctjson_p1 > /tmp/ctjson_p1.out
$ grep -e '3-level chain' /tmp/ctjson_p1.out
ok 98 3-level chain decl init
ok 99 3-level chain assign rhs
ok 100 3-level chain return pos
$ echo $?
0
```

收口：PH-1 / E-P1-1（提交 `9783f6e`、`8471a5b`）。写链仍不可用，另立 `JSON-6`。

## 阻塞点

J11 已解除；无剩余阻塞。
