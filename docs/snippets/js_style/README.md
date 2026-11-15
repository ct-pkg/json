# js_style 样例索引（CT v0.53.0 实测）

本目录原有 14 个样例（目标 1～9b），本轮新增 5 个（目标 10～13），编号延续原有写法。
**新增样例全部是当前 CT 已支持的写法，构建 rc=0、运行 rc=0**；构建命令统一在仓库根目录执行：

```sh
CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build <文件> -I src -o <可执行文件>
```

## 一、新增样例

| 文件 | 目标 | 覆盖 | 结果 |
| --- | --- | --- | --- |
| `js_sub_cases.ct` | 10 | 下标：读一层、读嵌套、缺键、越界 | 构建/运行 rc=0 |
| `js_opt_pointer.ct` | 11a | `?.` 在 `JsonNode *` 上、字段链、空指针 | 构建/运行 rc=0 |
| `js_opt_chain.ct` | 11b | `?.` 多级链在普通指针上 | 构建/运行 rc=0 |
| `js_opt_subscript_map_ptr.ct` | 12 | `?[` 在 `Map<Str, Str> *` 上（命中、缺键、空指针） | 构建/运行 rc=0 |
| `js_append_push.ct` | 13 | `push` 追加后的长度与下标变化 | 构建/运行 rc=0 |

空方括号 `v[] = x` 拟占 **PH-61**，尚未实现，本目录不提供样例；当前等价写法是 `v.push(x)`（目标 13）。

## 二、实测输出

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

### 目标 11a：`?.` 在 `JsonNode *` 上

```console
$ CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build docs/snippets/js_style/js_opt_pointer.ct -I src -o /tmp/s_js_opt_pointer
'cc' -std=c99 -I '.ctbuild' '.ctbuild/Vec.c' '.ctbuild/Option.c' '.ctbuild/Result.c' '.ctbuild/Str.c' '.ctbuild/js_opt_pointer.c' '.ctbuild/json.c' '-o' '/tmp/s_js_opt_pointer'
$ /tmp/s_js_opt_pointer
root?.tag=4 missing?.tag=0 fieldchain=4
```

`?.` 接受指针接收者：`JsonNode *` 可用，`doc.p?.tag` 这种字段链也可用。空指针落空状态，给该字段的零值；`missing?.tag` 的 `0` 与 JSON null 的 `tag=0` 同值，不能靠它区分缺键与显式 null。

### 目标 11b：`?.` 多级链

```console
$ CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build docs/snippets/js_style/js_opt_chain.ct -I src -o /tmp/s_js_opt_chain
'cc' -std=c99 -I '.ctbuild' '.ctbuild/Vec.c' '.ctbuild/Option.c' '.ctbuild/Result.c' '.ctbuild/Str.c' '.ctbuild/js_opt_chain.c' -o '/tmp/s_js_opt_chain'
$ /tmp/s_js_opt_chain
mid=7 beyond=0 none?.v=0
```

`head.next?.v` 命中给 7；`head.next?.next?.v` 在第二环为空时给 0；接收者本身为空同样给 0，链上任一空环都短路。

### 目标 12：`?[` 在 `Map` 指针上

```console
$ CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build docs/snippets/js_style/js_opt_subscript_map_ptr.ct -I src -o /tmp/s_js_opt_subscript_map_ptr
'cc' -std=c99 -I '.ctbuild' '.ctbuild/Vec.c' '.ctbuild/Option.c' '.ctbuild/Result.c' '.ctbuild/Str.c' '.ctbuild/js_opt_subscript_map_ptr.c' '-o' '/tmp/s_js_opt_subscript_map_ptr'
$ /tmp/s_js_opt_subscript_map_ptr
map ptr got=1 len=8 miss=1 null=1
```

`mp?[key]` 在 `Map<Str, Str> *` 上可用：命中给 `Str *`，缺键给 0，空指针也给 0（不解引用）。

### 目标 13：追加的当前写法

```console
$ CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build docs/snippets/js_style/js_append_push.ct -I src -o /tmp/s_js_append_push
'cc' -std=c99 -I '.ctbuild' '.ctbuild/Vec.c' '.ctbuild/Option.c' '.ctbuild/Result.c' '.ctbuild/Str.c' '.ctbuild/js_append_push.c' '.ctbuild/json.c' '-o' '/tmp/s_js_append_push'
$ /tmp/s_js_append_push
len 1 -> 2; [1] tag=2; [2] empty=1
```

`push` 后长度 +1，新元素落在 `len-1`；旧下标不变；新长度本身仍是越界下标。

## 三、覆盖对照

| 真实用法 | 样例 |
| --- | --- |
| 读一层 | `js_sub_cases.ct` |
| 读嵌套 | `js_sub_cases.ct` |
| 缺键 | `js_sub_cases.ct` |
| 越界 | `js_sub_cases.ct` |
| `?.` 在 JSON 树指针上 | `js_opt_pointer.ct` |
| `?.` 多级链在指针上 | `js_opt_chain.ct` |
| `?[` 在 `Map` 指针上 | `js_opt_subscript_map_ptr.ct` |
| 追加后的长度与下标 | `js_append_push.ct` |

本轮只加样例与说明：包实现、公开 API、规范均未改动。
