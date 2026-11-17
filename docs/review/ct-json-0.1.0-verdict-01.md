# ct-json 0.1.0 规范提案 · 合论（供外部评估）

> 评估对象：`/Users/samxx/.trae-cn/assistant/2026-11-15/ct-json-spec/input/ct-json-spec.md`（下称「提案」，行号均指该文件）。
> 合论来源：
> - 主张席 `docs/review/ct-json-0.1.0-advocate.md`（本地提交 `94952e9`，基线 ct-json `3149eee`、ct-lang `8691c186`、探针 `/tmp/ctjson-probe`）；
> - 反证席 `docs/review/ct-json-0.1.0-rebuttal.md`（本地提交 `030d77f`，基线 ct-json `94952e9`、ct-lang `5a75b90a`、探针 `/tmp/ctprobe`）。
> 共同基线：`ct v0.44.1`（`~/.local/bin/ct`）；仓库现状 `json.ct` 2,286 行、`json.expected.out` 135 行 = 125 `ok` + 20 errors。
> 仓库基线核对（**非探针**，仅统计，不改变任何结论）：`wc -l json.ct json.expected.out` → `2286` / `135`；`grep -c '^ok ' json.expected.out` → `125`；尾行 `all checks passed`。
>
> 合论规则：
> 1. **不写新判断**，只做归并、去重、排序与结构化；每条结论在「来源」列标注：`一致` / `主张席` / `反证席` / `反证席修正主张席` / `反证席新增`。
> 2. 原始报错**逐字保留**，不改写成概述；命令与探针坐标一并给出，可自行重跑。
> 3. 两席结论冲突处**并列呈现**，见 §3，不抹平、不代裁。
> 4. 本文件不改实现、不改 `docs/requirements.md`、不改 `DECISIONS.md`、不 push。
> 5. **本轮未新增任何探针**（补充探针条数 = 0）；§3 的收敛只依赖两席已有输出、探针源码与留存的构建日志，唯一的额外动作是只读执行了一次既有产物（`pkg/out`，未重建），理由与范围写在 §3 末。

---

## 1 判定与一句话理由

**判定：NO-GO。两席独立复核、结论一致：不能把这份提案作为 0.1.0 的设计基线。**

一句话理由：方向可留、形态不可用——「tagged union + 原生 `Map`/`Vec` + `int tag` 判别 + 不自造 DOM 类」这条路线成立，
但提案把 CT 0.44.1 的真实能力写错多处（匿名 union、裸泛型、`own`、Drop、`#define` 导出），
把两个**不存在**的语言依赖（L1 下标、自动类型转换）当成「已立项 / 待评估」，把生命周期押在一个实测为**空桩**的 Drop 上，
并且公开 API 形态在 C 层直接冲突；按原文既编译不过，也无法写出可验收的判据。

两席的差异只在**分级口径与少数条目标签**，不在结论：

| 席 | 分级体系 | 结论 |
| --- | --- | --- |
| 主张席 | 4 类硬伤（类型定义 / 生命周期 / 语言依赖 / API 形态）+ 3 处自相矛盾（其 §5 实列 6 条） | NO-GO |
| 反证席 | P0 确有问题 10 / P1 说得不够清晰 11 / P2 只需补例子 5 | NO-GO |

---

## 2 硬伤分级表

**分级定义**（合论统一口径，由两席分级映射而来）：
- **阻断**：按提案原文无法产出可编译、可验收的实现，必须改设计或改条款；
- **严重**：可以编译，但契约相对现状全面回退、或范围越权，开工前必须定口径；
- **需澄清**：不改设计，但契约有歧义、实现者必须自己猜。

探针命令统一在 `/tmp/ctprobe`（反证席）下执行，二进制为 `/tmp/ctprobe/bin/ct`（同 `~/.local/bin/ct`，`lib/std` 已软链，见 §8 环境前置）；标注 `[主张席]` 的条目来自 `/tmp/ctjson-probe`。

### 2.1 阻断（11 条）

