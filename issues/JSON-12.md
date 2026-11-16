---
id: JSON-12
status: open
priority: P1
owner: 本包（编码）
created: 2026-11-17
last-touched: 2026-11-17
block:
evidence: 基线 `2b9e9c4`；`test/j1_roundtrip.ct` 的 `a NUL value round-trips` 在测试提交 `d804224` 上 `not ok 95`
---

# JSON-12 控制字节转义写 6 位十六进制，含 NUL 的值编码后改值

- 归属：**本包编码实现**（`src/json.h.ct` 的 `j1_enc_bytes`），不是语言层。
- 优先级：P1（静默改值：`"a\u0000b"` 编码再解码变成 5 字节 `61 00 30 30 62`）。
- 影响面：所有含 U+0000…U+001F（未走 `\b \f \n \r \t` 的）字符串值与键的 encode→decode 往返。
- 关联：R-B-02、R-B-04、R-B-07、ACC-14/16/19、PH-5。

## 触发条件

值里含 NUL 或其它需要 `\u00XX` 转义的控制字节，执行 `json_encode` 后重新解析。

## 最小复现

由 `test/j1_roundtrip.ct` 的 `nul_value_contract` 覆盖：

```console
$ CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std \
    ct build test/j1_roundtrip.ct -I src -o /tmp/ctjson_p12 && /tmp/ctjson_p12
...
not ok 95 a NUL value round-trips
1 of 136 checks failed
$ echo $?
1
```

编码结果是 `{"s":"a\u000000b"}`：`\u0000` 后又多了 `00`，重解得到 5 字节 `61 00 30 30 62`，原值应为 3 字节 `61 00 62`。

## 根因

`j1_enc_bytes` 在控制字节分支写 `j1_puts(b, "\\u00")`，再调用 `j1_put_hex4` 写 **4 位**，
合计 6 位十六进制；旧 `json.ct` 是 `\u00` + 2 位。这是树重写时引入的回归。

## 期望行为

控制字节写成 4 位：`\u0000`、`\u0001`、`\u001f`；encode→decode 后字节与长度不变。

## 修复

`j1_puts(b, "\\u")` + `j1_put_hex4(b, c)`。回归断言见 `test/j1_roundtrip.ct` 的
`nul_value_contract`（4 条断言）。

## 阻塞点

无；本 phase 小循环修复。
