# 错误契约与失败清理（PH-5）

- 日期：2026-11-17
- 基线：`fdd1b2c` 之后的工作树（CT `v0.63.0`）
- 依据：R-B-03、R-C-01、R-C-03、R-C-05、D-001、D-006

## 1. 夹具

```console
$ CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build test/j5_errors.ct -I src -o /tmp/j5 && /tmp/j5
...
ok 30 a valid document still decodes after failures
ok 31 the valid document has its member
all checks passed
$ /tmp/j5 | grep -c '^ok '
31
```

## 2. 位置

```console
$ /tmp/j5 | grep -e 'offset is' -e 'line/col' -e '1:1' -e '2:7'
ok 13 trailing offset is 3
ok 14 trailing line/col is 1:4
ok 17 the missing colon offset is 8
ok 18 the missing colon is 2:7
ok 20 empty input is at 0, 1:1
```

## 3. 失败清理（ASan）

```console
$ CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build test/j5_errors.ct -I src -o /tmp/j5_asan \
    --cflags '-fsanitize=address -g' --ldflags '-fsanitize=address'
$ ASAN_OPTIONS=detect_leaks=0 /tmp/j5_asan
all checks passed
```

ASan 命中 0；夹具断言未完成对象/数组失败后 `out` 为空、随后合法文档仍可解码。
`detect_leaks` 在 macOS 不可用，泄漏检测没有运行证据（平台缺口）。

## 4. 非有限实数

```console
$ /tmp/j5 | grep -e 'nan encode' -e 'inf encode' -e 'finite double'
ok 2 nan encode rejected
ok 4 inf encode rejected
ok 6 -inf encode rejected
ok 8 a finite double still encodes
```

NaN / +Inf / -Inf 都返回 `NULL` + `JSON_ERR_RANGE`；合法 double 仍编码。

## 5. 泄漏与 int64 下限（PH-5 终验补）

```console
$ leaks --atExit --nosources -- /tmp/j5
Process: 0 leaks for 0 total leaked bytes.
$ /tmp/j1p5 | tail -1
all checks passed
$ /tmp/j1p5 | grep 'int64 min is exact'
ok 119 int64 min is exact
```

JSON-14 修复后对象不再泄漏 32B Map 头；JSON-13 绕行后 INT64_MIN 精确。
