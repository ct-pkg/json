# ct-json 0.1.0 反证（三）

> 承接 [02](ct-json-0.1.0-rebuttal-02.md) 的 §2 P0-5…P0-10 与 §3–§11；章节编号不变。

### P0-5 所有权没有闭合（§3.3:95-98、§7.3:224-229、§12.5:324）

**条款内部就有三个名字**：`json_ref_release_owned`（§3.3:98）、`json_ref_free_owned`（§7.3:226）、「调用方自管」（§12.5）。三者都没有签名、没有定义、没有测试。

**实测：同一个字符串指针被两个键共享**

```
$ cd /tmp/ctprobe && ./bin/ct p20.ct -o p20.c && cc -std=c99 p20.c -o p20 && ./p20
same_ptr=1
```

`Map::put` 按值拷贝 `JsonRef`（`Vec.h.ct:253-255`），`JsonRef` 没有 `retain`/`release`，所以两个槽位共享同一个 `strdup` 指针。按槽位释放会 double-free，按一次释放会让另一个槽位悬垂。

**另外两处未定义**：

- **decode 是否复制输入字符串？** §2.1:51 说 `v.s`「指向 `JsonDoc` 内部缓冲」→ 隐含复制；但全文没写「decode 完成后调用方可以立刻释放输入文本」。若实际不复制，`json_decode(temp)` 之后 `temp` 一旦失效，`v.s` 就是悬垂。
- **键谁释放？** §7.1:203-206 的 Drop 步骤只写「释放 Map 的每个 JsonRef 值」和「释放 Map 本身」，**没有键**。而 `Map::put` 不复制键（`Vec.h.ct:254`；`bindings-and-patterns.md:53`），`Map::release` 也只释放值（`Vec.h.ct:517-537`）。按 §7.1 实现，**所有对象键全部泄漏**。

**修法**：规定 decode 一律复制键与字符串；明确「输入文本在 decode 返回后即可释放」；只保留一个释放函数（如 `json_free`）并规定它按 tag 递归、同时释放键；`json_str` 的副本归 `JsonRef` 所有这条要么删除，要么给 `JsonRef` 加 ownership 位（当前 16 字节里没有）。

### P0-6 数值契约回退（§2.1:31、§4:132-137、Q-04、R-D-02/R-D-05）

**实测**

```
$ cd /tmp/ctprobe && ./bin/ct p9.ct -o p9.c && cc -std=c99 p9.c -o p9 && ./p9
d=9007199254740992          # 输入是 9007199254740993.0
big=inf                     # 输入是 1e400
neg=-0
int_cast=207049388          # (int)1e10，未定义行为的具体产物
int_cast2=1073741824        # (int)4294967296.0
```

- 所有数字走 `double`：超过 2^53 的整数静默丢精度（雪花 ID、金额、64 位端口号）。现状实现整数在 `int64` 内精确（`json.ct:1234-1283`）。
- `to_int` 定义为 `(int)v.n`（§4:135）：C 里 double→int 越界是 UB，实测给出无意义值；这不是「截断」，是不可预期。
- `1e400` 解成 `inf`，提案没有拒绝规则；旧实现 `as_double` 报 `JSON_READ_RANGE`（`json.ct:1284-1383`），旧 B-03 还要求 encode 拒绝非有限值。
- `JSON_TAG_NUM` 把 int/double 合成一个 tag，直接违反 `docs/requirements.md:138`（R-D-02 要求 7 类 tag，含 int 与 double 分开）与 `:141`（R-D-05 要求无小数/指数且在 int64 内落到 int64）。

**Q-04 没有被解决，而是被绕成一个更差的第三选项**：既不是口径 A（正确舍入 + 超 int64 转 double），也不是口径 B（超 int64 报错），而是「全部 double、没有 int64」。

**修法**：`JsonRef` 恢复 `int64 i` 与 `double n` 双 tag；`to_int` 改成带范围检查的 `int64`；明确定义 `1e400`、`-0`、`NaN`（encode 时）、以及 encode 的数字格式（见 P1）。

