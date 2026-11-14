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

## 4 J1–J14 逐条判定

判定口径与反证席一致：**先假设 H-04（`own`）与 H-06（重载）已按修法改掉**，再看该条断言本身能否写成可执行用例；
「可执行」不等于「今天能跑」，而是「修掉共享 API 问题后这条判据能落地」。主张席的「可保留」标签在差异行保留。

| 编号 | 提案条款 | 判定 | 原因 | 来源/差异 |
| --- | --- | --- | --- | --- |
| J1 | §11:301 | **不可执行（原文）** | 字段链接收者 `cannot resolve the method trait`（`p14.ct:32`）；`json_decode` 的 `own` 返回类型不可编译（H-04）。把 `Map *` 先落局部后可跑（`p22` 输出 `1`） | 反证席；主张席列为可保留，见 §3 D-3 |
| J2 | §11:302 | **不可执行（原文）** | 同一字段链错误（`p21.ct:22`：`doc->root.v.arr->len()`）；落局部后 `len()` 成立 | 反证席；主张席列为可保留 |
| J3 | §11:303 | **可执行** | 只依赖 `doc->root.tag/v.*`；需补 tag 常量导出方式（`#define` 不可用，改 `pub enum`） | 一致 |
| J4 | §11:304 | **不可执行** | 没有 code/offset；`message` 所有权未定义；无法断言 `line/col` 的具体值 | 一致 |
| J5 | §11:305 | **依赖未落地** | L1 未立项、非 Phase 40、明确排除指针接收者（H-10） | 一致 |
| J6 | §11:306 | **依赖未落地** | 同 J5，且自动转换不存在（H-11） | 一致 |
| J7 | §11:307 | **依赖未落地** | 同 J5；且 `Vec::get` 越界返回零值，`tag == 0` 与 `JSON_TAG_NULL` 撞值（`vec_oob_tag=0`），数组缺项会被误读成 null | 一致（反证席补撞值证据） |
| J8 | §11:308 | **不可执行** | 三重载冲突（H-06）+ 未取地址 + 无法选择入口 | 反证席；主张席列为可保留 |
| J9 | §11:309 | **不可执行** | 没有分配计数或 ASan/LSan 判据；「不 double-free」不是可观察结果 | 一致 |
| J10 | §11:310 | **不可执行且必假** | 没有计数 API；Drop 为空桩（H-05），`delete` 只 `free` 顶层 | 一致 |
| J11 | §11:311 | **依赖未落地** | 同 J5；链上两跳都是指针 | 一致 |
| J12 | §11:312 | **可执行（需改写）** | 写成 `arr->get(i).tag`（值拷贝，`Vec.h.ct:94-99`）；给 5 个元素的具体 tag 断言 | 一致（两席均要求改写） |
| J13 | §11:313 | **可执行** | `to_str` 对非 STR 返回 NULL（§4:134），需 `json_ref_to_str` 函数真实存在 | 一致 |
| J14 | §11:314 | **可执行** | 返回 0/1；但需同时补 `to_int` 对 NUM 越界的规则（H-13） | 一致 |

**计数：可执行 4（J3/J12/J13/J14，其中 J12 需改写）/ 不可执行 6（J1/J2/J4/J8/J9/J10）/ 依赖未落地 4（J5/J6/J7/J11）。**

---

## 5 与现有 38 条需求的关系

结论（主张席 §6，反证席 P0-10 一致）：**不是替代，是「口径 B 的完整版 + 大量静默删除」。**
提案只在 Q-01 裁定为「树为唯一公开模型」时才与需求兼容；在此之前它既推翻 API 载体，又不覆盖一半既有判据。

### 5.1 逐组归属（28 + 8 + 2 = 38）

