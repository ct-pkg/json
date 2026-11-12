# json — a zero-allocation JSON reader/writer in plain CT

> English · [中文](#中文)

A single CT file that validates JSON, exposes a read-only view over the caller's
text, and serializes values back out. It allocates nothing, owns nothing, and
does not need a DOM: a parsed document is just the input bytes plus the offset of
the first error, and every lookup re-scans the slice it needs.

```sh
ct-ast json.ct -o /tmp/json.c
cc -Wall -Wextra -std=c99 /tmp/json.c -o /tmp/json && /tmp/json
```

[`json.expected.out`](json.expected.out) is the golden output: build `json.ct`
with `ct-ast`, run it and diff the two. The program is
both the demo (`-- demo --`) and the conformance suite (`ok` / `FAIL` lines, a
non-zero exit on the first failing check).

## What is in the file

| part | contents |
| --- | --- |
| reader | `JsonDoc` + `trait Json`: `parse`, `root`, `kind`, `count`, `member`, `at`, `as_*`, `offset_of`, `len_of`, `emit`, error accessors |
| writer | `JsonOut` + `trait JsonWrite`: `begin`, `object`, `array`, `end`, `key`, `string`, `integer`, `real`, `boolean`, `null`, `finish`, `length`, `error` |
| view | `JsonView { start, len }`, a byte range in the text the caller passed to `parse` |
| demo/tests | `main` drives the sections `demo`, `reader`, `writer`, `errors` |

All generated C symbols are file-local (`static`); the file is meant to be copied
into a program or imported as one unit, not linked as a library.

## Reading

```c
struct JsonDoc doc;
struct JsonView root;
struct JsonView v;
char name[32];
long long stars;

if (!doc.parse(text, len)) {
    printf("%s at %d:%d\n", json_message(doc.error()),
            doc.error_line(), doc.error_column());
    return;
}
root = doc.root();
v = doc.member(&root, "name");
doc.as_string(&v, name, sizeof name);
v = doc.member(&root, "stars");
doc.as_int(&v, &stars);
```

`parse` validates the whole document once. A `JsonView` is only a slice, so a
view stays valid as long as the text does; there are no handles, no free, no
lifetime beyond that. `member` keeps the **last** duplicate key, `at` takes a
zero-based index, and both return a `MISSING` view when nothing matches.

`as_string` decodes `\"`, `\\`, `\/`, `\b`, `\f`, `\n`, `\r`, `\t`, `\uXXXX` and
surrogate pairs into UTF-8. It returns the decoded length and follows `snprintf`
semantics: a short buffer is truncated and NUL-terminated, but the return value is
always the length that would be needed. `cap = 0` therefore measures.

`as_int` accepts only a plain integer literal in `int64` range: `1.0` and `1e3`
are rejected with `JSON_READ_INTEGER`, out-of-range values with
`JSON_READ_RANGE`. `as_double` accepts any number token.

## Writing

```c
struct JsonOut out;
char buf[256];

out.begin(buf, sizeof buf);
out.object();
out.key("name");
out.string("ct");
out.key("stars");
out.integer(42);
out.end();
if (out.finish() < 0) { /* out.error() */ }
```

`JsonOut` appends into a caller buffer and keeps its nesting stack (depth 64) in
the struct. `begin(buf, 0)` measures without writing; `finish` NUL-terminates and
returns the required length, or `-1` on a structural error (`JSON_EMIT_STATE`),
too-deep nesting (`JSON_EMIT_DEPTH`) or a non-finite real (`JSON_EMIT_FINITE`).
Strings are escaped, including control bytes as `\u00XX`; `real` prints with
`%.17g`. `emit` copies one view's bytes into a `JsonOut` so a parsed subtree can
be embedded or round-tripped.

## Limits

- **Zero allocation.** No `malloc`, no hidden ownership; nesting depth and output
  size are the only resource limits (64 containers by default; set
  `doc.depth_limit` before `parse` to change it).
- **Lazy lookups cost O(n).** Each `member`/`at`/`count` re-scans its container.
  Fine for configuration-sized documents; not for hot loops over large arrays.
- **Errors are one code plus a byte offset**, with 1-based line and column
  computed on demand (column counts bytes, tabs count 1, `\n` starts a new line).
- **Numbers.** Integers are exact within `int64`. Reals are converted by hand
  (no `strtod`, so no locale dependency) from at most 19 significant digits and a
  clamped exponent; the last unit in the last place may differ from a correctly
  rounded conversion. Use `offset_of`/`len_of` for the raw token when exact
  decimal text matters.
- **Strings** are decoded to UTF-8, but the input is not validated as UTF-8: bytes
  above `0x7F` are passed through unchanged. Lone surrogates and unknown escapes
  are rejected; unescaped control bytes `< 0x20` are rejected.
- **No mutation, no DOM.** Values cannot be edited in place; build new output with
  `JsonOut` and `emit`. There is no pretty printer.
- **Duplicate keys are not an error**; `member` returns the last one.

## When to use it

Use it for configuration files, small protocol payloads, logs and test fixtures
where the whole text is already in memory and lookups are few. Use something else
when you need random access over large arrays, mutation, streaming of huge
documents, schema validation, exact decimal arithmetic, or pretty printing.

## 中文

一个 CT 文件：校验 JSON、在调用方文本上暴露只读视图、再把值序列化回去。全程
不分配内存、不持有所有权、不建 DOM。解析后的“文档”就是原始字节加上第一个错误的
偏移；每次查找重新扫描需要的那一段。

构建与运行：

```sh
ct-ast json.ct -o /tmp/json.c
cc -Wall -Wextra -std=c99 /tmp/json.c -o /tmp/json && /tmp/json
```

[`json.expected.out`](json.expected.out) 是基准输出：用 `ct-ast` 构建
`json.ct`，运行后与它比对。程序同时是演示（`-- demo --`）和
一致性测试（`ok` / `FAIL` 行，失败时以非零退出）。

### 文件里有什么

| 部分 | 内容 |
| --- | --- |
| 读取 | `JsonDoc` + `trait Json`：`parse`、`root`、`kind`、`count`、`member`、`at`、`as_*`、`offset_of`、`len_of`、`emit` 及错误访问器 |
| 写入 | `JsonOut` + `trait JsonWrite`：`begin`、`object`、`array`、`end`、`key`、`string`、`integer`、`real`、`boolean`、`null`、`finish`、`length`、`error` |
| 视图 | `JsonView { start, len }`，是传给 `parse` 的文本里的一个字节区间 |
| 演示/测试 | `main` 驱动 `demo`、`reader`、`writer`、`errors` 四段 |

生成的 C 符号全部是文件内 `static` 的；这个文件应当被复制进程序或作为一个单元
导入，而不是当作可链接的库。

### 读取

```c
struct JsonDoc doc;
struct JsonView root;
struct JsonView v;
char name[32];
long long stars;

if (!doc.parse(text, len)) {
    printf("%s at %d:%d\n", json_message(doc.error()),
            doc.error_line(), doc.error_column());
    return;
}
root = doc.root();
v = doc.member(&root, "name");
doc.as_string(&v, name, sizeof name);
v = doc.member(&root, "stars");
doc.as_int(&v, &stars);
```

`parse` 一次校验整个文档。`JsonView` 只是一个切片，所以只要文本还活着，视图就
有效；没有句柄、没有 free、没有额外生命周期。`member` 对重复键保留**最后一个**；
`at` 用从 0 开始的下标；找不到时都返回 `MISSING` 视图。

`as_string` 会把 `\"`、`\\`、`\/`、`\b`、`\f`、`\n`、`\r`、`\t`、`\uXXXX`
以及代理对解码成 UTF-8。它返回解码后的长度，语义同 `snprintf`：缓冲区不够就截断
并补 NUL，但返回值始终是所需长度，所以 `cap = 0` 可以用来量长度。

`as_int` 只接受纯整数字面量且必须在 `int64` 范围内：`1.0`、`1e3` 报
`JSON_READ_INTEGER`，越界报 `JSON_READ_RANGE`。`as_double` 接受任意数字词法。

### 写入

```c
struct JsonOut out;
char buf[256];

out.begin(buf, sizeof buf);
out.object();
out.key("name");
out.string("ct");
out.key("stars");
out.integer(42);
out.end();
if (out.finish() < 0) { /* out.error() */ }
```

`JsonOut` 追加到调用方缓冲区，嵌套栈（深度 64）就放在结构体里。
`begin(buf, 0)` 只量长度不写；`finish` 补 NUL 并返回所需长度，结构错误
（`JSON_EMIT_STATE`）、嵌套过深（`JSON_EMIT_DEPTH`）、非有限实数
（`JSON_EMIT_FINITE`）返回 `-1`。字符串会被转义，控制字节写成 `\u00XX`；
`real` 用 `%.17g` 输出。`emit` 把一个视图的字节复制进 `JsonOut`，因此解析出的
子树可以被嵌入或原样往返。

### 边界与限制

- **零分配。** 没有 `malloc`，没有隐藏所有权；唯一的资源限制是嵌套深度（默认
  64 层容器，可在 `parse` 前改 `doc.depth_limit`）和输出长度。
- **惰性查找是 O(n)。** 每次 `member`/`at`/`count` 都重新扫描所在容器。适合
  配置大小的文档，不适合在大数组上热循环。
- **错误模型是一个错误码加一个字节偏移**，行列按需计算（从 1 开始；列按字节，
  制表符算 1，遇 `\n` 换行）。
- **数字精度。** 整数在 `int64` 内精确。实数用手写十进制转换（不用 `strtod`，
  因而与 locale 无关），最多取 19 位有效数字并对指数做截断；最后一位可能与
  正确舍入的结果不同。需要精确十进制原文时用 `offset_of`/`len_of` 取原词。
- **字符串**会解码成 UTF-8，但不校验输入是否为合法 UTF-8：`0x7F` 以上的字节
  原样透传。孤立代理项和未知转义会被拒绝；字符串内未转义且小于 `0x20` 的控制
  字节也会被拒绝。
- **没有可变 API，没有 DOM。** 不能原地改值；要改就用 `JsonOut` 重新构造并
  `emit`。没有美化输出。
- **重复键不算错误**；`member` 返回最后一个。

### 什么时候该用它

适合整段文本已经在内存里、查找次数不多的场景：配置文件、小型协议报文、日志、
测试夹具。需要大数组随机访问、原地修改、超大文档流式处理、schema 校验、精确
十进制运算或格式化输出时，应换别的方案。