### P0-7 文本契约回退（§2.1:33、§3.3:95、Q-05、R-D-06/R-B-04/R-A-08/R-A-12）

**实测：键里的 NUL 碰撞**

```
$ cd /tmp/ctprobe && ./bin/ct p10.ct -o p10.c && cc -std=c99 p10.c -o p10 && ./p10
len=1
k1=2 k2=2
```

两个键 `"a\0b"` 与 `"a\0c"` 被 `strcmp` 判为同一个键，后写覆盖前写。`Map<char*,V>` 的键比较就是 `strcmp`（`Vec.h.ct:41-46`、`:232-239`）。

其余：

- 值类型是 `char *`，`"a\u0000b"` 解码后无法保留 3 字节；旧实现 `jw_escaped` 以 `'\0'` 为终止符（`json.ct:711`），旧需求 R-B-04 正是要求补长度 API。
- 输入 UTF-8 不校验（`json.ct:193-211` 只拒绝 `<0x20`），BOM `EF BB BF` 按非法字符拒绝（`DECISIONS.md:99-106`）。提案**一字未提** R-A-08 的 strict 开关与 R-A-12 的 BOM 口径。

**Q-05 同样被绕过**：没有选口径 A/B，也没有声明「含 NUL 不支持」。`char *` 这个类型本身就把 R-D-06 的 `len` 契约排除掉了。

**修法**：字符串值改用 `Str`（`{char*,int}`，v0.36.0 已支持）或自定义 `{char*,int}`；键要么也长度前缀（Map 不支持，需另设对象表示），要么在 §12 明确「含 `\u0000` 的键/值不支持」并删掉「无损」表述；UTF-8/BOM 必须给可判定口径。

### P0-8 错误模型回退（§3.1:78、§9:250-265）

**条款**：`JsonError { int line; int col; char *message; }`；decode 失败示例：

```ct
own JsonDoc *doc = json_decode(text);
if (doc == NULL) {
    <send> "JSON 解析失败" [to] user
    // 需要错误位置时用 json_decode_ex
}
// 没有 return，下一行继续用 doc
```

- **丢掉了现有「稳定错误码 + 字节偏移」**（`json.ct:1624-1653`；需求 R-C-01:127 要求逐条核对 code / offset / line / column）。只有 line/col/message 无法定位同一行内的多个错误，也无法写稳定负例。
- `message` 是 `char *`，**生命周期未定义**：静态字面量、调用方缓冲、还是 malloc？没有一条写得清。
- 示例本身是空指针继续用：`doc == NULL` 分支不 `return`、不 `else`，照抄就是解引用空指针。这不是排版问题，是规范给出的「完整示例」。
- `json_decode(char *text)`（§3.1:74）没有长度参数；`json_decode_ex(text, len, …)` 才有。ct-sse 的 `data` 是长度前缀且可含 NUL（`ct-sse/docs/requirements.md:50`，R-B-01），主入口无法直接消费。
- 空输入、纯空白、尾随数据、深度超限、OOM 的错误码全部没有；旧实现有 20 条错误用例（`json.expected.out:134`）。

**修法**：恢复 `code + offset + line + col`；`message` 改为「写入调用方缓冲」或「指向静态常量，永不为 NULL」二选一并写死；主入口统一 `(const char *text, int len)`；失败示例加 `return`/`else`；补错误码表。

### P0-9 两种宿主语言混淆（§13:329-409）

示例 1/2/4/5 使用 `<send> … [to] user`，这是 **RILL** 语法，不是 CT：

```
$ cd /tmp/ctprobe && ./bin/ct p11.ct -o p11.c
p11.ct:6:5: error: expected an expression
```

RILL 侧同款写法在 `rill-dsl/testdata/0.1.0/positive/quotes/escapes/source.rill:1` 等文件里。而 API 类型（`char *`、`Map<char *, JsonRef>`、`struct JsonRef`）是 CT 的。`defer`（Phase 38）是 CT 合法的，但 `[to] user` 不是。