| 组 | 条数 | 关系 | 具体 |
| --- | --- | --- | --- |
| A 解码 | 12 | 语义保留、载体取消 7 条 + 失效 5 条 | A-01～A-07（空输入/尾随/深度/转义/数字词法/重复键/访问器错误）语义仍需要，但判据全挂在被删的视图 API 上，必须重写到 `json_decode_ex`；A-08（UTF-8 开关）、A-09（实数精度）、A-10（深度硬上限）、A-11（大数组查找）、A-12（BOM）提案一字未提 → **失效**，其中 A-09 被「只有 double」再降一级 |
| B 编码 | 7 | 推翻 5 条 / 成立 2 条 | B-01～B-05 依赖 `JsonOut` 追写器，提案无该 API → **推翻**（截断不报错的问题随之回来）；B-06（原生 `Map`/`Vec` 直接编码）、B-07（能出就能读）**成立**，是提案唯一的实质增量 |
| C 错误 | 5 | 推翻/作废 3 条 / 保留 1 条 / 强化 1 条 | C-01（码+偏移+行列）被 §9 推翻；C-02（访问器错误五值）被 `to_*` 返回默认值推翻；C-03（码表冻结）随之作废；C-04（严格 RFC）**保留**进 decode；C-05（失败清理）**成立且更硬**——`JsonRef` 的元素 `release` 是空操作，必须手写递归 free |
| D 数据模型 | 8 | 成立 3 条 / 部分 2 条 / 推翻 2 条 / 越权 1 条 | D-01 **成立**；D-02 **成立但需 7 类 tag**（提案 6 类且无 int）；D-03 **不成立**（Drop 空桩、无 `json_free`、所有权两说）；D-04 被提案单方面选中口径 B（**越权**）；D-05 **推翻**（无 int64 落点）；D-06 **部分**（`char*` 无长度，NUL 丢失）；D-07 **成立**（`get` 返回 NULL）；D-08 **部分**（原位覆盖成立，旧值因 `elem_release` 空操作而泄漏） |
| E 工程 | 6 | 方向成立 1 条 / 需重写 1 条 / 静默缺失 4 条 | E-01（可 import）**方向成立**；E-02 需重写（`#define` 不进头，提案正好踩了 R-E-02 已警告过的那条）；E-03 许可、E-04 `requires` 下限、E-05 每条判据可执行、E-06 README 一致性全部未提 |

合计：直接推翻或作废 10 条（B-01～B-05、C-01～C-03、D-03、D-05）；越权单选 1 条（D-04）；一字未提而失效 5 条（A-08～A-12）；判据必须重写 7 条（A-01～A-07）；E 组需重写/未提 5 条（E-02～E-06）；仍成立 8 条（B-06、B-07、C-04、C-05、D-01、D-02、D-07、E-01）；部分成立 2 条（D-06、D-08）。28 + 8 + 2 = 38。

### 5.2 Q-01 与 `DECISIONS.md` 的冲突归属

- 现状决策：**视图唯一、零分配**（`DECISIONS.md:14-23`，`README.md:91-110`「No mutation, no DOM」）；`docs/requirements.md:207` 把 Q-01 记为「待确认」，`X-01` 仍未裁。
- 提案等于选了**口径 B**（树为唯一公开模型，视图降为内部），并把「两种模型并存、都能无损编码」的 `requirements.md:28` 直接改成「只有两个入口」（§14:415）。
- 归属（主张席 §6.1 的裁定，反证席 P0-10 未反对）：
  1. 「decode 落成原生 `Map`/`Vec`」是用户给的职责定位，`requirements.md:6` 已把它列为口径优先级第一；`DECISIONS.md` 是**在不含这条需求的前提下的取舍记录**。前提变了，记录必须让路。
  2. 但「不做可变 DOM」（`DECISIONS.md:69-75`）**并不**禁止原生容器树——`requirements.md:173` 已把它解释为「不另包一层 DOM 类」。所以真正的正面冲突不是「DOM」，而是 **DECISIONS §1「零分配视图唯一」 vs 提案「树唯一」**。这一条只能由 Q-01 裁定，提案不能自行覆盖。
- **顺序要求（硬）**：先裁 Q-01 = 口径 B，并在**同一决策提交**里改写 `DECISIONS.md:14-23`/`69-75` 与 `README.md:91-110` 的限制段；裁不下就退回口径 A，提案收缩为「视图之上的树构造层」，且**不得删除 125 条 golden**（R-E-05）。在 Q-01 裁定前，任何「先改决策文档再裁路线」的顺序都不成立，因为决策文档要改的方向正由 Q-01 决定。

---

## 6 如果要做：最小可行子集

只保留**只依赖现有 CT 0.44.1 能力**的部分（主张席 §4.1 的 8 项），逐条给出与提案原文的差异。
这 8 项不需要 L1、不需要自动转换、不需要跨单元导出树类型、不需要 Drop。

