# ct-json 0.1.0 规范提案 · 主张席评估

> **前提已变，结论待重估（2026-11-15）。** 本评审以「零分配视图」为默认前提；用户已裁定数据模型走树（[ADR-0001](../adr/0001-tree-data-model.md)）。文中以视图为前提的结论保留原文，不再作为设计依据。

> 评估对象：`/Users/samxx/.trae-cn/assistant/2026-11-15/ct-json-spec/input/ct-json-spec.md`（下称「提案」，行号均指该文件）。
> 基线：ct-json `3149eee`（`json.ct` 2,286 行 / `json.expected.out` 135 行 = 125 `ok` + 20 errors / 需求 38 条）；
> ct-lang `8691c186`；编译器 `ct v0.44.1`（`~/.local/bin/ct`）；探针目录 `/tmp/ctjson-probe`（仓外，未入库）。
> 边界：本文不改实现、不改 `docs/requirements.md`、不 push。所有判定附实测输出或 `path:line`；给不出证据的写「未验证」。

## 0 结论

**NO-GO：不能作为 0.1.0 的设计基线。** 方向可保留（tagged union + 原生 `Map`/`Vec` + `int tag` 判别 + 不自造 DOM 类），
但提案当前形态有 4 类硬伤，且都不是措辞问题：

1. **类型定义编译不过**：`union { … } v;` 与裸 `Map *obj` / `Vec *arr` 分别被 CT 与 C 拒绝（§2.1，A1/A2）。
2. **生命周期核心假设为假**：跨单元 `Drop` 是空桩，`delete` = 空桩 + `free`；同单元自动 glue 也不递归 `Map`/`Vec`，
   且对指针字段做类型错乱的递归调用（§2.2/§7.1，A3/A4/A5）。J10 不成立。
3. **两个语言层依赖不成立**：L1 未立项且不在 Phase 40；自动转换语法糖在 ct-lang 无任何立项痕迹，且被既有提案明确拒绝（§5/§6/§10，B1/B2）。J5/J6/J11 失效。
4. **公开 API 形态不可实现**：三同名 `json_encode` 冲突；`Vec::get` 返回值不是指针；`#define` 不进生成头；
   树类型无法跨单元导出（§3.2/§3.3，A8/A9/A10/A12）。

另有 3 处自相矛盾（路径 API、字符串所有权、int 精度），见 §5。

## 1 复核环境

```
$ ~/.local/bin/ct --version
ct v0.44.1
$ cd /Users/samxx/trae-ws/ct-lang && cat .git/HEAD     # 8691c186…
```

编译模式：`ct <in.ct> -o <out.c>`（自动预解析 `lib/std/*`，`Vec`/`Map` 无需 import）；
跨单元：`ct build <main.ct> -o <exe> --outdir <dir>`。以下探针全部先过 `ct`，再 `cc -std=c99 -Wall -Wextra`。

## 2 逐条核对提案对 CT 能力的断言

