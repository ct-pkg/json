# js_style 样例索引（CT v0.53.0 实测）

本目录原有 14 个样例（目标 1～9b），本轮新增 10 个（目标 10～12d、13、14），编号延续原有写法。
构建命令统一在仓库根目录执行：

```sh
CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build <文件> -I src -o <可执行文件>
```

状态口径（与评估文档一致）：

- **可运行**：当前 CT 版本下构建 rc=0，程序正常退出。
- **设计拒绝**：编译器有明确规则并报错，属于语言设计边界，不是 ct-json 的实现缺陷。
- **未实现 / 提案形态**：语法尚未落地（`v[]` 拟占 PH-61），样例只记录目标写法。

## 一、新增样例

| 文件 | 目标 | 覆盖 | 状态 | 结果 |
| --- | --- | --- | --- | --- |
| `js_sub_cases.ct` | 10 | 下标读一层、读嵌套、缺键、越界 | 可运行 | rc=0 |
| `js_opt_pointer.ct` | 11a | `?.` 在指针上（`JsonNode *`、字段链、NULL） | 可运行 | rc=0 |
| `js_opt_value.ct` | 11b | `?.` 在 `JsonRef`（struct 值）上 | 设计拒绝 | rc=1 |
| `js_opt_method.ct` | 11c | `?.` 后直接调 `Map` 方法 | 设计拒绝 | rc=1 |
| `js_opt_subscript_map_ptr.ct` | 12a | `?[` 在 `Map` 指针上（命中、缺键、空指针） | 可运行 | rc=0 |
| `js_opt_subscript_value.ct` | 12b | `?[` 在 `JsonRef`（struct 值）上 | 设计拒绝 | rc=1 |
| `js_opt_subscript_result.ct` | 12c | `?[` 的返回类型不是指针/标量 | 设计拒绝 | rc=1 |
| `js_opt_subscript_dot.ct` | 12d | JS 写法 `?.["k"]`（CT 只认 `?[`） | 设计拒绝（语法不认） | rc=1 |
| `js_append_push.ct` | 13 | 追加的现代表达：`push` 后长度与下标变化 | 可运行 | rc=0 |
| `proposal/js_append_empty.ct` | 14 | 空方括号追加 `v[] = x` | **提案形态（PH-61，未实现）** | rc=1 |

`proposal/` 单独成目录，避免与可运行写法混排、被误读成既有能力。

## 二、可运行样例的实测输出

### 目标 10：下标访问的四种情形

```console
$ CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build docs/snippets/js_style/js_sub_cases.ct -I src -o /tmp/s_js_sub_cases
'cc' -std=c99 -I '.ctbuild' '.ctbuild/Vec.c' '.ctbuild/Option.c' '.ctbuild/Result.c' '.ctbuild/Str.c' '.ctbuild/js_sub_cases.c' '.ctbuild/json.c' '-o' '/tmp/s_js_sub_cases'
$ /tmp/s_js_sub_cases
level1 tag=4
nested tag=3 host=db.local
missing empty=1 tag=-1
index hit empty=0 tag=2; oob empty=1 tag=-1
```

`missing` 是空句柄（`p == 0`、`tag == -1`），不是 JSON null；`get_idx(len)` 越界同样给空句柄，不崩。

### 目标 11a：`?.` 在指针上

```console
$ CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build docs/snippets/js_style/js_opt_pointer.ct -I src -o /tmp/s_js_opt_pointer
'cc' -std=c99 -I '.ctbuild' '.ctbuild/Vec.c' '.ctbuild/Option.c' '.ctbuild/Result.c' '.ctbuild/Str.c' '.ctbuild/js_opt_pointer.c' '.ctbuild/json.c' '-o' '/tmp/s_js_opt_pointer'
$ /tmp/s_js_opt_pointer
root?.tag=4 missing?.tag=0 fieldchain=4
```

`?.` 在当前 CT 里**已经存在**，但只接受指针接收者：`JsonNode *` 可用，`doc.p?.tag` 这种字段链也可用。空指针落「空状态」，给该字段的零值；`missing?.tag` 的 `0` 与 JSON null 的 `tag=0` 同值，**不能靠它区分缺键与显式 null**，仍需 `has` 或先看 `p == 0`。

### 目标 12a：`?[` 在 `Map` 指针上

```console
$ CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build docs/snippets/js_style/js_opt_subscript_map_ptr.ct -I src -o /tmp/s_js_opt_subscript_map_ptr
'cc' -std=c99 -I '.ctbuild' '.ctbuild/Vec.c' '.ctbuild/Option.c' '.ctbuild/Result.c' '.ctbuild/Str.c' '.ctbuild/js_opt_subscript_map_ptr.c' '-o' '/tmp/s_js_opt_subscript_map_ptr'
$ /tmp/s_js_opt_subscript_map_ptr
map ptr got=1 len=8 miss=1 null=1
```