| 编号 | 症状（一句话） | 提案条款 | 实测证据（命令 → 原始输出） | 严重度 | 来源 |
| --- | --- | --- | --- | --- | --- |
| H-01 | 匿名 `union` 带字段名被 CT 硬拒，`JsonRef` 的类型定义就编译不过 | §2.1:28-37 | `./bin/ct r1_anon.ct -o r1.c` → `r1_anon.ct:8:7: error: an anonymous record member cannot have a name; tag the record instead`，`rc=1`；规范同款拒绝 `ct-lang/docs/language-spec.md:930-931` | 阻断 | 一致 |
| H-02 | 裸 `Map *` / `Vec *` 缺类型实参；主张席环境下 CT 放行、`cc` 才报错 | §2.1:34-35 | `./bin/ct r2_bare.ct -o r2.c` → `r2_bare.ct:2:49: error: generic struct 'Map' needs type arguments in a type position`，`rc=1`；`[主张席]` 同条为 `p1.c:12:9: error: unknown type name 'Map'` / `p1.c:13:9: error: unknown type name 'Vec'` | 阻断 | 一致（证据点由反证席修正，见 §3 D-2） |
| H-03 | 树类型无法跨单元导出：带泛型字段的 `struct` 不能进 `.h.ct` | §2.2:56-59、§10:290-293 | `cd c3 && ./bin/ct build main.ct -o app` → `./H.h.ct:1:1: error: expected a field name`（CT 退出码仍为 `rc=0`）；`[主张席]` 另一失败点 `Vec.h:31: field has incomplete type 'struct types_JsonRef'` | 阻断 | 一致（失败点不同，见 §3 D-4） |
| H-04 | `own` 不能接工厂返回值；`own` 写进返回类型生成非法 C | §2.2:61、§3.1:74-76 | `./bin/ct p1b_own.ct -o p1b.c` → `p1b_own.ct:30:1: error: 'own' requires a malloc or calloc initialiser`、`ctc: 1 error(s) generated`，`rc=1`；`./bin/ct p12.ct -o p12.c && cc p12.c` → `p12.c:49:8: error: unknown type name 'own'`（`49 \| static own struct JsonDoc * json_decode(char *);`）、`p12.c:176:8: error: unknown type name 'own'` | 阻断 | 一致（反证席补第 2 条证据） |
| H-05 | Drop 不递归：同单元胶水空体、跨单元是空桩、容器元素 release 也是空体，`delete` 实际只等于 `free` | §2.2:61、§7.1:196-206 | `cd dropkg && ./bin/ct build src/main.ct -o app && ./app` → 只输出 `done`、`run-rc=0`，`[lib]` 一行未打；`grep -A3 JsonDoc_Drop_drop p6b.c` → `(void)_self;`；`Map_char_p_JsonRef__elem_release` 体为 `(void)e;` | 阻断 | 一致 |
| H-06 | 三个同名 `json_encode` 在 C 层冲突，CT 不做同名签名检查 | §3.2:84-86 | `./bin/ct p2b.ct -o p2b.c && cc -c p2b.c` → `p2b.c:570:8: error: conflicting types for 'json_encode'`、`p2b.c:448:8: note: previous declaration is here`、`p2b.c:573:8: error: conflicting types for 'json_encode'`、`p2b.c:448:8: note: previous declaration is here` | 阻断 | 一致 |
| H-07 | `Vec::get` 返回值拷贝不是指针，示例 2 与 J12 的写法都不成立 | §13 示例 2:359、J12 | `./bin/ct p16.ct -o p16.c && cc p16.c` → `p16.c:347:26: error: initializing 'struct JsonRef *' with an expression of incompatible type 'struct JsonRef'`；`Vec.h.ct:94-99`：`pub T get(int i)` | 阻断 | 一致 |
| H-08 | 字段链接收者不成立，`doc->root.v.obj->get(...)` 这类写法直接报错 | §3.1:71、J1/J2 断言形态 | `./bin/ct p14.ct -o p14.c` → `p14.ct:32:1: error: cannot resolve the method trait (unknown receiver type)`；`p21.ct:22` 复现同一形态 | 阻断 | 反证席新增（主张席 J 表未单列） |
| H-09 | `#define` 不进生成头，`JSON_TAG_*` 作为公开常量不可用 | §2.1:39-44 | `cd c1 && ./bin/ct build main.ct -o app` → `main.ct:6:20: error: use of undeclared identifier 'JSON_TAG_NUM'`；替代写法 `pub enum` 同目录 `app2` 输出 `2` | 阻断 | 一致（两席均实测 `pub enum` 可用） |
| H-10 | 下标链不成立：L1 未立项、不在 Phase 40，且 L1 明确排除指针接收者 | §6:174-180、§10:288、J5/J6/J11 | `./bin/ct p8.ct -o p8.c && cc p8.c` → `p8.c:161:29: error: array subscript is not an integer`（`161 \|     struct JsonRef * h = doc["host"];`）；文档：`roadmap.md:56` Phase 40 = `errdefer + err: + 尾随声明`，`custom-index-protocol.md:3-11`「提案 / 未立项 / 未过分析，不作数」，`:39`「不做指针接收者」，`requirements-pool.md:9-20` `REQ-L1` `status = open` | 阻断 | 一致 |
| H-11 | 自动类型转换语法糖不存在，只产生 warning 并把结构体地址当字符串 | §5:145-157、§10:289 | `cd pkg && ./bin/ct build src/main2.ct -o app3` → `src/main2.ct:11:12: warning: incompatible pointer types initializing 'char *' with an expression of type 'struct jsonext_JsonRef *'`；`./app3` 输出为一个控制字节 | 阻断 | 一致 |

