---
id: JSON-13
status: fixed
priority: P1
owner: 本包（工具链兼容）+ 上游提案
created: 2026-11-17
last-touched: 2026-11-17
block:
evidence: 基线 `0757aac`；`ct v0.63.0` / `v0.63.2` 把 `9223372036854775808ULL` 生成成 `9223372036854775807ULL`；`bash tools/check.sh g3` 干净重建 rc=1
---

# JSON-13 CT v0.63.0/v0.63.2 把 2^63 无符号字面量钳成 INT64_MAX

- 归属：**上游工具链缺陷**（`ct` v0.63.0 / v0.63.2 codegen），本包只能绕行。
- 优先级：P1（g3 红；`json_as_int(INT64_MIN)` 误报 `JSON_ERR_RANGE`）。
- 影响面：`json.ct` 的 golden `int64 minimum`、`src/json.h.ct` 的 int64 下限转换。
- 关联：R-A-04、R-C-04、G3；提案（DB-5/CF）：上游修字面量 codegen。

## 触发条件

源码里出现 `9223372036854775808ULL`（2^63）。

## 最小复现

```console
$ /tmp/ph1probe/i64        # json_decode("-9223372036854775808") + json_as_int
decode=0 as_int=-12 n=0 want=-9223372036854775808
```

用最小探针看工具链：

```ct
unsigned long long a = 9223372036854775808ULL;
printf("%llu\n", a);   // 实测 9223372036854775807
```

生成的 C 里两个分支同为 `9223372036854775807ULL`。

## 实际行为

- `bash tools/check.sh g3` 在干净 `.ctbuild` 下 `FAIL g3: json.ct demo exit != 0`，golden 的 `int64 minimum` 检查失败。
- `json_as_int("-9223372036854775808")` 返回 `JSON_ERR_RANGE`。

## 期望行为

2^63 字面量按值发射；INT64_MIN 精确读回。`json_as_int` 对 -2^63 返回 `JSON_OK` + 该值。

## 本包绕行

`limit = neg ? (9223372036854775807ULL + 1ULL) : 9223372036854775807ULL;`
（`json.ct` 与 `src/json.h.ct` 各一处，`json.ct` 的比较表达式同改）。
上游提案：请 `ct` 修无符号字面量 codegen，并补 2^63 的回归；本包不修改 `ct-lang`。

## 处置（fixed）

2026-11-17：`json.ct` 两处、`src/json.h.ct` 一处改为
`(9223372036854775807ULL + 1ULL)`；红证 `ea7777e`，修复 `deaa657`。
干净 `.ctbuild` 下 `g3` rc=0、j1 146 ok；`json_as_int(INT64_MIN)` 精确。
上游 codegen 缺陷已在本条登记为提案（DB-5），本包不修改 `ct-lang`。