**判定**：这份规范**面向 CT 宿主**，但 §13 的示例有一半不可运行。因此：

- 示例 1：`own`、`<send>`、L1 下标、自动转换，四处不成立；
- 示例 2：`<send>`、`Vec::get` 返回指针，两处不成立；
- 示例 4：`<send>` 与 `switch` 分支里的 RILL 语句，不成立；
- 示例 5：`own`、L1 下标，两处不成立；
- 示例 3：唯一的 CT 示例，但 `json_encode(m)` 传值给指针形参（见 P2）。

**修法**：示例统一改 CT（`printf` + `.get()` + `json_free`），或把 RILL 调用点单独标注为「调用方伪代码」，并明确它们不是验收对象。

### P0-10 与既有 125 + 20 条 golden、38 条需求的关系未交代（§14:415、Q-01）

提案 §14 说「只有两个公开入口」，等于把现有视图 API 全部裁掉；但：

- 现有 golden 125 `ok` + 20 errors 是仓库唯一的回归资产（本轮实跑匹配）；
- 需求 `docs/requirements.md:154`（R-E-05）要求「现有 125 条 `ok` + 20 条 errors 保留」；
- `docs/requirements.md:207`（Q-01）仍是**待确认**，`X-01` 未裁；
- `DECISIONS.md:14-23`、`README.md:91-110` 明确「零分配视图唯一、无 DOM」。

提案没有说：视图 API 删除还是保留？125 条 golden 作废还是改写？`JsonDoc` 与现有同名类型（`json.ct:126-136`，`use Json`）怎么处理？**这属于范围与验收基线问题，不是措辞问题。**

**修法**：先裁 Q-01；若选树唯一，必须同时给出 125+20 的迁移/替换清单，并改 `DECISIONS.md` / `README.md`；若并存，提案要收缩成「树构造层」，不得删除视图判据。

---

## 3 P1 · 说得不够清晰

| # | 位置 | 问题 | 需要写死的内容 |
| --- | --- | --- | --- |
| P1-1 | §1:17 vs §3.4:100-108、§6.2:185、§12.4:323 | 一边说「不做路径查询 API」，一边给 `json_get(doc, "server.host")` | 路径文法（转义、空串、末位 `.`、`a[0][1]`、负下标、键里含 `.`/`[`）；非法路径返回 NULL 还是 MISSING；路径解析是否分配 |
| P1-2 | §7.2:219 | `json_ref_clone` 只出现一次，无签名、无释放规则 | 返回 `own JsonRef *`？深拷贝到什么程度？配套的释放函数是什么？ |
| P1-3 | §7.2:211-214 | 「borrow 生命周期到 delete doc」与容器契约冲突：`Map::get` 返回的指针「在下一次 `put`/`remove`/`clear` 前有效」（`Vec.h.ct:397-408`） | 写明 decode 后 Map 不再修改；或改成 copy-out API |
| P1-4 | §3.1 / §11 | 重复键语义（last-wins？保留首次位置还是移到末尾？）一字未提 | 与旧 R-A-06 / R-D-08 对齐，并给用例 |
| P1-5 | §3.2 | encode 的契约几乎空白：键序、数字格式、`NaN`/`Inf`、`json_str(NULL)`、OOM、循环引用 | 键按插入序（`Vec.h.ct:41-46`）；数字用最短往返还是 `%.17g`；非有限值报错还是输出；OOM 返回 NULL 还是 abort |
| P1-6 | 全文 | decode 深度上限未定义 | 默认值、硬上限、超限错误码（旧 R-A-10 建议 1024） |
| P1-7 | §9:259-265 | `line`/`col` 按字节还是字符？多字节 UTF-8、tab 怎么算？ | 与旧实现一致：1-based、列按字节、`\n` 换行（`README.md:98-99`） |
| P1-8 | §3.1:74-75 | 两个入口的 `len` 语义：`json_decode` 无 len（靠 `strlen`？），`json_decode_ex` 的 len 含不含结尾 NUL？负数怎么办？ | 统一 `(const char*, int len)`，len 是字节数 |
| P1-9 | §4:124-129、§10:290 | `map trait` 必须放 `.m.ct`、消费方必须 `import`、recipe 只能单调用、命名空间内要写 mangled 名。实测 `a map recipe must be a single call`（把 `to_str(v) -> v->tag == 3 ? v->v.s : 0;` 写进 recipe 时）；写成裸名 `json_ref_to_str(v)` 则 `call to undeclared function` | 在规范里给出最小可编译包布局、一行 mangled recipe 与 import 语句 |
| P1-10 | 全文 | 并发/可重入未表态；`json_decode` 是否可多线程并发调用？ | 声明「不做线程安全」，或证明无共享状态 |
| P1-11 | 首行 vs §2.1:28 | 「JsonRef 是纯 union」但定义是 `struct { int tag; union … }`；§14「只有两个公开入口」与 §3.3/§3.4/§4 的构造器、`json_get`、`to_*`、释放函数矛盾 | 统一措辞：POD（tagged struct）；公开面按「入口 / 能力 / 兜底」分三层列全 |

