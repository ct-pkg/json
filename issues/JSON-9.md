---
id: JSON-9
status: open
priority: P1
owner: 本包（编码）
created: 2026-11-17
last-touched: 2026-11-17
block:
evidence: 基线 `fe6bb5a`；`set_double(NaN)` 后 `json_encode` 返回 `{"x":nan}`、`json_last_error()=0`
---

# JSON-9 NaN 编码输出非法 JSON

- 归属：**本包编码实现**，不是语言层。
- 优先级：P1（产出非法 JSON，违反 R-B-03 与「能出就能读」）。
- 影响面：任何用 `set_double` / `set_idx` 写入 NaN 再 `json_encode` 的调用方。
- 关联：R-B-03、[D-006](../docs/decisions/D-006.md)、ACC-15、PH-5。

## 触发条件

节点里有一个程序写入的 `double`，值为 NaN（例如 `strtod("nan", 0)`）。

## 最小复现

```sh
cat > /tmp/json9.ct <<'CT'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
import json;
int main(void)
{
    JsonRef r = { .p = 0 };
    Str k = str_from("x");
    char *out;
    json_decode("{}", 2, &r);
    r.set_double(k, strtod("nan", 0));
    out = json_encode(r);
    printf("encode=%s err=%d\n", out == 0 ? "(null)" : out, json_last_error());
    free(out);
    json_free(r);
    k.release();
    return 0;
}
CT
CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std \
  ct build /tmp/json9.ct -I src -o /tmp/json9 && /tmp/json9
```

## 实际行为

```console
$ /tmp/json9
encode={"x":nan} err=0
$ echo $?
0
```

`inf` / `-inf` 已被 `j1_enc_double` 的范围检查拦住（`NULL` + `JSON_ERR_RANGE`）；NaN 因为比较全为假而漏过。

## 期望行为

`json_encode` 返回 `NULL`，`json_last_error()` 为 `JSON_ERR_RANGE`（与 Inf 一致）。

## 修复提示

`j1_enc_double` 开头加 `if (d != d) { b->bad = JSON_ERR_RANGE; return; }`；补一条负例断言「NaN 编码返回 NULL」。

## 阻塞点

无；PH-5 处理。
