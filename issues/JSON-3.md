# JSON-3 `char *` 传给 `Str` 形参只报 warning，由 C 层兜底

- status: open
- 归属: **语言层**（上游 ct v0.53.0 的诊断分级），不是本包实现问题
- 优先级: P3（构建仍然失败，不产生错误二进制；只是诊断滞后）
- 影响面: 所有收 `Str` 的键 API，例如 `json_member(v, "k")`
- 关联: 规范 §3.2；样例 `docs/snippets/fail/char_key.ct`

## 触发条件

把 `char *` 实参传给形参类型为 `Str` 的函数。

## 最小复现

```sh
CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std \
  ct build docs/snippets/fail/char_key.ct -I src -o /tmp/f_char_key
```

## 实际行为

CT 先报一条 **warning** 并继续生成 C，随后 cc 报 error：

```console
docs/snippets/fail/char_key.ct:18:17: warning: type mismatch: 'json_member' argument 2: expected 'struct Str', got 'char *'
'cc' -std=c99 -I '.ctbuild' ... -o '/tmp/f_char_key'
docs/snippets/fail/char_key.ct:23:41: error: passing 'char[2]' to parameter of incompatible type 'struct Str'
   23 |     struct JsonRef m = json_member(doc, "k");
      |                                         ^~~
1 error generated.
$ echo $?
1
```

## 期望行为

CT 自己把类型不匹配当 error 终止，不依赖 C 编译器兜底。

## 本包绕法

无，也不应绕：键只收 `Str` 是裁定结果；这条只影响诊断体验，不影响最终构建结果。