| # | 提案断言 | 判定 | 证据 |
| --- | --- | --- | --- |
| A1 | `union { … } v;` 匿名联合体带字段名（§2.1:30-36） | **不成立** | `ct`：`an anonymous record member cannot have a name; tag the record instead`（规范同款拒绝，`ct-lang/docs/language-spec.md:929-932`） |
| A2 | `Map *obj;` / `Vec *arr;` 裸泛型（§2.1:34-35） | **不成立** | `ct` 原样透传，`cc`：`unknown type name 'Map'` / `unknown type name 'Vec'` |
| A3 | `JsonRef` 16 字节，可放进 `Map<char*,JsonRef>` / `Vec<JsonRef>`（§2.1:25,50） | **成立（但需改写）** | 改写成 `union JsonRefVal` + `struct JsonRef { int tag; union JsonRefVal v; }` 后实测 `sizeof(JsonRef)=16 sizeof(union)=8`，`put/get/push/len` 全部可用 |
| A4 | `struct JsonDoc { … } use Drop;` 的 Drop 递归释放整棵树（§2.2:61、§7.1:201-206） | **不成立** | 跨单元：`delete` 调用的是消费单元里的空桩（见 A5 输出）；同单元：自动 glue 只递归 `use Drop` 字段，`Map`/`Vec` 不参与 |
| A5 | 「`own JsonDoc *doc = json_decode(text);` 块退出自动释放」（§2.2:61、§7.1:196） | **不成立** | ① `own` 只接受 `malloc|calloc` 初始化：`error: 'own' requires a malloc or calloc initialiser`；② 跨单元 Drop 为空桩 |
| A6 | `map trait JsonExtract for type JsonRef*` 寄生可行（§4:124-130、§10:290） | **不成立（原样）；有丑绕法** | `.m.ct` 不能声明类型（`a .m.ct unit cannot declare a type`），也不能 import `.h.ct`（`a .m.ct unit can only import another .m.ct unit`）；宿主键是**规范化文本**比较，消费方静态类型是 `struct types_JsonRef *`，故 `no method 'to_str' for type 'struct types_JsonRef *'`。改写 `pub type JRefP = struct types_JsonRef *;` 后可跑通（输出 `s 1`），但宿主键必须写 mangled 名 |
| A7 | `#define JSON_TAG_*` 作为公开常量（§2.1:39-44） | **不成立** | `.h.ct` 的 `#define` 不进生成头：消费方 `use of undeclared identifier 'JSON_TAG_NUM'`；`pub enum JsonTag { … }` 可进头并可跨单元使用（实测打印 `2`） |
| A8 | `char *json_encode(Map<char*,JsonRef> *)` / `(Vec<JsonRef> *)` / `(JsonRef *)` 三重载（§3.2:84-86） | **不成立** | CT 无函数重载，`cc`：`conflicting types for 'json_encode'`（同一名字第二、三个定义均报） |
| A9 | `JsonRef *item = arr->get(i);`（§13 示例 2:359） | **不成立** | `Vec::get` 返回值拷贝：`pub T get(int i)`（`ct-lang/lib/std/Vec.h.ct:94-99`）；`cc`：`assigning to 'struct JsonRef *' from incompatible type 'struct JsonRef'` |
| A10 | 树类型（`JsonRef`/`JsonDoc`）由包导出、跨单元使用 | **不成立** | 导出单元一旦实例化 `Vec<JsonRef>`/`Map<char*,JsonRef>`，生成头不可编译：`Vec.h:31: field has incomplete type 'struct types_JsonRef'`（`Option`/`Result` 有延迟发射特例，`Vec`/`Map` 无，见 `ct-lang/docs/language-spec.md:2221-2224`） |
| A11 | `Map::get` 未命中返回 NULL、`Vec::len` 存在（§11 J2/J7） | **成立** | `pub V *get(char *k)`（`Vec.h.ct:260-269`）、`pub int len()`（`Vec.h.ct:87-91`）。实测 `missing=0x0`、`vec len=1` |
| A12 | `doc["server"]["host"]` 下标链（§6:174-180） | **不成立** | `ct` 透传，`cc`：`array subscript is not an integer`；且 `Vec`/`Map` 有显式诊断「use get(i)」，用户 struct 指针则直接漏到 `cc`（`language-spec.md:2199-2202`） |
| A13 | `char *host = doc["server"]["host"];` 自动转换（§5:147-157） | **不成立** | 无糖，`cc`：`incompatible pointer types initializing 'char *' with an expression of type 'struct JsonRef *'`（`int` 位置直接 error） |
| A14 | §13 示例是 CT 代码（§13:329-409） | **不成立** | `<send> … [to] user` 在 ct-lang 全仓 grep 无命中（不是 CT 语法）；示例 3 还把 `Map` 值传给指针形参（`:369` vs `:84`） |

### 2.1 关键实测原文

A2（裸泛型）：

```
p1.c:12:9: error: unknown type name 'Map'
   12 |         Map   *obj;
p1.c:13:9: error: unknown type name 'Vec'
   13 |         Vec   *arr;
```

A5（跨单元 Drop 空桩）。`xunit/lib.h.ct` 里 `impl Drop for Doc { void drop() { printf("[lib] …"); } }`，消费单元 `own Doc *d = malloc(...)` 后作用域退出 + `delete`：

```
$ /tmp/ctjson-probe/xunit/out
before scope exit
before delete
after delete
```

`[lib]` 一行都没打。生成物（`.ctbuild/main.c:26-49`）里消费单元自带一个**空桩**，而 `lib.c` 里的真实现是 `static __attribute__((unused))`：

```c
static void __attribute__((unused)) Doc_Drop_drop(void *self) {   /* main.c 的版本 */
    struct Doc *_self = (struct Doc *)self;
    (void)_self;
}
…
if (d) { Doc_Drop_drop(d); free(d); d = 0; }                      /* 只等于 free */
```

A4（同单元 glue）。`JsonDoc { JsonRef root; } use Drop` + `JsonRef use Drop`，生成 `p7.c:485-499`：