---

## 4 P2 · 只需补例子

| # | 位置 | 问题 | 补法 |
| --- | --- | --- | --- |
| P2-1 | §13 全部示例 | 缺 `#include <stdio.h>` / `<stdlib.h>`；C99 下 `printf`/`free` 未声明会被 `-Wall -Wextra` 拦 | 每个完整示例补 include，并给 `ct` + `cc` 两行命令 |
| P2-2 | §13 示例 3:369 | `json_encode(m)` 把 `Map` 值传给 `Map *` 形参 | 改 `json_encode(&m)`；实测不改就是 `passing 'struct Map…' to parameter of incompatible type '… *'` |
| P2-3 | §13 示例 3:370 | `Map<char*,JsonRef> m = {}; defer { m.release(); }`，若一次都没 `put`，`release()` 会对零 handle abort（`Vec.h.ct:189-195`） | 示例要么先 `put`，要么用 `if (m.h != 0)` guard；规范写明空 map 的 `release` 契约 |
| P2-4 | §11 J8 | `json_str("x") + json_encode` 没说取地址 | 写成 `JsonRef v = json_str("x"); json_encode(&v)` |
| P2-5 | §13 示例 5 | `llm_stream_tool_call_args` 是虚构函数，未给返回缓冲区是否 NUL 结尾 | 给最小 stub 与长度约定，或标为伪代码 |

---

## 5 J1–J14 逐条判定

> 判定口径：**先假设 P0-2/P0-4 的共享 API 问题已按修法改掉**，再看这一条断言本身能不能写成可执行用例。因此「可执行」不等于「今天就能跑」，而是「修掉 `own`/重载/字段链之后，这条判据能落地」。