### 2.2 严重（6 条）

| 编号 | 症状（一句话） | 提案条款 | 实测证据（命令 → 原始输出） | 严重度 | 来源 |
| --- | --- | --- | --- | --- | --- |
| H-12 | 所有权没有闭合：三个释放函数名、`strdup` 指针被两个槽位共享、键不复制且 §7.1 不释放键、输入文本是否复制未写 | §3.3:95-98、§7.1:203-206、§7.3:224-229、§12.5:324 | `./bin/ct p20.ct -o p20.c && cc p20.c -o p20 && ./p20` → `same_ptr=1`；`Map::put` 按值拷贝 `JsonRef` 且不复制键（`Vec.h.ct:253-255`、`:254`），`Map::release` 只释放值（`Vec.h.ct:517-537`） | 严重 | 一致（主张席记作「自相矛盾 2/4」，反证席记作 P0-5） |
| H-13 | 数值契约回退：全 `double` 单 tag，整数精度掉到 2^53，`to_int` 越界是 UB，`1e400` 得 `inf` | §2.1:31,39-44、§4:135（`(int)v.n`） | `./bin/ct p9.ct -o p9.c && cc p9.c -o p9 && ./p9` → `d=9007199254740992`（输入 `9007199254740993.0`）、`big=inf`（输入 `1e400`）、`neg=-0`、`int_cast=207049388`（`(int)1e10`）、`int_cast2=1073741824`（`(int)4294967296.0`）；违反 `docs/requirements.md:138`（R-D-02 要求 7 类 tag）与 `:141`（R-D-05） | 严重 | 一致（主张席记作矛盾 3） |
| H-14 | 文本契约回退：`char *` 无法保留 `\u0000`，键按 `strcmp` 截断碰撞，UTF-8/BOM 一字未提 | §2.1:33、§3.3:95 | `./bin/ct p10.ct -o p10.c && cc p10.c -o p10 && ./p10` → `len=1`、`k1=2 k2=2`（`"a\0b"` 与 `"a\0c"` 撞成同一个键）；`Map<char*,V>` 键比较用 `strcmp`（`Vec.h.ct:41-46`、`:232-239`）；`json.ct:711` 以 `'\0'` 为终止符 | 严重 | 一致（主张席只点到 int 精度，未展开文本，见 §3 D-5） |
| H-15 | 错误模型回退：丢掉稳定错误码与字节偏移，`message` 所有权未定义，失败示例不 return 继续用 `doc` | §3.1:78、§9:250-265 | 条款对比：现状为「码 + 字节偏移 + 1-based 行列」（`json.ct:1624-1653`），提案只有 `line/col/message`；示例 `if (doc == NULL) { <send> … }` 后无 `return`/`else` | 严重 | 一致（主张席记作矛盾 5） |
| H-16 | 与 125+20 条 golden、38 条需求的关系未交代，且单方面删视图入口属越权 | §14:415、§3.1、§3.4 | `docs/requirements.md:154`（R-E-05 要求保留 125 `ok` + 20 errors）、`:207`（Q-01 待确认）、`DECISIONS.md:14-23`、`README.md:91-110`；提案未给迁移/替换清单 | 严重 | 一致（主张席 §6.1，反证席 P0-10） |
| H-17 | §13 示例多数是 RILL 语法，不是 CT，四个示例不可运行 | §13:329-409 | `./bin/ct p11.ct -o p11.c` → `p11.ct:6:5: error: expected an expression`；`<send> … [to] user` 在 ct-lang 全仓无命中，RILL 侧同款见 `rill-dsl/testdata/0.1.0/positive/quotes/escapes/source.rill:1` | 严重 | 一致 |

