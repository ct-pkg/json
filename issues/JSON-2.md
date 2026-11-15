# JSON-2 下标结果或方法结果作接收者不可用

- status: open
- 归属: **语言层**（上游 ct v0.53.0），不是本包实现问题
- 优先级: P2（影响可读性；有局部变量绕法）
- 影响面: `doc["a"].has(k)`、`doc.get("a").get("b")` 等「结果继续调方法」的写法
- 关联: 规范 §5.1；样例 `docs/snippets/fail/temp_receiver.ct`

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
    if (json_decode("{\"server\":{\"host\":\"h\"}}", 24, &doc) != JSON_OK) return 1;
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

## 实际行为

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
