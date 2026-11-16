---
id: JSON-6
status: open
priority: P2
owner: 语言层
created: 2026-11-17
last-touched: 2026-11-17
block: 上游 CT 的自定义下标写入要求 lvalue 接收者
evidence: 基线 `9783f6e`；`ct build json6.ct` rc=1，`json6.ct:9:18: error: a custom subscript write needs a statement and an lvalue receiver`
---

# JSON-6 三级写链不可用

- 归属: **语言层**（自定义下标写入要求 lvalue 接收者），不是本包实现问题。
- 优先级: P2（有逐级落局部变量的绕法）。
- 影响面: `doc["a"]["b"]["c"] = v`、`doc.get("a").get("b")["c"] = v` 等多级写入。
- 关联: `docs/spec/ct-json-0.1.0.md` §5.1；`ADR-0007` 的写入口；`JSON-1`（读链已 fixed）。

## 触发条件

对串起来的表达式做下标写入，接收者不是变量/元素而是临时值。

## 最小复现

```sh
cat > /tmp/json6.ct <<'CT'
#include <string.h>
import json;
int main(void)
{
    char *text = "{\"a\":{\"b\":{}}}";
    JsonRef doc;
    if (json_decode(text, strlen(text), &doc) != JSON_OK) return 1;
    JsonRef v = doc.get("a").get("b");
    doc["a"]["b"]["c"] = v;
    json_free(doc);
    return 0;
}
CT
CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std \
  ct build /tmp/json6.ct -I src -o /tmp/json6
```

## 实际行为

```console
$ CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std \
    ct build /tmp/json6.ct -I src -o /tmp/json6
json6.ct:9:18: error: a custom subscript write needs a statement and an lvalue receiver
ctc: 1 error(s) generated
$ echo $?
1
```

单级写 `doc["a"] = v` 与两级读链可用；限制只在「写链」这一侧。

## 期望行为

`doc["a"]["b"]["c"] = v` 直接可用；或错误信息指出先落局部变量。

## 本包绕法

逐级落到局部变量再写：

```ct
JsonRef b = doc["a"]["b"];
b["c"] = v;
```

## 阻塞点

上游 `ct` 的自定义下标写规则；解锁后在下一个 phase 补回归与样例。