### 2.3 需澄清（9 条）

| 编号 | 症状（一句话） | 提案条款 | 实测证据 / 文档依据 | 严重度 | 来源 |
| --- | --- | --- | --- | --- | --- |
| H-18 | 路径 API 自相矛盾：定位写「不做路径查询」，同文又给 `json_get(doc, "server.host")`；路径文法一字未写 | §1:17 vs §3.4:100-108、§6.2:185、§12.4:323 | 条款互斥；缺路径转义、空串、末位 `.`、`a[0][1]`、负下标、键含 `.`/`[` 的规则，缺「非法路径返回 NULL 还是 MISSING」 | 需澄清 | 主张席矛盾 1 / 反证席 P1-1 |
| H-19 | 入口签名与长度语义未定：`json_decode(char *text)` 无 len，`json_decode_ex` 的 len 含不含结尾 NUL、负数怎么办 | §3.1:74-75 | 提案自身主张「无损」（§1:11）与无长度入口冲突；ct-sse 的 `data` 是长度前缀且可含 NUL（`ct-sse/docs/requirements.md:50`） | 需澄清 | 主张席矛盾 6 / 反证席 P1-8 |
| H-20 | `map trait` 的落地约束一字未给：必须 `.m.ct`、消费方必须 import、recipe 必须单调用且写 mangled C 名 | §4:124-129、§10:290 | `a map recipe must be a single call`；写成裸名 `json_ref_to_str(v)` → `call to undeclared function`；`bindings-and-patterns.md:725-726` 明确只允许 `.m.ct` | 需澄清 | 反证席 P1-9 / 主张席 A6 残余 |
| H-21 | encode 契约几乎空白：键序、数字格式、`NaN`/`Inf`、`json_str(NULL)`、OOM、循环引用、缓冲不足 | §3.2:82-87 | 现状有 `JSON_EMIT_FINITE`、`%.17g`、截断静默（`json.ct:817-831`、`852-866`）；提案无一条对应条款 | 需澄清 | 反证席 P1-5 |
| H-22 | decode 契约空白：重复键、深度上限、行列计法、并发/可重入 | §3.1、§11 | 现状 last-wins（`json.ct:1019-1021`）、默认 64 层（`json.ct:2249-2250`）、列按字节（`README.md:98-99`）；提案均无 | 需澄清 | 反证席 P1-4/P1-6/P1-7/P1-10 |
| H-23 | borrow 失效契约与容器契约冲突；`json_ref_clone` 只出现一次，无签名无释放规则 | §7.2:211-220 | `Map::get` 返回的指针「在下一次 `put`/`remove`/`clear` 前有效」（`Vec.h.ct:397-408`），与「生命周期到 delete doc」不一致 | 需澄清 | 反证席 P1-2/P1-3 |
| H-24 | 措辞与公开面计数不一致：「JsonRef 是纯 union」但定义是 `struct { int tag; union … }`；「只有两个入口」与构造器、`to_*`、`json_get`、释放函数并存 | 首行 vs §2.1:28、§14:415 vs §3.3/§3.4/§4 | 条款互斥 | 需澄清 | 反证席 P1-11 |
| H-25 | 示例层面的次级缺口：缺 include、示例 3 传值给指针形参、空 map `release()` abort、J8 未取地址、示例 5 用虚构函数 | §13 示例 3:369-370、J8 | 不改即 `passing 'struct Map…' to parameter of incompatible type '… *'`；`Vec.h.ct:189-195` 对零 handle abort | 需澄清 | 反证席 P2-1～P2-5 |
| H-26 | 验收覆盖缺口：空容器、重复键、数值边界、字符串边界、深度、错误逐条、encode 契约、入口边界、并发、所有权十组用例未列 | §11 | 反证席 §6 列了 10 组「一个都不能省」的缺失用例；J9/J10 不是可观察断言 | 需澄清 | 反证席 §5/§6 |

