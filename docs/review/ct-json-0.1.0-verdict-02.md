# ct-json 0.1.0 评审合论（二）

> 承接 [01](ct-json-0.1.0-verdict-01.md) 的 §4–§8；章节编号不变。

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
