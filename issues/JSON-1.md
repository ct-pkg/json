# JSON-1 三级下标链不可用（临时值接收者限制）

- status: open
- 归属: **语言层**（上游 ct v0.53.0），不是本包实现问题
- 优先级: P2（阻塞规范 J11，对应 0.1.1 backlog #3）
- 影响面: 同一表达式连续展开 3 次及以上用户类型下标；声明初始化与赋值右值都不行
- 关联: `docs/spec/ct-json-0.1.0.md` §5.1、§四 J11；样例 `docs/snippets/fail/three_level_chain.ct`

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

（仓库内同一写法：`docs/snippets/fail/three_level_chain.ct`，构建退出码 1。）

## 实际行为

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

## 阻塞点

J11；在编译器放开临时值接收者之前，本包无法提供三级链。