**计数：阻断 11 / 严重 6 / 需澄清 9，合计 26 条。**

---

## 3 两席分歧与相互修正

两席在「是否 NO-GO」上一致，但在 4 处判据/标签上不一致。本节按「谁判了什么、谁纠正了谁」排列，原话保留。

### D-1 `map trait JsonExtract for type JsonRef*`：主张席判死，反证席实测可用但条件苛刻

**主张席原话**（`ct-json-0.1.0-advocate.md:42`，A6 行）：

> `map trait JsonExtract for type JsonRef*` 寄生可行（§4:124-130、§10:290） | **不成立（原样）；有丑绕法** | `.m.ct` 不能声明类型（`a .m.ct unit cannot declare a type`），也不能 import `.h.ct`（`a .m.ct unit can only import another .m.ct unit`）；宿主键是**规范化文本**比较，消费方静态类型是 `struct types_JsonRef *`，故 `no method 'to_str' for type 'struct types_JsonRef *'`。改写 `pub type JRefP = struct types_JsonRef *;` 后可跑通（输出 `s 1`），但宿主键必须写 mangled 名

**反证席原话**（`ct-json-0.1.0-rebuttal.md:480`）：

> 我实测到一个更窄但可行的形态：命名空间 `.m.ct` + `map trait JsonExtract for type JsonRef *` + recipe 写 mangled 名，消费方 `import` 两个单元后 `.to_str()` / `.to_int()` 可用（`/tmp/ctprobe/pkg/app4`：`to_str=0x0 to_int=8080`）。所以应改为「**可行，但提案必须写死三件事**：`.m.ct`、import、mangled recipe 名」，而不是「不成立」

**谁纠正了谁**：反证席明确纠正了主张席的**判定标签**（`不成立` → `可行但有三条硬条件`）。主张席的**事实**没有被推翻——它只是另一种包布局。

**三处探针的实际形态**（合论读源码与构建日志所得，不是新实测）：

| 席 | 类型声明位置 | 映射单元 | 结果 |
| --- | --- | --- | --- |
| 主张席 `mpkg` | `JRef` 与 `map trait` 同在 `mpkg.m.ct` | 同文件 | `a .m.ct unit cannot declare a type` |
| 主张席 `pkg`（加别名前） | `types/types.h.ct` | `ext/ext.m.ct`，`for type JsonRef*` | `/tmp/ctjson-probe/pkg/main.ct:14:1: error: no method 'to_str' for type 'struct types_JsonRef *'`（`pkg/build.log`） |
| 主张席 `pkg`（加别名后） | `types/types.h.ct` | `ext/ext.m.ct` + `pub type JRefP = struct types_JsonRef *;` + shim | 通过（`pkg/out` 输出 `s 1`，`rc=0`） |
| 反证席 `pkg` | `jsonext/Json.h.ct` | `jsonext/JsonOps.m.ct`（同命名空间） | 通过（`to_str=0x0 to_int=8080`） |

> 注意：主张席目录里另有一个 `mpkg4/build.log`，内容是 `ctc: namespace 'types' does not match the directory ''`，那是目录/命名空间不匹配的脚手架错误，**不是**本条的证据；本条只采用 `mpkg`、`pkg` 与反证席 `pkg` 三处。

**合论呈现（不代裁）**：两席描述的是**同一能力的多种布局**，事实不冲突，标签冲突。
- 若按提案 §4 原文（trait 与 `map trait` 同块、recipe 写裸名 `json_ref_to_str(v)`、不交代 `.m.ct`/import）→ 主张席的「不成立」成立；
- 若按反证席配方（类型在 `.h.ct`、映射单元同命名空间且被 import、recipe 写 mangled 名）→ 可用；
- 若类型与映射单元跨命名空间 → 主张席的别名条件成立。
因此这条既不是「不成立」，也不是「已支持」，而是「**可行，但需三条硬条件 + 跨命名空间需别名**」；本合论按「需澄清」收录为 H-20。**残余未收敛点**：提案是否接受把类型定义与映射单元拆开——这是设计选择，留给 §7 的 Q-G。

### D-2 A2 裸泛型：证据点被修正，结论不变