```c
static void JsonRef_Drop_drop(void *self) { (void)_self; }            /* 空体，union payload 不释放 */
static void JsonDoc_Drop_drop(void *self) { JsonRef_Drop_drop(&_self->root); }
/* Holder { JsonRef *p; JsonRef v; Map<char*,JsonRef> m; } use Drop */
static void Holder_Drop_drop(void *self) {
    JsonRef_Drop_drop(&_self->p);   /* 传的是 struct JsonRef **，被当成 struct JsonRef * */
    JsonRef_Drop_drop(&_self->v);
    /* m 完全没被访问 */
}
```

即：① 树不会被递归释放；② `Map`/`Vec` 字段不参与释放；③ 指针字段被按值递归，属类型错乱（越界读）。
另有独立证据表明容器元素释放对 `JsonRef` 是空操作：`Map_char_p_JsonRef__elem_release` / `Vec_JsonRef__elem_release` 体为 `(void)e;`。

## 3 两个语言层依赖的真实状态

| 依赖 | 提案声称（:288-289） | 判定 | 证据 |
| --- | --- | --- | --- |
| 自定义 `[]` 下标协议 | 「已立项，Phase 40」 | **无据（且事实相反）** | Phase 40 是 `errdefer + err: 错误出口 + 尾随声明`，已于 v0.40.0 收口（`ct-lang/docs/roadmap.md:56`）；下标协议只有提案，头部明写「**提案 / 未立项 / 未过分析，不作数**」「不认领 phase 编号」（`docs/proposals/custom-index-protocol.md:3-11`）；需求池 `REQ-L1` `status = open`（`docs/planning/requirements-pool.md:9-20`）；`issues/` 无对应条目 |
| 赋值/传参/返回处的自动类型转换语法糖 | 「本提案附带需求，待 CT 项目组评估」 | **无据** | 需求池无该条目；`language-spec.md` 无此语法；`modern-oo-gap.md:186` 的算子清单里也没有；ct-lang 侧唯一相关表述是反向的：「不做隐式转换」（`docs/proposals/ct-pkg-agent-runtime.md:119`）；实测 A13 直接漏到 `cc` |

**额外致命点**：即使 L1 落地，下标链也不成立。协议明确「不做指针接收者：`struct X *p; p[k]` 保持 C 的指针算术」（`custom-index-protocol.md:39`），
而 `doc` 是 `JsonDoc *`、`Map::get` 返回 `JsonRef *`——链上每一跳都是指针接收者，`doc["a"]["b"]` 需要写成 `(*doc)["a"]` 之类，
且下一跳又回到指针。**提案的下标链依赖一个连提案文档自己都排除的形态。**

**没有这两个依赖时失效的验收条目**：J5、J6、J11 全部（§11:305-311），连带 §5 整节、§6.1、§13 示例 1 与示例 5、§14 的「下标访问靠 L1」。
J7 只在 `Map` 上成立——`Vec::get` 越界返回零值，`tag == 0` 与 `JSON_TAG_NULL` 撞值，数组缺项看起来像 `null`（实测 `vec oob tag=0`）。

## 4 可以立刻做 / 必须等 / 应当删

### 4.1 只依赖现成能力，可进 0.1.0

1. `union JsonRefVal { int64 i; double n; char *s; Map<char*,JsonRef> *obj; Vec<JsonRef> *arr; }` + `int tag`（16 字节已验证）。
2. `Map<char*, JsonRef>` / `Vec<JsonRef>` 在**消费单元内**构造与遍历；对象键按插入序（`Vec.h.ct` 语义），重复键原位覆盖。
3. 递归 `json_free(JsonRef *)` 显式释放（不能用 Drop）；键需自己拷贝并释放（`put` 不复制键：`Vec.h.ct:254`）。
4. 单一入口 `json_decode_ex(const char *text, int len, JsonError *err)`；错误保留现有「码 + 字节偏移 + 1-based 行列」。
5. 具名编码入口 `json_encode_map` / `json_encode_vec` / `json_encode_scalar`（不重载）。
6. `JSON_TAG_*` 用 `pub enum`（不用 `#define`）。
7. 访问用 `.get()` / `.len()`，不提供路径 API。
8. 可保留的验收：J1、J2、J3、J4、J7（仅 Map）、J8、J12、J13、J14。

### 4.2 必须等语言层或编译器修复

