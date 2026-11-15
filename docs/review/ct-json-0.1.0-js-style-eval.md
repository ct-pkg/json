# ct-json「JS 风格」使用形态评估

> 范围：**只评估，不改实现、不改现有 API、不改既有规范**。
> 定位：ct-json 是**外部包**，不是 CT 内部机制；JSON 文档 = `Vec` / `Map` 组合，CT 没有内置 JSON 类型。本文所有「缺什么」都按容器能力口径写（§五）。
> 基线：CT `v0.53.0`，ct-json 0.1.0 当前公开面（`JsonRef` 为 tagged 句柄）。
> 样例：`docs/snippets/js_style/`，每条都是真跑出来的；失败样例保留原始报错，未改写成语义不同的替代写法。

## 一、结论

1. 今天能用的只有：单层 `doc["k"]` 读写、两级链**读**（声明初始化/赋值右值）、`get_idx(i)`、`has(Str)`、`json_obj_key_at`、`json_encode`。
2. `doc.server.host`、`doc["a"]["b"] = x`、`doc["port"] + 1`、`printf("%s", doc["host"])`、`for (e in arr)`、`doc.has("k")` 六类写法目前**都写不出来**。
3. **瓶颈在 CT 内置容器的能力边界，不在 ct-json 的接口设计。** ct-json 是外部包，JSON 的值形态就是 `Vec` / `Map` 的组合；点访问、链式写、值语义、迭代协议这四类写法，本质都是「让 `Vec` / `Map` 像 JS 对象/数组那样用」所缺的语法能力。换任何库设计都做不出来，扩张本包自有句柄层也解决不了。
4. 有一条例外路径：为固定 schema 生成静态 `struct`，点访问、算术、打印全部原生可用（§四 C），但那是静态 schema 形态，不是动态 JSON。
5. 0.1.0 完工判定不受影响；本评估不改变既有 J 判据结论。

## 二、实测矩阵

分类：**(a)** 今天就能用；**(b)** 报错但只需改库/std 的接口设计；**(c)** CT 语言缺能力。

| # | 写法 | 样例 | 实测结果 | 类 |
| --- | --- | --- | --- | --- |
| 1 | `doc["port"]` 读 | `js_subscript.ct` | `read tag=2` | a |
| 2 | `doc["port"] = ref` | `js_subscript.ct` | `write {"port":9090}` | a |
| 3 | `doc["server"]["host"]` 读 | `js_chain2_read.ct` | `chain read tag=3 host=db.local` | a |
| 4 | `doc["server"]["port"] = ref` | `js_chain2_write.ct` | `error: a custom subscript write needs a statement and an lvalue receiver` | c |
| 5 | `arr[0]` | `js_mixed.ct` | `arr[0] empty=1 tag=-1`（静默空句柄） | c |
| 6 | `arr.get_idx(0)["name"]` | `js_mixed.ct` | `real[name] tag=3` | a |
| 7 | `doc["port"] + 1` | `js_value.ct` | `error: invalid operands to binary expression ('struct JsonRef' and 'int')` | c |
| 8 | `printf("%s", doc["host"])` | `js_print.ct` | 编译通过，输出 `host=` + 0x03（把节点指针当字符串读到 tag 字节） | c |
| 9 | `for (JsonRef e in tags)` | `js_iter_native.ct` | `error: unexpected token` | c |
| 10 | 下标循环迭代数组/对象 | `js_iter_index.ct` | `arr[0]=a` … `key[0]=tags` | a |
| 11 | `doc.has("host")` | `js_has_charptr.ct` | `error: passing 'char[5]' to parameter of incompatible type 'struct Str'` | b/c |
| 12 | `doc.has(Str)` | `js_has_str.ct` | `has(host)=1 has(nope)=0` | a |
| 13 | `Map<Str,Str> m[k]`（Str 变量） | `js_native_map.ct` | `len=1 has=1 null=0 got=db.local` | a |
| 14 | `m["host"]`（字面量） | `js_native_map_literal.ct` | std 头里 `error: passing 'char[5]' ... 'struct Str'` | b |
| 15 | `doc.server.host` | `js_dot.ct` | `error: no member named 'server' in 'struct JsonRef'` | c |
| 16 | 静态 struct 的 `doc.server.host` | `js_struct_control.ct` | `dot db.local:8080` / `arith 8081` / `print db.local` | a |

