# ct-json 下标访问样例

实测基线：CT `v0.53.0`。下列输出全部是本机实跑原文，命令都在仓库根目录执行：

```sh
CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build <文件> -I src -o <可执行文件>
```

能跑的文件构建退出码为 0；`fail/` 下的文件按设计不编译，保留原始报错作为「照现状记录」，不是为了凑样例改写的替代写法。

## 索引

| 文件 | 演示 | 结果 |
| --- | --- | --- |
| `read_str.ct` | 单层 `v["k"]` 读、缺失键与显式 null 的区分 | 可运行 |
| `write_str.ct` | `v["k"] = ref` 覆盖与新增、共享引用、`set_str`/`set_bool` | 可运行 |
| `chain.ct` | 两级链在声明初始化、赋值右值两个位置 | 可运行 |
| `numeric_index.ct` | `arr[0]` 与 `get_idx(0)` 的实际差别 | 可运行 |
| `cross_unit.ct` | 定义在 `src/json.h.ct`、使用在本文件 | 可运行 |
| `fail/char_key.ct` | `char *` 键传给 `json_member` | 不编译（照现状记录，JSON-3） |
| `fail/three_level_chain.ct` | 三级下标链 | 不编译（照现状记录，JSON-1） |
| `fail/temp_receiver.ct` | `doc["server"].has(k)` | 不编译（照现状记录，JSON-2） |
| `fail/private_get.ct` | 定义单元 `get` 未加 `pub` | 不编译（照现状记录，说明跨单元要求） |

## 1. 字符串键读取

```sh
CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build docs/snippets/read_str.ct -I src -o /tmp/s_read_str
/tmp/s_read_str
```

```console
server: tag=4 host=db.local
missing: empty=1 tag=-1
explicit null: empty=0 tag=0 is_null=1
has(host)=1 has(nope)=0
```

`v["k"]` 返回 `JsonRef`（8 字节值句柄），不是 `char *`；值是借用的，要 `json_as_*` 显式取出。缺失键是空句柄（`p == 0`、`tag == -1`），显式 null 是有效句柄（`tag == 0`），两者靠 `has(Str)` 或 `tag` 区分。

## 2. 字符串键写入 / 覆盖 / 新增

```sh
CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build docs/snippets/write_str.ct -I src -o /tmp/s_write_str
/tmp/s_write_str
```

```console
encoded: {"port":9090,"name":9090}
keys: 2
after set_str/set_bool: {"port":9090,"name":9090,"owner":"ops","enabled":true}
```

覆盖保持原位，新增追加到尾部。写是共享引用：容器 retain 自己的一份，调用方仍然持有并负责 `json_release`。

## 3. 两级链

```sh
CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build docs/snippets/chain.ct -I src -o /tmp/s_chain
/tmp/s_chain
```

```console
decl init: tag=4
assign rhs: tag=4
third level: tag=2 value=1
```

可用位置：声明初始化、赋值右值。不可用位置：三级链、作为函数参数、对结果继续调方法——分别见 `fail/` 下三个文件与 `issues/JSON-1.md`、`JSON-2.md`。

## 4. 数字下标与 `get_idx`

```sh
CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build docs/snippets/numeric_index.ct -I src -o /tmp/s_numeric_index
/tmp/s_numeric_index
```

```console
items[0]:   empty=1 tag=-1
get_idx(0): empty=0 tag=2 value=1
get_idx(2): empty=1 tag=-1
```

`items[0]` **能编译**，但它展开成 `get(0)`，`0` 作为空 `char *` 键传入，于是静默拿到空句柄（`tag == -1`）——不是数组访问，也不报错。数组读要写 `items.get_idx(0)`；越界同样返回空句柄。

## 5. 跨单元

```sh
CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build docs/snippets/cross_unit.ct -I src -o /tmp/s_cross_unit
/tmp/s_cross_unit
```

```console
keys=2 alias_tag=4
```

`JsonRef` 定义在 `src/json.h.ct`，本文件只是使用方。下标能跨单元，靠的是定义侧的 `pub`：

```ct
pub JsonRef get(char *key);
pub void    set(char *key, JsonRef value);
```

去掉 `pub` 的实际结果（照现状记录）：

```console
$ ct build docs/snippets/fail/private_get.ct -I src -I docs/snippets/fail/private_unit -o /tmp/f_priv
docs/snippets/fail/private_get.ct:19:14: error: type 'Box' has no subscript: 'get' is private to its unit
ctc: 1 error(s) generated
```

## 6. 失败对照（照现状记录）

| 写法 | 原文报错 | 归属 |
| --- | --- | --- |
| `json_member(doc, "k")` | `warning: type mismatch: 'json_member' argument 2: expected 'struct Str', got 'char *'`，随后 `error: passing 'char[2]' to parameter of incompatible type 'struct Str'` | 语言层诊断分级（JSON-3） |
| `doc["a"]["b"]["c"]` | `error: a method call on a temporary is only allowed at the start of a statement or of an assignment` | 语言层（JSON-1） |
| `doc["server"].has(k)` | `error: method receiver must be a variable, an element, a call or a field chain` | 语言层（JSON-2） |
| 去掉 `pub` 的 `get` | `error: type 'Box' has no subscript: 'get' is private to its unit` | 本包使用约束（设计要求，不是缺陷） |

## 7. 能力总结

| 能力 | 0.1.0 现状 | 做不到的原因归属 |
| --- | --- | --- |
| `v["k"]` 读 / `v["k"] = x` 写 | 可用（跨单元需 `pub`） | — |
| 两级链（初始化/赋值） | 可用 | — |
| 三级链 | 不可用 | 语言层（JSON-1） |
| 对结果继续调方法 | 不可用 | 语言层（JSON-2） |
| `v[0]` 数字下标 | 编译通过但静默空句柄 | 语言层（已交编译组，见规范 §3.4；按裁定只记录，不另立条目） |
| `arr.get_idx(i)` | 可用，越界返回空句柄 | — |

写样例期间未发现本包实现问题；`issues/` 下三条均为语言层上游问题。