- J5 / J6 / J11（下标链 + 自动转换）：等 `REQ-L1` 立项，且需要 L1 支持指针接收者，否则链路断在第一跳。
- 树类型跨单元导出（A10）：属 ct-lang 缺陷（`Vec`/`Map` 实例在导出头里先于元素定义发射），需修编译器或把类型定义下沉到消费单元。
- 真 Drop 递归：不需要语言新能力，但需要放弃「自动」改用显式 `json_free`；若坚持 Drop，则必须解决跨单元空桩。

### 4.3 应从这一版删掉

§5 全节、§6 全节、§3.2 的三重载、§3.4 `json_get`（见 §5 矛盾 1）、§2.2 的 `own` 用法、§7.1 的 Drop 叙述、
§10 依赖表、§11 的 J5/J6/J11、§13 全部示例、§14 的末句。保留 §1 的定位、§2.1 的 tag 思路、§4 的寄生动机、§12 的非目标。

## 5 提案内部矛盾（与语言无关，但会直接变成错误契约）

| # | 矛盾 | 位置 |
| --- | --- | --- |
| 1 | 定位写「不做路径查询 API——下标访问是唯一方式」，同一文档又给出 `json_get(doc, "server.host")` 作为兜底 | §1:17 vs §3.4:100-108、§6.2:185、§12.4:323 |
| 2 | `v.s` 被定义为「指向 `JsonDoc` 内部缓冲，不拥有」；`json_str` 又 `strdup` 且「JsonRef 拥有副本」，同一字段两种所有权 | §2.1:51 vs §3.3:95-98、§7.3:224-229 |
| 3 | 值为 `double` 单 tag（`JSON_TAG_NUM`），整数精度掉到 2^53；实测 `9007199254740993` → `9007199254740992`。而现状是 int64 精确（`json.ct:1234-1283`） | §2.1:31,39-44 |
| 4 | 「所有 Map / Vec / char\* 都在 doc 内部」——但 `Map` 条目由 `realloc` 分配、键由调用方指针保存，doc 内部并没有这些字节的归属方案 | §7.1:197-198 vs `Vec.h.ct:240-258` |
| 5 | 错误模型只有 `line/col/message`，丢掉现有「稳定错误码 + 字节偏移」（`json.ct:1624-1653`）；`message` 的 `char *` 生命周期未定义 | §9:259-265 |
| 6 | `json_decode(char *text)` 无长度，无法表达含 `\0` 的值；与提案自己主张的「无损」冲突 | §3.1:74 vs §1:11 |

## 6 与现有 38 条需求的关系

**结论：不是替代，是「口径 B 的完整版 + 大量静默删除」。** 提案只在 Q-01 裁定为「树为唯一公开模型」时才与需求兼容；
在此之前它既推翻 API 载体，又不覆盖一半的既有判据。

| 组 | 条数 | 关系 | 具体 |
| --- | --- | --- | --- |
| A 解码 | 12 | 语义保留、载体取消 + 5 条失效 | A-01～A-07（空输入/尾随/深度/转义/数字词法/重复键/访问器错误）语义仍需要，但判据全部挂在被删掉的视图 API 上，必须重写到 `json_decode_ex`；A-08（UTF-8 开关）、A-09（实数精度）、A-10（深度硬上限）、A-11（大数组查找）、A-12（BOM）提案一字未提 → **失效**，其中 A-09 反而被「只有 double」再降一级 |
| B 编码 | 7 | 5 推翻 / 2 成立 | B-01～B-05 依赖 `JsonOut` 追写器，提案没有该 API → 推翻（截断不报错的问题随之回来）；B-06（原生 `Map`/`Vec` 直接编码）、B-07（能出就能读）成立，是提案唯一的实质增量 |
| C 错误 | 5 | 3 推翻 / 1 保留 / 1 强化 | C-01（码+偏移+行列）被 §9 的 `line/col/message` 推翻；C-02（访问器错误五值）被 `to_*` 返回默认值推翻；C-03（码表冻结）随之作废；C-04（严格 RFC）保留进 decode；C-05（失败清理）成立且更硬——因为 `JsonRef` 的元素 `release` 是空操作，必须手写递归 free |
| D 数据模型 | 8 | 核心成立，3 条被推翻 | D-01 成立；D-02 成立但需 tagged union、7 类 tag（提案 6 类且无 int）；D-03 不成立（Drop 空桩、无 `json_free`、所有权两说）；D-04 由提案单方面选中口径 B；D-05 被推翻（无 int64 落点）；D-06 部分（`char*` 无长度，NUL 丢失）；D-07 成立（`get` 返回 NULL）；D-08 部分（原位覆盖成立，旧值因 `elem_release` 空操作而泄漏） |
| E 工程 | 6 | 1 成立 / 5 静默缺失 | E-01（可 import）方向成立；E-02 需重写（`#define` 不进头，提案正好踩了 R-E-02 已经警告过的那条）；E-03 许可、E-04 `requires` 下限、E-05 每条判据可执行、E-06 README 一致性全部未提 |

