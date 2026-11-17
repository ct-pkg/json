<!-- applies-to: 0.6.0 -->
# ct-json 下标访问样例

实测基线：CT `v0.53.0`（链式访问相关样例在 `v0.62.0` 复跑，见 §3b）。下列输出全部是本机实跑原文，命令都在仓库根目录执行：

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
| `chain3.ct` | 三级下标链、下标结果作接收者、方法结果链 | 可运行（v0.62.0） |
| `numeric_index.ct` | `arr[0]` 与 `get_idx(0)` 的实际差别 | 可运行 |
| `cross_unit.ct` | 定义在 `src/json.h.ct`、使用在本文件 | 可运行 |
| `fail/char_key.ct` | `char *` 键传给 `json_member` | 不编译（照现状记录，JSON-3） |
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

两级链可用位置：声明初始化、赋值右值。三级链、下标结果作接收者、方法结果链在 CT v0.62.0 起可用，见 §3b；仍不可用的是把链式结果直接作函数实参，登记在 `issues/JSON-5.md`。

## 3b. 三级链与方法结果链（v0.62.0）

```sh
CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build docs/snippets/chain3.ct -I src -o /tmp/s_chain3
/tmp/s_chain3
```

```console
decl init: tag=2 value=1
assign rhs: tag=2 value=1
subscript receiver: has(host)=1
method chain: tag=4
chain3 ok
```

`doc["a"]["b"]["c"]` 在声明初始化与赋值右值两个位置都可用；`doc["server"].has(k)`（下标结果作接收者）与 `doc.get("a").get("b")`（方法结果链）同样可用。写链 `doc["a"]["b"]["c"] = x` 仍不可用，报 `a custom subscript write needs a statement and an lvalue receiver`，登记为 `JSON-6`；链式结果作函数实参仍不可用，见 `JSON-5`。

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
| 去掉 `pub` 的 `get` | `error: type 'Box' has no subscript: 'get' is private to its unit` | 本包使用约束（设计要求，不是缺陷） |

## 7. 能力总结

| 能力 | 0.1.0 现状 | 做不到的原因归属 |
| --- | --- | --- |
| `v["k"]` 读 / `v["k"] = x` 写 | 可用（跨单元需 `pub`） | — |
| 两级链（初始化/赋值） | 可用 | — |
| 三级链 | 可用（v0.62.0，声明初始化/赋值） | — |
| 对结果继续调方法 | 可用（v0.62.0） | — |
| 三级写链 `a["b"]["c"]["d"] = x` | 不可用 | 语言层（JSON-6） |
| 链式结果作函数实参 | 不可用 | 语言层（JSON-5） |
| `v[0]` 数字下标 | 编译通过但静默空句柄 | 语言层（已交编译组，见规范 §3.4；按裁定只记录，不另立条目） |
| `arr.get_idx(i)` | 可用，越界返回空句柄 | — |

写样例期间未发现本包实现问题；`issues/` 下 JSON-1…3、JSON-5、JSON-6 为语言层上游问题，JSON-4 为包消费问题（已 fixed），JSON-7 为门禁夹具问题（已 fixed）。

## 8. JS 风格使用形态（评估样例）

`docs/snippets/js_style/` 覆盖点访问、链式写、值语义、打印、迭代与字面量键，每条文件头标注 **(a)** 今天可用 / **(b)** 只需改库或 std 接口 / **(c)** CT 语言缺能力。评估结论见 [ct-json-0.1.0-js-style-eval.md](../review/ct-json-0.1.0-js-style-eval.md)。

目标编号 10～13 是本轮新增的下标 / 可选链 / 追加样例，全部在当前 CT v0.53.0 上实跑通过，逐条命令与原始输出见 [js_style/README.md](js_style/README.md)。空方括号 `v[] = x` 拟占 PH-61、尚未实现，不提供样例。
