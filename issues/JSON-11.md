---
id: JSON-11
status: fixed
priority: P2
owner: 本包（解码错误）
created: 2026-11-17
last-touched: 2026-11-17
block:
evidence: 基线 `fe6bb5a`；`grep -n 'json_error_offset' src/json.h.ct` 无输出；修复提交 `4f89a80`（红证 `f3d37ce`）
---

# JSON-11 解析错误只有码，没有 offset/行列

- 归属：**本包解码实现**，不是语言层。
- 优先级：P2（不阻塞功能；诊断与 R-C-01 的承诺缺失）。
- 影响面：所有调用 `json_decode` 后需要定位错误的调用方与错误报告。
- 关联：R-A-01、R-C-01、[D-001](../docs/decisions/D-001.md)、ACC-01/20、PH-5。

## 触发条件

`json_decode` 失败后想拿到错误字节位置或行列。

## 最小复现

```console
$ grep -n 'json_error_offset\|json_error_line\|json_error_column' src/json.h.ct
$ echo $?
1

$ cat > /tmp/json11.ct <<'CT'
#include <stdio.h>
#include <string.h>
import json;
int main(void)
{
    JsonRef r = { .p = 0 };
    int rc = json_decode("{} {}", 5, &r);
    printf("rc=%d err=%d\n", rc, json_last_error());
    return 0;
}
CT
$ CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build /tmp/json11.ct -I src -o /tmp/json11 && /tmp/json11
rc=-3 err=-3
```

`-3` 是 `JSON_ERR_TRAILING`，但调用方无法知道位置是 offset 3；行列也拿不到。

## 期望行为

- `json_error_offset()`：最近一次 parse 失败的字节偏移（0-based），成功时为 0。
- `json_error_line()` / `json_error_column()`：1-based，列按字节计。
- `"{} {}"` → offset 3；空输入 → offset 0；失败后 root 仍为空。

## 修复（`4f89a80`）

`j1_place` 在 `j1_fail` 记录 `p->pos`，并扫描 `[0,pos)` 算 1-based 行列；
`json_error_offset/line/column` 读取；decode 开头清零，成功保持 0。
`test/j5_errors.ct` 覆盖 `{} {}` → 3 / 1:4、缺冒号 → 8 / 2:7、空输入 → 0 / 1:1。

## 阻塞点

无；PH-5 处理。
