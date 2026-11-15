# ct-json「JS 风格」使用形态评估

> 范围：**只评估，不改实现、不改现有 API、不改既有规范**。
> 基线：CT `v0.53.0`，ct-json 0.1.0 当前公开面（`JsonRef` 为 tagged 句柄）。
> 样例：`docs/snippets/js_style/`，每条都是真跑出来的；失败样例保留原始报错，未改写成语义不同的替代写法。

## 一、结论

1. 今天能用的只有：单层 `doc["k"]` 读写、两级链**读**（声明初始化/赋值右值）、`get_idx(i)`、`has(Str)`、`json_obj_key_at`、`json_encode`。
2. `doc.server.host`、`doc["a"]["b"] = x`、`doc["port"] + 1`、`printf("%s", doc["host"])`、`for (e in arr)`、`doc.has("k")` 六类写法目前**都写不出来**。
3. **瓶颈在 CT 语言能力，不在 ct-json 的接口设计**。库层能补的只是几个便捷函数，天花板很低；点访问、链式写、值语义、迭代协议这四类，换任何库设计都做不出来。
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

### D. 目标态：语言协议（真正的 JS 风格）

要写出 `doc.server.host`、`arr[0].name`、`doc["a"]["b"] = x`、`n + 1`、`print(doc)`、`for (k in doc)`，需要 CT 补齐 §五 的六项。ct-json 的接口已经按这个方向留了口（`get`/`set` 单参数、`pub`、`JsonRef` 值句柄），**剩下的不在库能改的范围**。

| 形态 | 用户写法接近 JS | 需要谁改 | 动态 JSON 适配 | 主要风险 |
| --- | --- | --- | --- | --- |
| A 句柄 + 便捷函数 | 远 | ct-json | 好 | 接口膨胀，仍不像 map/vec |
| B std Map/Vec | 中（下标） | std + CT 转换 | 差（null/类型分叉） | 类型不安全、缺缺失语义 |
| C 静态 schema | 高（点/算术/打印） | 生成器 | 差（固定 schema） | 失去动态性 |
| D 语言协议 | 高 | CT | 好 | 类型不安全需运行期检查；语言改动大 |

## 五、需要 CT 补的能力（可直接作为上游需求）

| # | 缺什么 | 哪段样例因此写不出来 | 现状原文 |
| --- | --- | --- | --- |
| R1 | 用户类型属性访问协议（`doc.server` 能映射到库的 `get("server")`） | `js_dot.ct`、`arr[0].name` | `error: no member named 'server' in 'struct JsonRef'` |
| R2 | 同名方法重载，或下标按键类型分派（`get(char*)` 与 `get(int)` 并存） | `v[0]` 与 `v["k"]` 无法同时成立；`has("k")` 与 `has(Str)` 只能二选一 | 探针：`error: conflicting types for 'T_get'`（C 层） |
| R3 | 临时值接收者放开（三级链、链式写、结果调方法） | `doc["a"]["b"]["c"]`、`doc["a"]["b"] = x`、`doc["a"].has(k)` | `a method call on a temporary ...` / `a custom subscript write needs a statement and an lvalue receiver` / `method receiver must be ...`（详见 JSON-1、JSON-2） |
| R4 | 结果当值：运算符重载/隐式取值，以及格式化协议 | `doc["port"] + 1`、`printf("%s", doc["host"])` | `invalid operands to binary expression`；`%s` 编译通过但输出 `host=\x03` |
| R5 | 容器迭代协议（`foreach` 目前只收一维 C 数组） | `for (JsonRef e in tags)`、`for (Str k in doc)` | `error: unexpected token` |
| R6 | 字符串字面量到 `Str` 的隐式转换（或键参数的专用重载） | `doc.has("k")`、`Map<Str,V> m["k"]` | `error: passing 'char[5]' to parameter of incompatible type 'struct Str'` |

> R3 已入账 `issues/JSON-1.md`、`JSON-2.md`；R6 的诊断分级已入账 `JSON-3.md`。R1、R2、R4、R5 是本轮新发现，按「评估不改实现、不新开本包 issue」的边界，先按上游需求列在这里，是否入账由负责人定。

## 六、对版本的影响

- 0.1.0 完工判定不变，J 判据结论不变。
- 0.1.1 能做的只有 A 类便捷函数（`has_cstr`、`json_str_of` 等），**不能把形态变成 JS 风格**。
- B 需要改 std 的 `Mapget`/字面量下标；C 是生成器产品；D 必须等语言。
- 若负责人目标是「像 map/vec 一样用」，路线应是：先把 R1～R6 提给 CT，同期 0.1.1 只做 A 类过渡，不做 B 类（会把缺失/类型语义做坏）。

## 七、复现

```sh
# 通过的样例
CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build docs/snippets/js_style/js_subscript.ct -I src -o /tmp/js1 && /tmp/js1
# 失败的样例（保留原文报错）
CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build docs/snippets/js_style/js_dot.ct -I src -o /tmp/js2
```

完整样例清单见 `docs/snippets/js_style/`，每条文件头标了 `(a)` / `(b)` / `(c)` 与对应结论。