## 三、原始输出

```console
# js_subscript（单层读写）
read tag=2
write {"port":9090}

# js_chain2_read（两级链读）
chain read tag=3 host=db.local

# js_mixed（数字下标 vs get_idx）
arr[0] empty=1 tag=-1
arr[0][name] empty=1 tag=-1
get_idx(0) tag=4
real[name] tag=3

# js_iter_index（下标循环）
arr[0]=a
arr[1]=b
key[0]=tags
key[1]=port

# js_has_str
has(host)=1 has(nope)=0

# js_native_map
len=1 has=1 null=0 got=db.local

# js_struct_control（静态 struct 对照）
dot db.local:8080
arith 8081
print db.local
```

```console
# js_dot
docs/snippets/js_style/js_dot.ct:24:33: error: no member named 'server' in 'struct JsonRef'

# js_chain2_write
docs/snippets/js_style/js_chain2_write.ct:14:18: error: a custom subscript write needs a statement and an lvalue receiver

# js_value
docs/snippets/js_style/js_value.ct:24:43: error: invalid operands to binary expression ('struct JsonRef' and 'int')

# js_iter_native
docs/snippets/js_style/js_iter_native.ct:12:20: error: unexpected token

# js_has_charptr
docs/snippets/js_style/js_has_charptr.ct:25:42: error: passing 'char[5]' to parameter of incompatible type 'struct Str'

# js_native_map_literal（报错落在 std 头里）
docs/snippets/js_style/js_native_map_literal.ct:291:44: error: passing 'char[5]' to parameter of incompatible type 'struct Str'
```

`js_print` 的字节级证据（`printf("%s", doc["host"])` 不报错，但把 `JsonNode *` 当成 `char *`）：

```console
$ /tmp/n_js_print | xxd
00000000: 686f 7374 3d03 0a                        host=..
```

## 四、候选形态

### A. 保持 tagged 句柄，补便捷函数（库层可做）

```ct
JsonRef server = doc["server"];              /* 两级链读可以 */
char *host = json_as_str(server["host"], &len);
doc.set_str(k_port, "9090", 4);
for (i = 0; i < json_arr_len(arr); i++) { JsonRef e = arr.get_idx(i); }
```

- 需要 ct-json 提供：`has_cstr(char *)`、`json_str_of(JsonRef)` 之类的小函数；`set_*` 已有。
- 需要 CT 补：无。
- 代价：仍然要 `as_*` 解包、仍然不能点访问/算术/打印；**没有重载，`has("k")` 只能叫另一个名字**。
- 风险：接口越补越多，离「像 map/vec」越远。这条只适合 0.1.1 的过渡改善。

### B. 直接用 std `Map`/`Vec` 当 JSON（无句柄）

```ct
Map<Str, Str> m = {};
Str *got = m[k];          /* 要 Str 变量，字面量不行 */
```

- 需要 ct-json 提供：不提供，改用 std 容器。
- 需要 CT 补：字面量到 `Str` 的转换或重载（实测 `m["host"]` 在 std 头里就报错）。
- 代价/风险：JSON 是动态的——`Str *` 的 `NULL` 只能表达「缺键」，表达不了 JSON `null` 与类型分叉；嵌套要么用命名 union（回到 tag），要么每种 schema 一个类型；类型不安全且没有点访问。**不推荐**作为主形态。

### C. 静态 schema：为每份 JSON 生成 `struct`

```ct
Doc doc;
doc.server.host = str_from("db.local");
doc.server.port = doc.server.port + 1;      /* 实测可编译可运行 */
printf("%s\n", doc.server.host.data);
```

