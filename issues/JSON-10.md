---
id: JSON-10
status: fixed
priority: P2
owner: 本包（解码）
created: 2026-11-17
last-touched: 2026-11-17
block:
evidence: 基线 `fe6bb5a`；`json_as_double` 对 `1e999` 返回 rc=0、值 inf；修复提交 `a57502b`（红证 `2b88322`）
---

# JSON-10 `json_as_double` 对溢出实数返回 inf 而非 RANGE

- 归属：**本包解码/转换实现**，不是语言层。
- 优先级：P2（不崩溃，但值与错误承诺不符）。
- 影响面：任何把超大指数实数读成 double 的调用方；`1e999`、`-1e999`。
- 关联：R-A-09、[D-005](../docs/decisions/D-005.md)、ACC-09、PH-4。

## 触发条件

数字字面量的指数超出 double 范围。

## 最小复现

```sh
cat > /tmp/json10.ct <<'CT'
#include <stdio.h>
#include <string.h>
import json;
int main(void)
{
    char *text = "{\"b\":1e999}";
    JsonRef r = { .p = 0 };
    Str k = str_from("b");
    double d = 0.0;
    int rc;
    json_decode(text, strlen(text), &r);
    rc = json_as_double(json_member(r, k), &d);
    printf("rc=%d d=%g\n", rc, d);
    json_free(r);
    k.release();
    return 0;
}
CT
CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std \
  ct build /tmp/json10.ct -I src -o /tmp/json10 && /tmp/json10
```

## 实际行为

```console
$ /tmp/json10
rc=0 d=inf
$ echo $?
0
```

`0.30000000000000004` 已 bit-exact（R-A-09 的精度项通过）；`1e-400` 归 0 符合期望；只有溢出没有转成 `JSON_ERR_RANGE`。

## 期望行为

`rc == JSON_ERR_RANGE`，且 `d` 不被写入（与 `json_as_int` 的越界行为一致）。

## 修复（`a57502b`）

`json_as_double` 对 `strtod` 结果做有限性检查（`d != d` 或超出 `DBL_MAX` → `JSON_ERR_RANGE`），
`out` 不被写入。回归断言：`test/j1_roundtrip.ct` 的 `1e999 is a range error`、
`-1e999 is a range error`、`a range error leaves out untouched`。

## 阻塞点

无；PH-4 处理。