`mp?[key]` 在 `Map<Str, Str> *` 上可用：命中给 `Str *`，缺键给 0，空指针也给 0（不解引用）。返回类型必须能表示 NULL（指针或标量）。

### 目标 13：追加的当前写法

```console
$ CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build docs/snippets/js_style/js_append_push.ct -I src -o /tmp/s_js_append_push
'cc' -std=c99 -I '.ctbuild' '.ctbuild/Vec.c' '.ctbuild/Option.c' '.ctbuild/Result.c' '.ctbuild/Str.c' '.ctbuild/js_append_push.c' '.ctbuild/json.c' '-o' '/tmp/s_js_append_push'
$ /tmp/s_js_append_push
len 1 -> 2; [1] tag=2; [2] empty=1
```

`push` 后长度 +1，新元素落在 `len-1`；旧下标不变；新长度本身仍是越界下标。

## 三、跑不通的样例与原始报错

### 目标 11b：`?.` 用在 `JsonRef` 值上（设计拒绝）

```console
$ CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build docs/snippets/js_style/js_opt_value.ct -I src -o /tmp/s_js_opt_value
docs/snippets/js_style/js_opt_value.ct:13:17: error: optional chain '?.' requires a pointer receiver; a struct value has no empty state
ctc: 1 error(s) generated
$ echo $?
1
```

### 目标 11c：`?.` 后直接调方法（设计拒绝）

```console
$ CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build docs/snippets/js_style/js_opt_method.ct -I src -o /tmp/s_js_opt_method
docs/snippets/js_style/js_opt_method.ct:11:11: error: optional method calls are not supported; assign the receiver to a variable first
ctc: 1 error(s) generated
$ echo $?
1
```

### 目标 12b：`?[` 用在 `JsonRef` 值上（设计拒绝）

```console
$ CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build docs/snippets/js_style/js_opt_subscript_value.ct -I src -o /tmp/s_js_opt_subscript_value
docs/snippets/js_style/js_opt_subscript_value.ct:13:17: error: optional subscript '?[' requires a pointer receiver; a struct value has no empty state
ctc: 1 error(s) generated
$ echo $?
1
```

### 目标 12c：`?[` 的结果类型不可空（设计拒绝）

```console
$ CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build docs/snippets/js_style/js_opt_subscript_result.ct -I src -o /tmp/s_js_opt_subscript_result
docs/snippets/js_style/js_opt_subscript_result.ct:15:16: error: optional subscript result must be a pointer or scalar; 'JsonRef' has no NULL representation
ctc: 1 error(s) generated
$ echo $?
1
```

### 目标 14：空方括号追加（提案形态，未实现）

```console
$ CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build docs/snippets/js_style/proposal/js_append_empty.ct -I src -o /tmp/s_js_append_empty
docs/snippets/js_style/proposal/js_append_empty.ct:23:11: error: expected an expression
$ echo $?
1
```

`v[] = x` 拟占 **PH-61**，当前只有目标写法；等价能力是 `v.push(x)`（目标 13）。

## 四、目标 12d：`?.["k"]` 不是 CT 语法（设计拒绝）

JS 的 `obj?.["k"]` 在 CT 里不成立，`?.` 之后必须跟字段或方法名：

```console
$ CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build docs/snippets/js_style/js_opt_subscript_dot.ct -I src -o /tmp/s_js_opt_subscript_dot
docs/snippets/js_style/js_opt_subscript_dot.ct:13:19: error: expected a field or method name
$ echo $?
1
```

CT 的可选下标写成 `?[`（无点），且只对指针接收者成立（目标 12a/12b）。

## 五、结论

| 形态 | 当前状态 | 说明 |
| --- | --- | --- |
| `v["k"]` / `v["k"] = x` | 可运行 | 单层；两级链限声明初始化/赋值位置 |
| `v.get_idx(i)` | 可运行 | 越界返回空句柄 |
| `p?.field`（`p` 为指针） | 可运行 | 空指针给零值，不能区分缺键与 null |
| `m?[key]`（`m` 为 `Map *`） | 可运行 | 结果必须可空（指针/标量） |
| `v?.field` / `v?["k"]`（`v` 为 struct 值） | 设计拒绝 | 值类型没有空状态 |
| `v?.["k"]` | 设计拒绝（语法） | CT 写作 `v?["k"]` |
| `p?.method()` | 设计拒绝 | 可选方法调用未支持 |
| `v[] = x` | 提案形态（PH-61） | 当前用 `v.push(x)` |

本轮只加样例与说明：包实现、公开 API、规范均未改动。若 PH-61 落地，`v[] = x` 的落点就是现有 `push`（共享引用、长度 +1），不需要新增接口层；若可选链将来允许值接收者，`JsonRef` 已有的 `p == 0` 空句柄即可充当空状态，也不需要新接口。