### 6.1 最硬的冲突：Q-01 / R-D-04

- 现状决策：**视图唯一、零分配**（`DECISIONS.md:14-23`，`README.md:91-110`「No mutation, no DOM」）；`requirements.md:207` 把 Q-01 记为「待确认」，`X-01` 仍未裁。
- 提案等于选了**口径 B**（树为唯一公开模型，视图降为内部），并把「两种模型并存、都能无损编码」的 R-01 §1:28 直接改成「只有两个入口」（§14:415）。

**谁让谁（主张席裁定）**：
1. 「decode 落成原生 `Map`/`Vec`」是用户给的职责定位，`requirements.md:6` 已把它列为口径优先级第一；`DECISIONS.md` 是**在不含这条需求的前提下的取舍记录**。前提变了，记录必须让路。
2. 但「不做可变 DOM」（`DECISIONS.md:69-75`）**并不**禁止原生容器树——`requirements.md:173` 已把它解释为「不另包一层 DOM 类」。所以真正的正面冲突不是「DOM」，而是**DECISIONS §1「零分配视图唯一」 vs 提案「树唯一」**。这一条只能由 Q-01 裁定，提案不能自行覆盖。
3. 因此：先裁 Q-01 = 口径 B，并在同一决策提交里改写 `DECISIONS.md:14-23`/`69-75` 与 `README.md` 的限制段；裁不下就退回口径 A，提案收缩为「视图之上的树构造层」，且不得删除 125 条 golden。

## 7 复现清单（全部只读，产物在 `/tmp/ctjson-probe`）

| 项 | 命令 | 结果 |
| --- | --- | --- |
| A2 裸泛型 | `ct p1_bare_generic_union.ct -o p1.c && cc -std=c99 p1.c` | `unknown type name 'Map' / 'Vec'` |
| A1 匿名 union 具名 | `ct p2b_selfref.ct -o p2b.c` | `an anonymous record member cannot have a name` |
| A3 16 字节 | `ct p3_tagged_union.ct -o p3.c && cc … && ./p3` | `sizeof(JsonRef)=16` |
| A5 own | `ct p4_own_call.ct -o p4.c` | `'own' requires a malloc or calloc initialiser` |
| A12 下标 | `ct p5_subscript.ct -o p5.c && cc …` | `array subscript is not an integer` |
| A13 自动转换 | `ct p6_autoconv.ct -o p6.c && cc …` | `incompatible pointer types … 'char *'` |
| A4 glue | `ct p7_drop_glue.ct -o p7.c && grep -A3 _Drop_drop p7.c` | 空体 / `&_self->p` |
| A9 `Vec::get` | `ct p9_vec_get_ptr.ct -o p9.c && cc …` | `assigning to 'struct JsonRef *' from incompatible type 'struct JsonRef'` |
| A8 重载 | `ct p10_overload.ct -o p10.c && cc …` | `conflicting types for 'json_encode'` |
| 跨单元 Drop | `ct build xunit/main.ct -o xunit/out && ./xunit/out` | 无 `[lib]` 输出 |
| 寄生 m.ct | `ct build mpkg/main.ct`、`pkg3`、`pkg4`、`pkg` | `a .m.ct unit cannot declare a type` / `can only import another .m.ct` / `no method 'to_str'` / 别名改写后 `s 1` |
| `#define` 进头 | `ct build --outdir pkg2/c pkg2/main.ct` | `use of undeclared identifier 'JSON_TAG_NUM'`；`pkg3` 的 `pub enum` 可用 |
| 跨单元导出树 | `ct build --outdir pkg6/c pkg6/main.ct` | `Vec.h:31: field has incomplete type 'struct types_JsonRef'` |
| Map 字面量 + defer | `ct p11_map_init.ct -o p11.c && cc … && ./p11` | `len=2 name=rill`（这条成立） |

## 8 未验证项

- `json_encode` 的实际输出语义（提案无实现，本轮不写实现）。
- OOM / 部分树回滚（需注入分配失败，未做）。
- J9「不 double-free」、J10「free 计数归零」的运行时断言（Drop 已验证为空桩，计数断言无意义）。
- ASan/LSan 下的递归释放（显式 `json_free` 尚未存在）。
- 跨单元导出修复后 `A10` 是否自动成立（未修，不推测）。