| 编号 | 判定 | 依据 |
| --- | --- | --- |
| J1 `root.v.obj->get("a")->v.n` | **不可执行（原文）** | 字段链接收者报 `cannot resolve the method trait`（`p14.ct:32`）；把 `Map *` 先落局部后可跑（`p22` 输出 `1`）。另外 `json_decode` 的 `own` 返回类型不可编译（P0-2） |
| J2 `root.v.arr->len() == 3` | **不可执行（原文）** | 同一字段链错误（`p21.ct:22`）；落局部后 `len()` 成立 |
| J3 四个标量 | **可执行** | 只依赖 `doc->root.tag/v.*`；需补 `JSON_TAG_*` 的导出方式（`#define` 不可用，改 `pub enum`） |
| J4 `{invalid` → NULL + JsonError | **不可执行** | 没有 code/offset；`message` 所有权未定义；无法断言 line/col 的具体值 |
| J5 `doc["server"]["host"]` | **依赖未落地** | L1 未立项、非 Phase 40、排除指针接收者（P0-3） |
| J6 `int port = doc["port"]` | **依赖未落地** | 同上 + 自动转换不存在（P0-3） |
| J7 `doc["missing"]` → NULL | **依赖未落地** | 同上；且 `Vec::get` 越界返回值零值，`tag == 0` 与 `JSON_TAG_NULL` 撞值（实测 `vec_oob_tag=0`），数组缺项会被误读成 null |
| J8 `json_str("x")` + encode | **不可执行** | 三重载冲突（P0-4）+ 未取地址；输出断言也无法选择入口 |
| J9 「encode 后 free 不 double-free」 | **不可执行** | 没有分配计数或 ASan/LSan 判据；「不 double-free」不是可观察结果 |
| J10 `delete doc` 后 free 计数归零 | **不可执行且必假** | 没有计数 API；Drop 为空桩（P0-2），`delete` 只 `free` 顶层 |
| J11 `doc["a"]["b"]["c"]` | **依赖未落地** | 同 J5；链上两跳都是指针 |
| J12 异构 array 每个 tag 正确 | **可执行（需改写）** | 写成 `arr->get(i).tag`（值拷贝，`Vec.h.ct:94-99`）；给 5 个元素的具体 tag 断言 |
| J13 `to_str` 对非字符串 | **可执行** | `to_str` 对非 STR 返回 NULL（§4:134），需 `json_ref_to_str` 函数真实存在 |
| J14 `to_int` 对 bool | **可执行** | 返回 0/1；但需同时补 `to_int` 对 NUM 越界的规则（P0-6） |

> 与主张席的差异：对方把 J1/J2/J8 列为「可保留」，但**按原文写法**这三条都过不了 CT/CC 两段编译（J1/J2 是字段链接收者，J8 是重载冲突）；J1/J2 在落局部变量后才可以保留。

---

## 6 缺失的关键用例

按「一个都不能省」列：

1. **空容器**：`{}`、`[]`、`{"a":{}}`、`[[]]`；`len/count == 0` 与 encode 输出。
2. **重复键**：`{"a":1,"a":2}`（值、位置、encode 顺序）；转义键 `"a\u0062"` 命中 `"ab"`。
3. **数值**：`1e400`、`1e-400`、`-0`、`0.1`、`9007199254740993`、`9223372036854775807`、`9223372036854775808`、`1.0`、`1e3`；decode→encode→decode 的数值等价。
4. **字符串**：`\u0000` 值、`\u0000` 键、超长串（1 MiB）、孤立代理项、`\uD83D\uDE00`、非法 UTF-8（`0xFF 0xFE`）、BOM、控制字节。
5. **深度**：64/65/1024/10^6 层；decode 与 `json_free` 各一遍（递归爆栈）。
6. **错误**：空输入、纯空白、尾随数据、截断字符串、坏转义、坏 `\u`、`01`、`1.`、`.5`、`+1`、`1e`、注释、尾逗号、`NaN`；每条断言 code + offset + line + col。
7. **encode 契约**：键序、键转义、`NaN`/`Inf`、`json_str(NULL)`、OOM、循环引用、深树。
8. **入口边界**：`json_decode(NULL)`、`len == 0`、`len < 0`、`len` 大于实际、非 NUL 结尾缓冲区、输入含 NUL。
9. **并发**：多线程并发 decode；`JsonRef` 跨线程共享的契约。
10. **所有权**：decode 后释放输入文本；`json_free` 后 ASan/LSan 0 泄漏；重复 `json_free`；`json_str` 副本与 decode 借用混用。

---

## 7 Q-04 / Q-05 / Q-03 对照