- 需要 ct-json 提供：JSON → CT struct 的生成器（或 schema 编译器）。
- 需要 CT 补：无，普通 struct 已全部支持（`js_struct_control.ct` 实测）。
- 代价：失去动态性——未知键、异构数组、运行时新增键都不行；生成代码与 schema 版本绑定。
- 风险：这实际上是另一个产品（静态类型化 JSON），不能替代动态 JSON 库。

### D. 目标态：`Vec` / `Map` 获得语言协议（真正的 JS 风格）

要写出 `doc.server.host`、`arr[0].name`、`doc["a"]["b"] = x`、`n + 1`、`print(doc)`、`for (k in doc)`，需要 CT 让 `Vec` / `Map` 补齐 §五 列出的六项能力（不是给 ct-json 加接口）。JSON 包只是这两个容器的组合，届时**不需要新增自有接口层**；`JsonRef` 句柄层降级为兼容层或直接移除，见 §5.1。

| 形态 | 用户写法接近 JS | 需要谁改 | 动态 JSON 适配 | 主要风险 |
| --- | --- | --- | --- | --- |
| A 句柄 + 便捷函数 | 远 | ct-json | 好 | 接口膨胀，仍不像 map/vec |
| B std Map/Vec | 中（下标） | std + CT 转换 | 差（null/类型分叉） | 类型不安全、缺缺失语义 |
| C 静态 schema | 高（点/算术/打印） | 生成器 | 差（固定 schema） | 失去动态性 |
| D 语言协议 | 高 | CT | 好 | 类型不安全需运行期检查；语言改动大 |

## 五、对 `Vec` / `Map` 的要求（原「需要 CT 补的能力」的重述）

口径：ct-json 不定义 CT 缺什么语法；下面每一条都先翻译成「用 `Vec` / `Map` 表达 JSON 时，容器缺的具体能力」。**「能绕」不等于「该由本包修」**：0.1.1 只修可用性与正确性，这些条目一律等 CT。

| # | 写法 | 用 Vec/Map 表达时缺的具体能力 | 现在能否绕 | 绕法（当前唯一可写形式） |
| --- | --- | --- | --- | --- |
| R1 | `doc.server` | `Map` 无属性访问协议：`doc.server` 无法映射为 `doc.get("server")`，只能按下标取 | 能 | `JsonRef server = doc["server"];`（单层下标；两级限制见 R3） |
| R2 | `v[0]` 与 `v["k"]` 并存；`has("k")` 与 `has(Str)` 并存 | `Map` 的 `get`/`has` 按键类型只有一个签名：无同名重载、无按键类型分派；`Vec` 的 `at(int)` 与 `Map` 的 `get(Str)` 无法统一到同一个下标运算符 | 能（分名） | 数组用 `get_idx(i)`，对象用 `v["k"]`；`has` 只收 `Str`，`char *` 键先 `str_from`。C 层探针：`error: conflicting types for 'T_get'` |
| R3 | `doc["a"]["b"]["c"]`、`doc["a"]["b"] = x`、`doc["a"].has(k)` | 容器的下标/方法接收者规则：临时值只能作一次接收者（声明初始化/赋值位置），三级链与参数位置不行；自定义下标写还要求左值接收者 | 能 | 逐级拆局部变量；写用 `JsonRef b = a["b"]; b.set(...)`。报错原文：`a method call on a temporary is only allowed at the start of a statement or of an assignment`、`a custom subscript write needs a statement and an lvalue receiver`、`method receiver must be a variable, an element, a call or a field chain` |
| R4 | `doc["port"] + 1`、`printf("%s", doc["host"])` | 容器元素无隐式取值与运算符参与：`Vec`/`Map` 的 `at`/`get` 返回容器元素类型，不参与算术；无格式化协议 | 能 | 显式解包：`json_as_int` → `long long`，`json_as_str` → `char *` + `len`。报错原文：`invalid operands to binary expression`；`%s` 编译通过但输出 `host=\x03` |
| R5 | `for (JsonRef e in tags)`、`for (Str k in doc)` | `Vec` / `Map` 无可遍历协议：`foreach` 只接收一维 C 数组，容器不暴露迭代器形态 | 能 | 数组按下标循环 `0..json_arr_len`；对象用 `json_obj_key_at(v, i, &len)` 逐键取，再 `json_member` |
| R6 | `doc.has("k")`、`Map<Str,V> m["k"]` | 字面量不转 `Str`：`Map` 的键参数是 `Str`，下标协议把字面量按 `char *` 传入 | 能 | 先 `Str k = str_from("k");` 再传变量；ct-json 仅在 `get`/`set` 两个下标协议入口做 `char *` 适配。报错原文：`passing 'char[5]' to parameter of incompatible type 'struct Str'` |

