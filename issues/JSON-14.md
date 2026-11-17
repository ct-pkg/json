---
id: JSON-14
status: fixed
priority: P1
owner: 本包（对象生命周期）
created: 2026-11-17
last-touched: 2026-11-17
block:
evidence: 基线 `0757aac`；`leaks --atExit /tmp/j5` → 9 leaks / 288 bytes，均为 `Map_Str_int_from` 的 32B header
---

# JSON-14 每个对象泄漏 32B Map 头

- 归属：**本包对象创建**（`j1_obj_new`），不是语言层。
- 优先级：P1（每个 JSON 对象泄漏；ASan `detect_leaks=0` 看不到，只有 `leaks` 能抓）。
- 影响面：所有对象节点；失败路径与成功路径都泄漏。
- 关联：R-C-05、R-D-03、G7。

## 触发条件

创建任意对象（decode `{}`、`json_set` 中间对象、`set` 新键）。

## 最小复现

```console
$ cat > /tmp/lk.ct <<'CT'
#include <string.h>
import json;
int main(void)
{
    JsonRef r = { .p = 0 };
    json_decode("{}", 2, &r);
    json_free(r);
    return 0;
}
CT
$ CT_STD_DIR=... ct build /tmp/lk.ct -I src -o /tmp/lk
$ leaks --atExit --nosources -- /tmp/lk
Process: 1 leak for 32 total leaked bytes.
STACK OF 1 INSTANCE OF 'ROOT LEAK: <malloc in Map_Str_int_from>':
... j1_obj_new
```

`test/j5_errors.ct` 的 `leaks` 结果是 9 leaks / 288 bytes（每个对象 32B）。

## 根因

`j1_obj_new`：

```ct
Map<Str, int> z = {};
JsonObj *o = ...;
o->index = j1_alloc(sizeof(z));
o->index->h = 0;      /* 丢掉 z 已分配的 32B header */
```

CT v0.63.0 的 `Map_Str_int_from(0,0)` 会 `malloc` 一个 `ct_buf` 头并置 `refs=1`；
把 `h` 清零后该头无人释放。源码注释“无键对象从未分配 header”在当前工具链下不成立。

## 期望行为

对象释放后 `leaks` 0；`json_free` 仍走 `index->release()`。

## 修复

把 header 所有权转给对象：`o->index->h = z.h;`（`z` 出作用域不会释放它）。
修复后用 `leaks --atExit` 跑 `test/j5_errors.ct` 应为 0 leaks。

## 处置（fixed）

2026-11-17：`j1_obj_new` 改为 `o->index->h = z.h;`（修复 `de87c01`）。
`leaks --atExit -- /tmp/j5` 从 9 leaks / 288B 降为 0 leaks / 0B；
j5、j1、ASan 均绿。