| # | 最小可行项 | 与提案原文的差异 |
| --- | --- | --- |
| 1 | `union JsonRefVal { int64 i; double n; char *s; Map<char*, JsonRef> *obj; Vec<JsonRef> *arr; }` + `int tag`（16 字节已验证：`sizeof=16`） | **具名 union**（提案 §2.1 是匿名 `union { … } v;`，被 CT 硬拒）；**恢复 `int64 i`**（提案只有 `double n`，丢 2^53 以上整数）；`obj`/`arr` 写**带类型实参的指针**（提案是裸 `Map *`/`Vec *`） |
| 2 | `Map<char*, JsonRef>` / `Vec<JsonRef>` 在**消费单元内**构造与遍历；键按插入序，重复键原位覆盖 | 提案假定树类型由包导出、跨单元使用；实测导出面不成立（H-03），故树只能在消费单元内实例化 |
| 3 | 递归 `json_free(JsonRef *)` 显式释放；键需自行拷贝并释放（`put` 不复制键） | **显式释放**替代 `own` + Drop（提案 §2.2/§7.1 的自动递归不成立）；`Map::put` 不复制键（`Vec.h.ct:254`），键的所有权必须写进规范 |
| 4 | 单一入口 `json_decode_ex(const char *text, int len, JsonError *err)`；错误保留现有「码 + 字节偏移 + 1-based 行列」 | **删除 `json_decode(char *text)`**（无长度，无法表达含 `\0` 的值）；`JsonError` 从 `line/col/message` 扩为 `code/offset/line/col/message` 并写死 `message` 所有权 |
| 5 | 具名编码入口 `json_encode_map` / `json_encode_vec` / `json_encode_scalar` | **不重载**（提案 §3.2 三个同名 `json_encode` 在 C 层 `conflicting types`） |
| 6 | `JSON_TAG_*` 改 `pub enum JsonTag { … }` | **不用 `#define`**（不进生成头，消费方 `use of undeclared identifier`） |
| 7 | 访问统一用 `.get()` / `.len()`，**不提供路径 API** | 删除 §3.4 `json_get` 与 §6 下标链；与 §1 的定位一致（提案自相矛盾见 H-18） |
| 8 | 验收保留 J1、J2、J3、J4、J7（仅 Map）、J8、J12、J13、J14 | 按反证席口径**改写后才可保留**：J1/J2 先落局部变量（H-08），J8 取地址并选定具名入口（H-06），J4 补 code/offset，J7 只对 `Map` 成立（`Vec` 越界撞 `JSON_TAG_NULL`） |

### 6.1 反证席的 12 条开工前闭合清单（原样归并）

| # | 必须闭合 | 闭合判据 |
| --- | --- | --- |
| C1 | Q-01 裁定（树唯一 / 并存）并同步 `DECISIONS.md`、`README.md` | 有明确裁决记录；125+20 golden 的处置清单（保留/改写/作废）写进评审结论 |
| C2 | `JsonRef` 定义可编译 | `ct` 通过；`cc -std=c99 -Wall -Wextra` 通过；`sizeof == 16`；导出单元的字段只含内建类型或 `void *` |
| C3 | 生命周期改为显式释放 | `json_free(JsonDoc *)` 有原型、有实现、有 ASan/LSan 用例；全文删除 `own`、删除「Drop 自动递归」承诺 |
| C4 | 所有权唯一 | 写明 decode 是否复制键/值；写明输入文本可释放时机；只保留一个释放函数名；`json_str` 副本归属有唯一答案 |
| C5 | 下标/自动转换降级 | J5/J6/J7/J11、§5、§6.1、示例 1/5 改为「本期不主张」，判据全部换成 `.get()` / `.len()` |
| C6 | 编码入口可编译 | 具名三入口或单入口 + tag；`cc` 零 `conflicting types`；键序与数字格式写死 |
| C7 | 数值契约 | 恢复 int64 与 double 双 tag；`to_int` 越界规则；`1e400`/`-0` 判据；Q-04 有口径 |
| C8 | 文本契约 | 含 NUL 的值/键二选一（支持或明确不支持）；UTF-8/BOM 二选一；Q-05 有口径 |
| C9 | 错误契约 | code + offset + line + col；`message` 所有权写死；失败示例加 `return`；20 条错误用例迁移 |
| C10 | 示例统一 CT | §13 五个示例可 `ct` + `cc` 跑通，或明确标为伪代码；补 include 与编译命令 |
| C11 | J 表重写 | 每条给「可执行/依赖未落地/不做」标签；补 §6 的缺失用例；J9/J10 改成可观察断言 |
| C12 | 路径 API 去留 | `json_get` 要么删除（与 §1 一致），要么给完整文法 + 非法路径 + 越界 + 分配规则 |