| 需求项 | 旧状态（`docs/requirements.md`） | 提案的处理 | 判定 |
| --- | --- | --- | --- |
| Q-04 数字精度 | 整数 int64 精确；实数 19 位、指数 ±400、末位可能差；三口径待选（`:210`） | 全部 `double` 单 tag；整数精度掉到 2^53；没有选任何口径 | **未解决，且比现状更差**；违反 R-D-02/R-D-05 |
| Q-05 Unicode | 不校验 UTF-8、不剥 BOM、`\u0000` 写回截断；两口径待选（`:211`） | 一字未提；`char *` 类型使含 NUL 值/键不可表达 | **未解决**；R-A-08/A-12/D-06/B-04 全部悬空 |
| Q-03 错误模型 | 码 + 字节偏移 + 1-based 行列；文案是否冻结待定（`:209`） | 只有 line/col/message；message 所有权未定义 | **回退**；R-C-01/C-03 无法验收 |
| Q-01 数据模型 | 视图 vs 树 vs 并存，待裁（`:207`） | 单方面选「树唯一」，删掉视图入口 | **越权**；必须先裁 Q-01 |

---

## 8 与主张席评估的分歧（复核）

已有 `docs/review/ct-json-0.1.0-advocate.md`；我的结论与其「NO-GO」一致，但以下四处的判据需要修正/加强：

1. **A2（裸泛型）**：主张席写「`ct` 原样透传，`cc` 报 unknown type name」。在 `lib/std` 可发现的环境下，`ct` 自己就会报 `generic struct 'Map' needs type arguments in a type position`（`r2_bare.ct:2:49`）。结论不变，但证据应换成 CT 层错误，避免把「环境缺 std」当成语言放行。
2. **A6（`map trait` 寄生）**：主张席判「不成立（原样）；有丑绕法」。我实测到一个更窄但可行的形态：命名空间 `.m.ct` + `map trait JsonExtract for type JsonRef *` + recipe 写 mangled 名，消费方 `import` 两个单元后 `.to_str()` / `.to_int()` 可用（`/tmp/ctprobe/pkg/app4`：`to_str=0x0 to_int=8080`）。所以应改为「**可行，但提案必须写死三件事**：`.m.ct`、import、mangled recipe 名」，而不是「不成立」。
3. **J1/J2/J8 的「可保留」**：见 §5；按原文写法不可保留，落局部/改签名后才可保留。
4. **A10（跨单元导出树类型）**：我复现了「带泛型字段的结构无法出现在 `.h.ct`」：`pub struct Holder { Vec<int> *v; }` 直接报 `expected a field name`（`/tmp/ctprobe/c3`）。这与主张席的「生成头 incomplete type」是不同失败点，但结论相同：导出面不可用。

其余 A3（16 字节）、A4（指针字段胶水类型错乱）、A7（`#define` 不进头）、A9（`Vec::get` 值拷贝）、A11（`Map::get` 缺失返回 NULL）、A12（下标落 C）、A13（自动转换不存在）、A14（RILL 语法）我独立复现，结论一致。

补充一条主张席未在 J 表写明的实测：`Vec::get` 越界返回零值，`tag == 0` 与 `JSON_TAG_NULL` 撞值，因此 J7 的「数组缺项返回 NULL」不可能成立：

```
$ cd /tmp/ctprobe && ./bin/ct p24.ct -o p24.c && cc -std=c99 p24.c -o p24 && ./p24
map_missing=0x0
vec_oob_tag=0
```

---

## 9 开工前必须闭合（按顺序）

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

## 10 未验证

- decode/`json_free` 在 10^6 层下的精确爆栈阈值；本轮只测了平凡递归：100,000 层通过（`max=100000`, rc=0），1,000,000 层 `rc=139`（SIGSEGV）。提案无深度上限，这是风险不是结论。
- OOM 与部分树回滚（需注入分配失败，未做）。
- 「并发 decode」的线程安全性（提案无实现）。
- L1 落地后的 `JsonRef::get` 类型冲突（按 RL1-D3 只校验元数推演，未实测）。
- `json_encode` 的输出语义（无实现；键序/数字格式/NaN 均无条款）。
- 跨单元导出修复后 `JsonRef` 是否可用（当前 `Vec`/`Map` 字段在 `.h.ct` 直接解析失败）。
- 跨单元 `Drop` 空桩是否会在未来版本修复（当前 v0.44.1 实测为空桩；属 ct-lang 缺陷，不是本包能绕过的）。

