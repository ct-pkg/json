---
id: JSON-5
status: open
priority: P2
owner: 语言层
created: 2026-11-17
last-touched: 2026-11-17
block: 上游 CT 未放开「链式结果作实参/条件/字段」
evidence: 基线 `9783f6e`；`ct build json5_arg.ct` rc=1，`json5_arg.ct:9:1: error: a method call on a temporary is only allowed at the start of a statement or of an assignment`
---

# JSON-5 链式结果不能作函数实参 / 条件 / 字段

- 归属: **语言层**（CT v0.62.0 仍未放开），不是本包实现问题。
- 优先级: P2（有局部变量绕法；影响可读性）。
- 影响面: `take(doc["a"]["b"])`、`doc["a"]["b"]["c"].p != 0` 等把链式结果放到实参位或 rvalue 取字段的写法。
- 关联: `docs/spec/ct-json-0.1.0.md` §5.1；`JSON-1`（三级读链，已 fixed）。

## 触发条件

`JSON-1` 修好三级读链后，v0.62.0 仍只在「语句 / 赋值的起始处」接受临时值接收者：

1. 把两级或三级链的结果直接作函数实参；
2. 对链式结果取字段或放条件里（C 层 `cannot take the address of an rvalue`）；
3. 单层下标 `doc["a"]` 作实参仍可用，限制从两级链开始。

## 最小复现

```sh
cat > /tmp/json5_arg.ct <<'CT'
#include <string.h>
import json;
static int take(JsonRef v) { return v.p != 0; }
int main(void)
{
    char *text = "{\"a\":{\"b\":{\"c\":1}}}";
    JsonRef doc;
    if (json_decode(text, strlen(text), &doc) != JSON_OK) return 1;
    int t = take(doc["a"]["b"]);
    json_free(doc);
    return t;
}
CT
CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std \
  ct build /tmp/json5_arg.ct -I src -o /tmp/json5_arg
```

## 实际行为

```console
$ CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std \
    ct build /tmp/json5_arg.ct -I src -o /tmp/json5_arg
json5_arg.ct:9:1: error: a method call on a temporary is only allowed at the start of a statement or of an assignment
$ echo $?
1
```

条件位置是另一条（C 层）诊断：

```console
$ # if (doc["a"]["b"]["c"].p != 0) { ... }
cond.ct:24:34: error: cannot take the address of an rvalue of type 'struct JsonRef'
$ echo $?
1
```

## 期望行为

链式结果可直接作函数实参、取字段、放条件，或错误信息明确要求先落局部变量。

## 本包绕法

先落局部变量：

```ct
JsonRef b = doc["a"]["b"];
take(b);
JsonRef c = doc["a"]["b"]["c"];
if (c.p != 0) { /* ... */ }
```

## 阻塞点

上游 `ct` 的临时值规则；解锁后在下一个 phase 补回归与样例。