---

## 7 需要外部评估方回答的问题

以下 8 项必须由人裁定，合论不替选。每项给出候选与各自后果。

**Q-A 数据模型路线（Q-01）：视图、树、还是并存？**
- A1 口径 A 并存：视图与树共享词法校验，视图保留为轻量路径。后果：D 组与 B-06 全部成立，125+20 golden 原样保留，`DECISIONS.md` 只需追加不重写；实现量最大，两套 API 要保证同输入同值。
- A2 口径 B 树唯一：树为唯一公开模型，视图降为内部。后果：必须给 125+20 golden 的迁移/替换清单并改写 `DECISIONS.md:14-23`/`69-75` 与 `README.md:91-110`；提案的「只有两个入口」才成立。
- A3 口径 C 视图唯一：撤销 D 组。后果：本提案整体作废，只剩 A/B/C 组的现状固化。

**Q-B 数值精度承诺（Q-04）：**
- B1 正确舍入 + 超 int64 整数转 double。后果：需引入 `strtod` 或大整数路径，locale 依赖要处理；R-A-09 可判。
- B2 保持现状实数近似 + 超 int64 报 `JSON_READ_RANGE`。后果：不需新算法，文档降级；R-D-05 取「报错」分支。
- B3 提案的全 `double` 单 tag。后果：整数精度掉到 2^53，违反 R-D-02/R-D-05，现状能力直接回退（不建议，但这是候选）。

**Q-C Unicode 承诺（Q-05）：**
- C1 默认宽松 + `strict` 开关校验 UTF-8，BOM 可选剥离。后果：新增错误码与开关，R-A-08 可判；golden 需增 strict/非 strict 两组。
- C2 始终不校验 UTF-8、BOM 一律拒绝、键含 `\u0000` 一律拒绝。后果：不改实现，只需写死负例；R-D-06 的「值保留 NUL」仍悬空。
- C3 值是长度前缀 `Str`、键也长度化。后果：`Map<char*,V>` 无法表达含 NUL 的键，需另设对象表示，工作量与 API 面都扩大。

**Q-D 错误模型（Q-03）：**
- D1 码 + 偏移 + 行列 + 文案冻结。后果：golden 可比对文案，R-C-03 取「冻结」；文案改动即红灯。
- D2 码 + 偏移 + 行列，文案只保证非空。后果：R-C-03 取「不作契约」，负例只断言码与位置。
- D3 提案的 `line/col/message`。后果：丢掉稳定码与偏移，20 条错误用例无法逐条断言（不建议，但这是候选）。

**Q-E 包形态与版本承诺（Q-06）：**
- E1 拆单元 + 冻结最小导出面 + `requires`。后果：R-E-01/E-02/E-04 可判；需要先解决导出面的泛型字段问题（H-03），否则导出面只能放 `void *`。
- E2 保持单文件复制 + 补 `requires`。后果：不需要碰导出缺陷，但 R-E-01 不成立，消费者仍不能 `import`。

**Q-F 语言依赖策略（L1 下标 + 自动转换）：**
- F1 等 L1 立项并补指针接收者后再做下标链。后果：J5/J6/J11 继续冻结，本版用 `.get()`；需向 ct-lang 提需求。
- F2 本期只用 `.get()`/`.len()`，把下标链与自动转换列为非目标。后果：提案 §5/§6 全删，判据不变；本版可立即开工。
- F3 推动 ct-lang 改 L1 支持指针接收者 + 新增自动转换。后果：跨仓库改动，超出本包边界，工期与风险不可控。

**Q-G `map trait` 是否作为公开取值面（D-1 残余）：**
- G1 作为唯一取值方式，并在规范里写死三条硬条件 + 附一个最小可编译包样例。后果：API 最薄，但包布局被绑死；跨命名空间还需别名。
- G2 改为普通函数 `json_ref_to_str(v)` 等，不提供 `.to_str()`。后果：无包布局约束、无 mangled 名问题；调用更啰嗦，且提案「零开销寄生」的卖点消失。
- G3 本期不提供，调用方自取 `tag` 与 `v.*`。后果：API 面最小，但类型不匹配的默认值语义（§4）全部由调用方重写。