---

## 11 复现清单

探针均在 `/tmp/ctprobe`（仓外）：

| 项 | 命令 | 原始结果 |
| --- | --- | --- |
| 匿名 union | `./bin/ct r1_anon.ct -o r1.c` | `an anonymous record member cannot have a name` |
| 裸泛型 | `./bin/ct r2_bare.ct -o r2.c` | `generic struct 'Map' needs type arguments in a type position` |
| 泛型字段导出 | `cd c3 && ./bin/ct build main.ct -o app` | `H.h.ct:1:1: expected a field name` |
| `#define` 不导出 | `cd c1 && ./bin/ct build main.ct -o app` | `use of undeclared identifier 'JSON_TAG_NUM'` |
| `pub enum` 可导出 | `cd c1 && ./bin/ct build main.ct -o app2 && ./app2` | `2` |
| `own` 工厂 | `./bin/ct p1b_own.ct -o p1b.c` | `'own' requires a malloc or calloc initialiser` |
| `own` 返回类型 | `./bin/ct p12.ct -o p12.c && cc p12.c` | `unknown type name 'own'` |
| 同单元胶水 | `grep -A3 JsonDoc_Drop_drop p6b.c` | 空体 `(void)_self;` |
| 跨单元 Drop | `cd dropkg && ./bin/ct build src/main.ct -o app && ./app` | 只输出 `done`，无 `[lib]` |
| 指针字段胶水 | `./bin/ct p23.ct -o p23.c` | `JsonRef_Drop_drop(&_self->p);`（类型错乱），`Map` 字段忽略 |
| 三重载 | `./bin/ct p2b.ct -o p2b.c && cc -c p2b.c` | `conflicting types for 'json_encode'` |
| `Vec::get` | `./bin/ct p16.ct -o p16.c && cc p16.c` | 指针接值类型错误 |
| 字段链调用 | `./bin/ct p14.ct -o p14.c` | `cannot resolve the method trait` |
| 下标 | `./bin/ct p8.ct -o p8.c && cc p8.c` | `array subscript is not an integer` |
| 自动转换 | `cd pkg && ./bin/ct build src/main2.ct -o app3 && ./app3` | `incompatible pointer types` warning + 运行输出乱码 |
| `map trait` 可行形态 | `cd pkg && ./bin/ct build src/main.ct -o app4 && ./app4` | `to_str=0x0 to_int=8080` |
| 数字精度 | `./bin/ct p9.ct -o p9.c && cc p9.c -o p9 && ./p9` | `9007199254740992` / `inf` / `int_cast=207049388` |
| NUL 键碰撞 | `./bin/ct p10.ct -o p10.c && cc p10.c -o p10 && ./p10` | `len=1`，`k1=2 k2=2` |
| Map 值共享指针 | `./bin/ct p20.ct -o p20.c && cc p20.c -o p20 && ./p20` | `same_ptr=1` |
| Map 缺键 / Vec 越界 | `./bin/ct p24.ct -o p24.c && cc p24.c -o p24 && ./p24` | `map_missing=0x0`，`vec_oob_tag=0` |
| RILL 语法 | `./bin/ct p11.ct -o p11.c` | `expected an expression` |
| 16 字节 | `./bin/ct p18.ct -o p18.c && cc p18.c -o p18 && ./p18` | `sizeof=16` |
| golden | `./bin/ct json.ct -o json.c && cc json.c -o jsongold && ./jsongold` | 125 ok / 20 errors / GOLDEN-MATCH |
| 递归深度 | `p15c`（100k）/ `p15b`（1M） | `max=100000` rc=0；1M `rc=139` |