> R3 已入账 `issues/JSON-1.md`、`JSON-2.md`；R6 的诊断分级已入账 `JSON-3.md`。R1、R2、R4、R5 按上游需求记录，不记作 JSON 库需求。

### 5.1 若 CT 补齐这些能力，JSON 包准备怎么接

本轮**不动实现**，只把接口形状预留写清，避免将来返工：

| CT 能力 | 届时 JSON 包的接法 | 预留的层 |
| --- | --- | --- |
| R1 属性访问协议 | 属性访问直接落在 JSON 对象上，不再经 `JsonRef` 转一道；公开面从 `JsonRef.get/set` 退到容器本身 | 对象存储已是 `Str *keys` + `JsonRef *vals` + `Map<Str,int> *index`（规范 §2.3），索引层可原位替换 |
| R2 按键类型分派（`Vec` 下标 + `Map` 键下标统一） | 去掉 `get_idx`，`v[i]` 由 `Vec` 语义提供；`has` 保持单签名 | 数组已是 `JsonArr{len,cap,items}`，内部可换 `Vec<JsonRef>` 而不改上层 |
| R3 临时值接收者放开 | `v["a"]["b"]["c"]` 与 `v["a"]["b"] = x` 直接成立；包侧只删文档里的拆分说明 | 无需新层：`get`/`set` 已是单参数、`pub` |
| R4 运算符/格式化 | `json_as_*` 保留为显式转换，不引入隐式转换；另加返回值形态的便捷函数 | `JsonRef` 是 8 字节值句柄，已满足「可当值传递」 |
| R5 容器迭代协议 | 删掉 `json_obj_key_at` 的手工循环示例，改为 `for (k in doc)`；`JsonArr` 换可迭代容器 | 对象保序已在 `keys` 数组里，迭代序即插入序 |
| R6 字面量→`Str` | 删除 `get`/`set` 的 `char *` 协议例外，两入口改回 `Str`；其余 API 不变 | 协议入口是唯一的 `char *` 面，收口点单一 |

约束：以上任一项都要求 CT 先改语言/标准库；在此之前 0.1.1 不预埋分支、不加开关，避免为未落地能力写无效代码。

## 六、对版本的影响

- 0.1.0 完工判定不变，J 判据结论不变。
- **0.1.1 只修可用性与正确性**（包能被 `ct get` / `ct install` 消费），不加接口层能力；A 类便捷函数扩张（`has_cstr`、`json_str_of` 等）一并推迟，等 CT 修完相关 bug 再谈。
- B 需要改 std 的 `Map.get`/字面量下标（即 R6）；C 是生成器产品；D 必须等 CT 让 Vec/Map 具备 §五 的六项能力。
- 若负责人目标是「像 map/vec 一样用」，路线应是：先把 R1～R6 作为 Vec/Map 需求提给 CT，包侧保持现有最小接口，不做过渡性接口扩张。

## 七、复现

```sh
# 通过的样例
CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build docs/snippets/js_style/js_subscript.ct -I src -o /tmp/js1 && /tmp/js1
# 失败的样例（保留原文报错）
CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build docs/snippets/js_style/js_dot.ct -I src -o /tmp/js2
```

完整样例清单见 `docs/snippets/js_style/`，每条文件头标了 `(a)` / `(b)` / `(c)` 与对应结论。