**Q-H 125+20 golden 与视图 API 的处置：**
- H1 全保留并新增树用例。后果：两套判据都要跑，回归资产最厚；与口径 A 配套。
- H2 视图判据保留、树用例新增，但分两条命令。后果：迁移成本低，需明确哪条是发布门禁。
- H3 作废视图 golden，重写为树判据。后果：与口径 B 配套，但现有 125 条覆盖（转义、错误码、emit 往返）需要逐条翻译，漏一条就是回归缺口。

---

## 8 复现附录：24 条探针

环境前置（反证席 §1 固定，缺了会把泛型声明误判成比较表达式）：

```sh
mkdir -p /tmp/ctprobe/bin /tmp/ctprobe/lib
cp /Users/samxx/.local/bin/ct /tmp/ctprobe/bin/ct
ln -s /Users/samxx/trae-ws/ct-lang/lib/std /tmp/ctprobe/lib/std
cd /tmp/ctprobe && ./bin/ct t3.ct -o t3.c && cc -std=c99 t3.c -o t3 && ./t3
# 3
```

缺 `lib/std` 时的误导性错误（`[主张席]` 环境）：`t3.ct:5:8: error: use of an undeclared variable`。

| # | 项 | 探针坐标 | 命令 | 原始输出 |
| --- | --- | --- | --- | --- |
| P-01 | 匿名 `union` 具名字段 | `r1_anon.ct:8:7` | `./bin/ct r1_anon.ct -o r1.c` | `r1_anon.ct:8:7: error: an anonymous record member cannot have a name; tag the record instead`，`rc=1` |
| P-02 | 裸泛型 `Map *` / `Vec *` | `r2_bare.ct:2:49` | `./bin/ct r2_bare.ct -o r2.c` | `r2_bare.ct:2:49: error: generic struct 'Map' needs type arguments in a type position`，`rc=1`；`[主张席]` `p1.c:12:9: error: unknown type name 'Map'`、`p1.c:13:9: error: unknown type name 'Vec'` |
| P-03 | 泛型字段进导出头 | `c3/H.h.ct:1:1` | `cd c3 && ./bin/ct build main.ct -o app` | `./H.h.ct:1:1: error: expected a field name`，`rc=0` |
| P-04 | `#define` 不导出 | `c1/main.ct:6:20` | `cd c1 && ./bin/ct build main.ct -o app` | `main.ct:6:20: error: use of undeclared identifier 'JSON_TAG_NUM'` |
| P-05 | `pub enum` 可导出 | `c1/main.ct` | `cd c1 && ./bin/ct build main.ct -o app2 && ./app2` | `2` |
| P-06 | `own` 接工厂返回值 | `p1b_own.ct:30:1` | `./bin/ct p1b_own.ct -o p1b.c` | `p1b_own.ct:30:1: error: 'own' requires a malloc or calloc initialiser`、`ctc: 1 error(s) generated`，`rc=1` |
| P-07 | `own` 写进返回类型 | `p12.c:49`、`p12.c:176` | `./bin/ct p12.ct -o p12.c && cc p12.c` | `p12.c:49:8: error: unknown type name 'own'`、`49 \| static own struct JsonDoc * json_decode(char *);`、`p12.c:176:8: error: unknown type name 'own'`（`ct-rc=0`，CT 放行、C 拒绝） |
| P-08 | 同单元 Drop 胶水空体 | `p6b.c:305-309` | `grep -A3 JsonDoc_Drop_drop p6b.c` | `static void __attribute__((unused)) JsonDoc_Drop_drop(void *self) { struct JsonDoc *_self = (struct JsonDoc *)self; (void)_self; }` |
| P-09 | 跨单元 Drop 空桩 | `dropkg/src/main.ct` | `cd dropkg && ./bin/ct build src/main.ct -o app && ./app` | `done`、`run-rc=0`；`[lib]` 一行未打 |
| P-10 | 指针字段胶水类型错乱 | `p23.ct` | `./bin/ct p23.ct -o p23.c` | `JsonRef_Drop_drop(&_self->p);`（传 `struct JsonRef **` 被当 `struct JsonRef *`），`Map` 字段被忽略 |
| P-11 | 三重载 | `p2b.c:570`、`p2b.c:573`、`p2b.c:448` | `./bin/ct p2b.ct -o p2b.c && cc -c p2b.c` | `p2b.c:570:8: error: conflicting types for 'json_encode'`、`p2b.c:448:8: note: previous declaration is here`、`p2b.c:573:8: error: conflicting types for 'json_encode'`、`p2b.c:448:8: note: previous declaration is here` |
| P-12 | `Vec::get` 返回值 | `p16.c:347` | `./bin/ct p16.ct -o p16.c && cc p16.c` | `p16.c:347:26: error: initializing 'struct JsonRef *' with an expression of incompatible type 'struct JsonRef'` |
| P-13 | 字段链调用 | `p14.ct:32`、`p21.ct:22` | `./bin/ct p14.ct -o p14.c` | `p14.ct:32:1: error: cannot resolve the method trait (unknown receiver type)` |
| P-14 | 下标落 C | `p8.ct:9`（生成 `p8.c:161`） | `./bin/ct p8.ct -o p8.c && cc p8.c` | `p8.c:161:29: error: array subscript is not an integer`、`161 \|     struct JsonRef * h = doc["host"];` |
| P-15 | 自动转换不存在 | `pkg/src/main2.ct:11` | `cd pkg && ./bin/ct build src/main2.ct -o app3 && ./app3` | `src/main2.ct:11:12: warning: incompatible pointer types initializing 'char *' with an expression of type 'struct jsonext_JsonRef *'`；运行输出一个控制字节（地址被当字符串） |
| P-16 | `map trait` 可行形态 | `pkg/src/jsonext/Json.h.ct`、`JsonOps.m.ct` | `cd pkg && ./bin/ct build src/main.ct -o app4 && ./app4` | `to_str=0x0 to_int=8080` |
| P-17 | `map trait` 别名形态（主张席） | `/tmp/ctjson-probe/pkg/ext/ext.m.ct`、`pkg/types/types.h.ct` | `cd /tmp/ctjson-probe && ~/.local/bin/ct build pkg/main.ct -o pkg/out && ./pkg/out` | `s 1`（`rc=0`）；别名未加时同一命令的日志为 `pkg/main.ct:14:1: error: no method 'to_str' for type 'struct types_JsonRef *'` |
| P-18 | 数字精度与 UB | `p9.ct` | `./bin/ct p9.ct -o p9.c && cc p9.c -o p9 && ./p9` | `d=9007199254740992`、`big=inf`、`neg=-0`、`int_cast=207049388`、`int_cast2=1073741824` |
| P-19 | NUL 键碰撞 | `p10.ct` | `./bin/ct p10.ct -o p10.c && cc p10.c -o p10 && ./p10` | `len=1`、`k1=2 k2=2` |
| P-20 | Map 值共享指针 | `p20.ct` | `./bin/ct p20.ct -o p20.c && cc p20.c -o p20 && ./p20` | `same_ptr=1` |
| P-21 | Map 缺键 / Vec 越界 | `p24.ct` | `./bin/ct p24.ct -o p24.c && cc p24.c -o p24 && ./p24` | `map_missing=0x0`、`vec_oob_tag=0` |
| P-22 | RILL 语法混入 | `p11.ct:6:5` | `./bin/ct p11.ct -o p11.c` | `p11.ct:6:5: error: expected an expression` |
| P-23 | 16 字节 | `p18.ct` | `./bin/ct p18.ct -o p18.c && cc p18.c -o p18 && ./p18` | `sizeof=16`（`[主张席]` 同条：`sizeof(JsonRef)=16 sizeof(union)=8`） |
| P-24 | 基线 golden | `json.ct`、`json.expected.out` | `./bin/ct json.ct -o json.c && cc json.c -o jsongold && ./jsongold > gold.out && grep -c '^ok ' gold.out && diff -q gold.out /Users/samxx/trae-ws/ct-json/json.expected.out` | `125`、`GOLDEN-MATCH`（共 135 行 = 125 `ok` + 20 errors） |

附：递归深度（反证席 §10 未验证项，仅作风险记录，不是判据）：`p15c`（100k 层）→ `max=100000`、`rc=0`；`p15b`（1M 层）→ `rc=139`（SIGSEGV）。提案无深度上限条款。
