---
id: JSON-2
status: fixed
priority: P2
owner: 语言层（上游 ct v0.53.0 → v0.62.0 已放开）
created: 2026-11-15
last-touched: 2026-11-17
block:
evidence: CT v0.62.0 复跑 rc=0；`test/j1_roundtrip.ct` 的 method chain 断言（提交 `9783f6e`）；样例 `docs/snippets/chain3.ct`
---

# JSON-2 下标结果或方法结果作接收者不可用

- 归属: **语言层**（上游 ct v0.53.0），不是本包实现问题
- 优先级: P2（影响可读性；有局部变量绕法）
- 影响面: `doc["a"].has(k)`、`doc.get("a").get("b")` 等「结果继续调方法」的写法
- 关联: 规范 §5.1；样例 `docs/snippets/chain3.ct`

## 触发条件

把一次下标或方法调用的返回值直接当作下一个方法的接收者。

## 最小复现

```sh
cat > /tmp/recv.ct <<'CT'
#include <string.h>
import json;
int main(void)
{
    JsonRef doc;
    Str k = str_from("host");
    if (json_decode("{\"server\":{\"host\":\"h\"}}", 23, &doc) != JSON_OK) return 1;
    int present = doc["server"].has(k);   /* 下标结果作接收者 */
    k.release();
    json_free(doc);
    return present == 0;
}
CT
CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std \
  ct build /tmp/recv.ct -I src -o /tmp/recv
```

方法结果链同理：`JsonRef b = doc.get("a").get("b");`。

## 实际行为（修复前，CT v0.53.0）

```console
$ CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std \
    ct build docs/snippets/fail/temp_receiver.ct -I src -o /tmp/f_temp_receiver
docs/snippets/fail/temp_receiver.ct:19:1: error: method receiver must be a variable, an element, a call or a field chain
$ echo $?
1

$ # 方法结果链
error: method receiver must be a variable, an element, a call or a field chain
```

注意：这条与 JSON-1 的 `a method call on a temporary is only allowed ...` 不是同一条诊断，不要合并。

## 期望行为

下标结果与方法结果可直接作接收者，或至少错误信息指出「先落到局部变量」。

## 本包绕法

先落到局部变量：

```ct
JsonRef server = doc["server"];
int present = server.has(k);

JsonRef a = doc.get("a");
JsonRef b = a.get("b");
```

## 处置（fixed）

上游 CT v0.62.0 放开接收者限制，本仓不改 `src/`。回归断言固定两种形态，原失败样例
由 `docs/snippets/chain3.ct` 覆盖后删除。

```console
$ CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std \
    ct build test/j1_roundtrip.ct -I src -o /tmp/ctjson_p1
（0 warning）
$ /tmp/ctjson_p1 > /tmp/ctjson_p1.out
$ grep -e 'method on subscript' -e 'method-result chain' /tmp/ctjson_p1.out
ok 101 method-result chain receiver
ok 102 method on subscript result
ok 103 method on subscript chain
$ echo $?
0
```

收口：PH-1 / E-P1-1（提交 `9783f6e`）。

## 关联

`JSON-1`（三级链）、`JSON-5`（链式结果作实参/条件仍不可用）。
