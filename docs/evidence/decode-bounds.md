# 解码边界复核（PH-4）

- 日期：2026-11-17
- 基线：`6f8b0ed` 之后的工作树（CT `v0.62.0`）
- 依据：R-A-08/09/10/11/12、D-002、D-005

## 1. 深度硬上限（R-A-10）

```console
$ CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build test/depth_1m.ct -I src -o /tmp/depth1m && /tmp/depth1m
depth1m: rc=-9 empty=1
$ echo $?
0
```

10^6 层 `[` 在 65 层停住，返回 `JSON_ERR_DEPTH`（-9），根为空，无栈溢出。

## 2. 20k 遍历（R-A-11）

```console
$ CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build test/perf_20k.ct -I src -o /tmp/perf20k && /tmp/perf20k
perf20k: sum=20000 elapsed=6.708ms
$ echo $?
0
```

本机多次测量在 0.9–6.7 ms 之间（受机器负载影响），均 < 10 ms；`sum=20000` 说明全量读回。
夹具内置 `< 10 ms` 断言。

## 3. 严格 UTF-8 与 BOM（R-A-08 / R-A-12）

```console
$ CT_STD_DIR=... ct build test/j4_decode.ct -I src -o /tmp/j4 && /tmp/j4
16 ok / all checks passed
$ echo $?
0
```

覆盖：0xFF、overlong C0 AF、overlong F0 80 80 80、UTF-8 代理 ED A0 80、
孤立续字节 80 在 strict 下报 `JSON_ERR_UTF8`；合法 2/4 字节与转义代理对通过；
BOM 在宽松/严格两模式都报 `JSON_ERR_SYNTAX`；合法文档两模式根字节一致。

## 4. 实数溢出与精度（R-A-09 / JSON-10）

```console
$ CT_STD_DIR=... ct build test/j1_roundtrip.ct -I src -o /tmp/j1p4 && /tmp/j1p4
145 ok / all checks passed
$ echo $?
0
```

`1e999`/`-1e999` → `JSON_ERR_RANGE` 且 `out` 不变；`1e-400` → 0.0；
`0.30000000000000004` bit-exact。

## 5. 回归

```console
$ bash tools/check.sh g3
ok g3 (j1_roundtrip, json.expected.out, zero warnings)
$ bash tools/check.sh g7
ok g7 (secret scan clean, ASan run clean; detect_leaks unavailable on this platform)
```