**主张席原话**（advocate:38）：

> `ct` 原样透传，`cc`：`unknown type name 'Map'` / `unknown type name 'Vec'`

**反证席原话**（rebuttal:479）：

> 在 `lib/std` 可发现的环境下，`ct` 自己就会报 `generic struct 'Map' needs type arguments in a type position`（`r2_bare.ct:2:49`）。结论不变，但证据应换成 CT 层错误，避免把「环境缺 std」当成语言放行。

**谁纠正了谁**：反证席纠正主张席的证据，不纠正结论。反证席同时给出环境差异的根因（`ct` 单文件模式找不到 `lib/std` 时把泛型声明当比较表达式，报误导性的 `t3.ct:5:8: error: use of an undeclared variable`，见 §8 环境前置）。

### D-3 J1/J2/J8「可保留」：主张席判可留，反证席判按原文不可执行

**主张席原话**（advocate:124）：

> 8. 可保留的验收：J1、J2、J3、J4、J7（仅 Map）、J8、J12、J13、J14。

**反证席原话**（rebuttal:443）：

> 与主张席的差异：对方把 J1/J2/J8 列为「可保留」，但**按原文写法**这三条都过不了 CT/CC 两段编译（J1/J2 是字段链接收者，J8 是重载冲突）；J1/J2 在落局部变量后才可以保留。

**谁纠正了谁**：反证席纠正主张席。§4 的 J 表按「原文写法」判，同时标注「改写后可保留」，两边都留痕。

### D-4 A10 导出树类型：失败点不同，结论相同

**主张席原话**（advocate:46）：

> 导出单元一旦实例化 `Vec<JsonRef>`/`Map<char*,JsonRef>`，生成头不可编译：`Vec.h:31: field has incomplete type 'struct types_JsonRef'`

**反证席原话**（rebuttal:482）：

> 我复现了「带泛型字段的结构无法出现在 `.h.ct`」：`pub struct Holder { Vec<int> *v; }` 直接报 `expected a field name`（`/tmp/ctprobe/c3`）。这与主张席的「生成头 incomplete type」是不同失败点，但结论相同：导出面不可用。

**判定**：不是分歧，是两段流水线的两个失败点（CT 解析阶段 vs C 编译阶段）。合论两条都保留。

### D-5 覆盖范围差异（非矛盾，但影响完整性）

- 主张席做了**提案内部矛盾**清单（6 条：路径 API、字符串所有权、int 精度、Map 内存归属、错误模型、无长度入口），反证席做了**契约回退**清单（数值/文本/错误三组）与**缺失用例**清单（10 组）。两套清单有交集但不等价，§2 已合并去重。
- 主张席未展开文本契约（NUL / UTF-8 / BOM），反证席未把「Map 条目由 `realloc` 分配、doc 内部并无这些字节」单列为矛盾；合论分别归入 H-14 与 H-12。
- 两席基线 sha 与探针目录不同（`3149eee`/`/tmp/ctjson-probe` vs `94952e9`/`/tmp/ctprobe`），ct-lang HEAD 亦不同（`8691c186` vs `5a75b90a`）。本合论引用的文档坐标以章节号为准；探针命令以附录标注的目录为准。

### 为什么本轮补充实测 = 0

D-1 的冲突是**标签冲突**，不是事实冲突：两份探针源码与构建产物都还在（`/tmp/ctjson-probe/{mpkg,pkg}`、`/tmp/ctprobe/pkg`），三种布局的成败可由源码与构建日志直接读出，两席的命令与输出也已逐字给出。
合论只做了一次**坐标校正**（不编译、不重跑探针）：主张席 A6 的「别名改写后输出 `s 1`」对应的是 `pkg`，不是其目录里残留的 `mpkg4`——后者 `build.log` 是 `ctc: namespace 'types' does not match the directory ''` 的脚手架错误。为避免把错误坐标交出去，合论只读执行了既有产物 `pkg/out` 核对输出，未重建、未改动任何探针。
D-2 的冲突是**环境差异**，反证席已在 §1 固定了 `lib/std` 发现路径并给出对照输出；再跑一次只会复现同一环境差异。
D-3/D-4 是分级口径差异，不需要新证据。因此合论不新增探针；若要复核，直接跑 §8 的命令即可。

---

