# ct-json 需求规约

> 状态：需求层梳理完成，**未立项**。
> 依据：本仓 `json.ct`（2,286 行）、`json.expected.out`（135 行）、`README.md`、`DECISIONS.md`、`ct.pkg`、`LICENSE`；外部只读取证：`ct-lang/docs/proposals/json-package-refactor.md`、`ct-lang/lib/std/Vec.h.ct`、`ct-lang/docs/bindings-and-patterns.md`、`ct-lang/LICENSE.EXCEPTION`、`ct-lang/docs/roadmap.md`。
> 边界：本文只做需求层判定，不含设计选型、实现代码、phase 卡、roadmap、版本与发布动作；不改 `ct-lang`，不改许可文件。
> 口径优先级：用户给定的职责定位（decode / encode，decode 结果落到原生 `Map` / `Vec`）> 现有代码事实 > 既有文档。三者冲突逐条列在 §5，不静默取舍。

## 0 阅读约定

- 需求编号：`R-<组>-<序号>`，组为 A（解码）、B（编码）、C（错误与边界）、D（数据模型与互操作）、E（工程与交付）。
- 状态只取五值：
  - **已满足**：现有实现与测试已覆盖，判据可直接复用；
  - **需新增**：现有实现没有该能力，但不需要改 CT 语言；
  - **需变更**：现有行为存在但与目标口径冲突，需要改实现并重生成 golden；
  - **待确认**：判据依赖 Q 项裁定，裁定前不写死期望值；
  - **不做**：明确列入非目标（§6）。
- 判据只接受两类：**可执行**（给定输入 → 期望输出，可用用例断言）或**可核对**（可逐条人工/脚本比对）。**“能编译通过”不作为任何条目的判据。**
- 每条现状结论必须带 `文件:行号`；外部仓库结论同样带路径与行号。
- 术语：
  - **视图**：`JsonView {start, len}`，指向调用方文本的字节区间，零分配、只读；
  - **追写器**：`JsonOut`，向调用方缓冲区追加 JSON 字节；
  - **原生容器**：CT 内建 `Map<K,V>` / `Vec<T>`（`ct-lang/lib/std/Vec.h.ct:37-54`）；
  - **树模型**：decode 后把对象落成 `Map`、数组落成 `Vec`、标量落成带 tag 的值；
  - **MISSING**：`JsonView.start == -1` 的“未命中”视图（`json.ct:920-926`）。

## 1 一句话需求

把一段已在内存里的 JSON 字节严格校验后，既能暴露为零分配的只读视图，也能解码成 CT 原生 `Map` / `Vec` 容器；两种模型都能无损编码回 JSON 字节。错误以稳定错误码 + 字节偏移 + 1-based 行列报告。不引入自造 DOM、流式解析、注释与自定义序列化钩子。

> 注：两种模型是并存还是二选一，取决于 Q-01；在 Q-01 裁定前，D 组条目不进入实现排期。

## 2 使用边界

| 角色 | 说明 |
| --- | --- |
| 上游 | 整段已在内存的字节（`const char *` + `int len`）；不负责网络、文件、分片、编码转换 |
| 下游 | 只读视图 API（配置读取、字段探测）；树模型 API（需要遍历/改写/跨模块传递的场景）；`JsonOut` 追写器 |
| 不属于本包 | HTTP / SSE 传输、文件读取、schema 校验、业务语义、日志格式化、数据库映射、JSON Patch |

## 3 能力现状清单

### 3.1 读取 / 解码

| 能力 | 现状证据 | 边界与已知缺口 |
| --- | --- | --- |
| 全量校验 + 根视图 | `json.ct:1590-1623`；`json.ct:1654-1659` | 空输入 / `NULL` → `JSON_ERR_EOF`；尾随非空白 → `JSON_ERR_TRAILING`；失败后 `root()` 为 MISSING |
| 嵌套对象 / 数组 | `json.ct:317-431`；`json.ct:68`、`443-445` | 递归下降；默认 64 层容器；65 层报 `JSON_ERR_DEPTH`（`json.ct:2249-2250`）；`depth_limit` 可被调用方调高，无硬上限 |
| 对象键查找 | `json.ct:337-350`、`530-551`、`1010-1027` | 键必须双引号；键按解码后内容比较（`"a\u0062"` 可用 `"ab"` 命中）；重复键 **last-wins** |
| 数组下标 | `json.ct:1084-1114`、`1684-1692` | 0-based；负下标与越界都返回 MISSING；对象上调用 `at` 报 `JSON_READ_KIND` |
| 字符串解码 | `json.ct:193-264`、`1176-1205` | 支持 `\" \\ \/ \b \f \n \r \t`、`\uXXXX`、代理对；拒绝 <0x20 控制字节、坏转义、孤立代理；**不校验 UTF-8**，≥0x80 原样透传；`cap=0` 量长度 |
| 整数读取 | `json.ct:1234-1283` | 只接受纯整数字面量；int64 边界精确；`1.0` / `1e3` → `JSON_READ_INTEGER`；越界 → `JSON_READ_RANGE` |
| 实数读取 | `json.ct:1284-1383` | 接受任意数字词法；最多 19 位有效数字，指数钳在 ±400；不用 `strtod`；末位可能与正确舍入不同；`1e999` → `JSON_READ_RANGE`，`1e-400` → 0.0 |
| 布尔 / null | `json.ct:1403-1533` | `true` / `false` → 1 / 0；`null` 只能靠 `kind()` 判别；`as_bool(null)` 报 `JSON_READ_KIND` |
| 原始字节访问 | `json.ct:1725-1740` | `offset_of` / `len_of` 返回原词区间；字符串的 `len_of` 含两侧引号 |
| 子树搬运 | `json.ct:928-937`、`1744-1751` | `emit` 按原字节复制，不重排、不转义；要求追写器当前处于可写值位置 |
| 错误定位 | `json.ct:1624-1653` | 一个错误码 + 字节偏移；行列按需扫描，1-based，列按字节计 |
| 访问器错误 | `json.ct:56-60`、`1577-1584`、`1741-1743` | `JSON_READ_*` 每次访问器调用重置；parse 错误是 sticky，二者分离 |
| 原生容器树 | 全文无 `malloc/free/realloc/calloc`；`README.md:93-95`、`108-110`；`DECISIONS.md:14-23`、`69-75` | **当前完全不产出 `Map` / `Vec`**；decode 结果是字节区间，不是容器 |
| UTF-8 校验 / BOM | `json.ct:193-211`；`DECISIONS.md:99-106` | 不校验输入 UTF-8；BOM `EF BB BF` 被当作非法字符，由调用方剥离 |
| 流式 / 注释 | `json.ct:1590-1623`；`README.md:112-117` | 一次性整段校验，无增量/SAX；严格 RFC 8259，不接受注释、尾逗号、`NaN` |

### 3.2 写入 / 编码

| 能力 | 现状证据 | 边界与已知缺口 |
| --- | --- | --- |
| 追写器状态机 | `json.ct:92-101`、`658-704`、`755-795` | 单根值；对象内 `key` 后必须跟值；`end` 必须配对；嵌套栈固定 64 层（`JSON_OUT_DEPTH`） |
| 字符串转义 | `json.ct:706-735` | `"` / `\` 反斜杠转义；<0x20 用 `\b \f \n \r \t` 或 `\u00XX`；≥0x80 原样输出 |
| 整数输出 | `json.ct:806-816` | `%lld`，int64 全范围 |
| 实数输出 | `json.ct:817-831` | `%.17g`；NaN / 超出 `DBL_MAX` → `JSON_EMIT_FINITE`；小数点是 locale 相关（程序未调 `setlocale`，默认 C locale） |
| 布尔 / null 输出 | `json.ct:832-851` | 固定 `true` / `false` / `null` |
| 长度测量 | `json.ct:741-748`、`852-866` | `begin(buf, 0)` 只量长度；`finish` 返回所需长度并 NUL 结尾；**缓冲不足时静默截断**，无错误码 |
| 含 NUL 的字符串 | `json.ct:711` | `jw_escaped` 以 `'\0'` 为终止符；`\u0000` 解码结果写回时被截断；无 `string_len` / `key_len` |
| 原生容器编码 | 全文无递归编码入口 | 调用方必须手写 `object()` / `key()` / `string()` 逐字段遍历；`emit` 只能原样搬运已解析子树 |
| 美化 / 排序 | `README.md:108-110` | 无 pretty printer，无键排序，无缩进配置 |

### 3.3 测试与交付现状

| 项 | 现状 |
| --- | --- |
| 形态 | 单文件 `json.ct`，库 + demo + 自测同一个 `main`（`json.ct:2275-2286`）；全部符号 `static`（`README.md:145-146`），无 `.h.ct` / `.m.ct`，消费者只能整体复制 |
| 断言数 | `json.expected.out` 中 125 条 `ok`（`grep -c '^ok '`）+ 20 条错误用例（`json.expected.out:134`）；golden 共 135 行，失败时程序非零退出（`json.ct:2280-2285`） |
| 覆盖 | demo、reader、writer、errors 四段；含嵌套、空容器、重复键、转义键、int64 边界、实数上溢/下溢、64/65 层、20 条错误码+偏移+行列、emit 往返 |
| 未覆盖 | 原生 `Map`/`Vec`、UTF-8 strict、实数正确舍入、深度硬上限、大数组性能、输出截断错误、含 NUL 往返、可 `import` 形态、ASan/LSan、fuzz |
| 包声明 | `ct.pkg`：`name=json`、`version=0.1.0`、`licence=GPL-3.0-only`，**无 `requires`**；`json.ct:1` 另写 `//@ct-requires: ct-ast` |
| 许可文件 | `LICENSE:1-3` 是 GPLv3 全文；上游来源 `DECISIONS.md:3` 写明“原 `examples/json/`”，而 `ct-lang/LICENSE.EXCEPTION:28-46` 写明 `examples/` 全部按 MIT 授权 |
| 门禁 | 仓内无 `tools/check.sh`、无 CI、无 `tests/`；验收只有“编译后跑 main 并 diff golden” |

### 3.4 现状结论

现有实现是一个**成熟度较高的零分配只读视图 + 追写器**，RFC 8259 词法严格、错误定位完整、自测密度高；但它**不是**“decode 到原生 `Map`/`Vec`”的实现，也没有“从 `Map`/`Vec` 直接 encode”的入口。§4 的 D 组与 B-06 是本次需求的主要新增面，A-08～A-11、B-04～B-05 是已知生产缺口。

## 4 需求条目

### 4.1 A 组：解码

| 编号 | 需求（要解决的问题） | 验收判据 | 状态 | 依据 / 阻塞 |
| --- | --- | --- | --- | --- |
| R-A-01 | 整段输入必须一次校验通过才产出根视图；空输入、纯空白、尾随数据各有确定错误 | ① `""` → rc=0、`JSON_ERR_EOF`、offset 0；② `" \n\t "` → rc=0、`JSON_ERR_EOF`；③ `"{} {}"` → `JSON_ERR_TRAILING`、offset 3；④ 失败后 `kind(root)` 为 `JSON_MISSING` | 已满足 | `json.ct:1590-1623`、`1654-1659`；`json.expected.out:8-13`、`98-118` |
| R-A-02 | 任意嵌套对象/数组可解析；空容器计数为 0；默认深度边界固定 | ① 现有 edge 文档 `root count=6`、空对象/空数组 `count=0`；② 64 层数组 rc=1；③ 65 层 rc=0 且 `JSON_ERR_DEPTH`、offset 64 | 已满足 | `json.ct:317-431`、`2249-2250`；`json.expected.out:14-24` |
| R-A-03 | 字符串 8 种转义 + `\uXXXX` + 代理对解码为 UTF-8；短缓冲按 `snprintf` 语义 | ① `k_escape_text` 解码长度 22；② `\u0041`→`A`、`\u00e9`→`C3 A9`、`\u20ac`→`E2 82 AC`、`\ud83d\ude00`→`F0 9F 98 80`；③ `cap=5` 返回 22 且 `strlen=4`；④ 孤立代理、坏 `\u`、未知转义、<0x20 控制字节各报对应码 | 已满足 | `json.ct:193-264`、`1176-1205`、`1956-1979`；`json.ct:2163-2193` |
| R-A-04 | 数字词法严格按 RFC 8259；整数 int64 精确，越界/小数/指数拒绝 | ① `01` / `1.` / `.5` / `+1` / `1e` 的错误码与 offset 逐条等于现有负例；② int64 min/max 精确；③ `9223372036854775808` → `JSON_READ_RANGE`；④ `1.0` / `1e3` 走 `as_int` → `JSON_READ_INTEGER` | 已满足 | `json.ct:267-314`、`1234-1283`；`json.ct:2103-2160` |
| R-A-05 | `true` / `false` / `null` 必须可判别，不得跨类型静默取值 | ① `as_bool(true)=1`、`as_bool(false)=0`；② `kind(null)=JSON_NULL` 且 `as_bool(null)=0` + `JSON_READ_KIND`；③ `as_int(true)` / `as_string(true)` 均失败并报 KIND | 已满足 | `json.ct:1403-1533`；`json.expected.out:23-24` |
| R-A-06 | 重复键、转义键的查找语义固定 | ① `{"dup":1,"dup":2}` → `member("dup")` 得 2；② `"a\u0062":7` 可用 `"ab"` 命中；③ 不存在的键 → MISSING + `JSON_READ_MISSING` | 已满足 | `json.ct:530-551`、`1010-1027`；`json.ct:1901-1919` |
| R-A-07 | 访问器错误必须区分“缺项”“类型不对”“越界/负下标” | ① 缺键 → MISSING + `JSON_READ_MISSING`；② 对象上 `at` → MISSING + `JSON_READ_KIND`；③ 数组负下标 → MISSING + `JSON_READ_MISSING`；④ 标量上 `count` → -1 + `JSON_READ_KIND` | 已满足 | `json.ct:1084-1114`、`1684-1692`；`json.ct:1917-1925` |
| R-A-08 | 输入 UTF-8 是否校验必须成为可判定开关，而不是隐含行为 | ① 默认（非 strict）保持现状：字符串内的 `0xFF 0xFE` 被接受，≥0x80 原样透传；② strict 模式：非法 UTF-8 序列 rc=0 且报新错误码（建议 `JSON_ERR_UTF8`），合法多字节与 `\u` 解码结果一致；③ 同一合法文档在两种模式下根视图逐字节相同 | 需新增 | `json-package-refactor.md:50`；`json.ct:193-211`；`DECISIONS.md:99-106` |
| R-A-09 | 实数解码必须给出可核对的精度承诺，不能“大致对” | ① 与 `strtod` 对比 10^6 个随机 JSON 数字文本，bit-exact 差异为 0；② `0.30000000000000004` 读回同值；③ `1e-400`→`+0.0`、`-1e-400`→`-0.0`、`1e999`→`JSON_READ_RANGE`；④ 次正规数与 `DBL_MAX` 边界有明确期望 | 需变更 | `json-package-refactor.md:47`；`json.ct:1284-1383`；`README.md:100-104` |
| R-A-10 | 深度上限必须是硬上限，调用方不能靠调大 `depth_limit` 打穿 C 栈 | ① `depth_limit` 超过硬上限（建议 1024）时按硬上限生效；② 10^6 层输入在任意 `depth_limit` 下不崩溃，rc=0 且 `JSON_ERR_DEPTH`；③ 默认 64 层接受、65 层拒绝的行为不变 | 需变更 | `json-package-refactor.md:49`；`json.ct:68`、`443-445` |
| R-A-11 | 大数组/大对象的重复查找不能退化为 O(n²) | ① 20k 元素数组全量遍历 < 10 ms（固定基准机）；② 提供一次性索引/游标后，`at` / `member` 单次查找不重扫整段；③ 仍不调用 `malloc`，索引内存由调用方提供 | 需变更 | `json-package-refactor.md:48`；`json.ct:997-1027`、`1084-1114` |
| R-A-12 | 流首 BOM 与前后空白的行为必须唯一 | ① 默认行为按 Q-05 裁定：剥离 `EF BB BF` 或按非法字符拒绝；② 前后空白允许（现有行为），中间空白不改变语义；③ 视图 API 与树 API 对同一输入结果一致 | 待确认 | `DECISIONS.md:99-106`；`json.ct:193-211` |

### 4.2 B 组：编码

| 编号 | 需求（要解决的问题） | 验收判据 | 状态 | 依据 / 阻塞 |
| --- | --- | --- | --- | --- |
| R-B-01 | 追写器必须在结构错误时立即拒绝，而不是输出非法 JSON | ① 顶层 `key` → `JSON_EMIT_STATE`；② 第二个根值 → STATE；③ pending key 后 `end` → STATE；④ 第 65 层 → `JSON_EMIT_DEPTH` | 已满足 | `json.ct:658-704`、`755-795`、`852-866`；`json.ct:2039-2054` |
| R-B-02 | 字符串必须转义 `"`、`\`、控制字节；非 ASCII 原样输出 | ① `a"b\c\nd\te\x01` → `"a\"b\\c\nd\te\u0001"`；② `0x7F` 原样；③ 输出可被本包 reader 重新解析且解码值相同 | 已满足 | `json.ct:706-735`；`json.ct:2032-2037` |
| R-B-03 | 非有限实数必须拒绝，不得写出 `nan` / `inf` | ① NaN → rc=0 + `JSON_EMIT_FINITE`；② +Inf / -Inf 同；③ 失败后 `length()` 不增加 | 已满足 | `json.ct:817-831`；`json.ct:2055-2059` |
| R-B-04 | 字符串/键必须支持长度参数，保证含 `\u0000` 的值可往返 | ① 解码 `"a\u0000b"` 得 3 字节；② 用 `string_len(buf, 3)` 写出后逐字节等于合法编码；③ `key_len` 同理；④ 现有 NUL 结尾 API 行为不变 | 需新增 | `json-package-refactor.md:51`；`json.ct:711` |
| R-B-05 | 输出缓冲不足必须可判定，不得静默返回半截 JSON | ① `cap` 不足时 `finish()` 返回 -1 且 `error()==JSON_EMIT_TRUNCATED`（新码）；② `cap=0` 仍只量长度并返回所需长度；③ 足够时返回长度且 NUL 结尾；④ 负例：把截断当成功必须变红 | 需新增 | `json-package-refactor.md:52`；`json.ct:852-866` |
| R-B-06 | 必须能把原生 `Map` / `Vec` 树直接编码，不要求调用方手写 object/key 序列 | ① `encode(Map<char*, JsonVal>)` 与手写追写器输出逐字节相同；② `encode(Vec<JsonVal>)` 同；③ 覆盖 3 层嵌套、空对象、空数组、null/true/false；④ 对象键按 Map 插入序输出；⑤ 不支持任意用户自定义类型（见 §6） | 需新增 | `Vec.h.ct:37-54`、`216-344`；`bindings-and-patterns.md:10-79` |
| R-B-07 | 编码必须保证“能出就能读”：输出可被本包解析且值等价 | ① 对 A 组全部正例跑 decode→encode→decode，二次结果与首次相等；② 覆盖含 `\u0000`、代理对、负零、int64 边界；③ 失败时不得留下“看似合法”的半截输出 | 需新增 | 与 R-B-04/05、R-D 联动 |

### 4.3 C 组：错误与边界

| 编号 | 需求（要解决的问题） | 验收判据 | 状态 | 依据 / 阻塞 |
| --- | --- | --- | --- | --- |
| R-C-01 | 解析失败必须给出稳定错误码与位置 | ① 20 条错误用例逐条核对 code / offset / line / column；② 行列 1-based、按字节；③ 失败后 root 为 MISSING | 已满足 | `json.ct:1624-1653`、`2206-2236`；`json.expected.out:98-118` |
| R-C-02 | 解析错误与访问器错误必须分离，访问器不得污染 parse 状态 | ① `read_error` 五值（NONE/KIND/MISSING/RANGE/INTEGER）；② 成功访问后 `JSON_READ_NONE`；③ parse 的 `error()` 不被访问器改写 | 已满足 | `json.ct:56-60`、`1577-1584`、`1741-1743` |
| R-C-03 | 错误码常量、错误文案与未知码行为必须成为公开契约或明确不作契约 | ① `JSON_ERR_*` / `JSON_READ_*` / `JSON_EMIT_*` 数值冻结并写入 README；② `json_message` 文案精确或只保证非空，二选一并测试；③ 未知码返回固定文案 | 待确认 | `json.ct:42-66`、`1756-1783`；`DECISIONS.md:35-43` |
| R-C-04 | 非错误情况不得误报 | ① 重复键、未知成员、空容器、前后空白均 rc=1 且 `error()==JSON_OK`；② 注释、尾逗号、`NaN`、`+1` 必须报错（严格 RFC 8259） | 已满足 | `json.ct:1590-1623`、`2097-2155` |
| R-C-05 | 解码到 `Map`/`Vec` 失败时的部分结果与资源必须可判定 | ① 语法错误：不返回部分树（或明确返回 + 错误位，二选一）并释放已建节点，LSan 0 泄漏；② OOM 与语法错误可区分；③ 深度超限错误码与视图 API 一致；④ 重复键 last-wins 不报错 | 需新增 | 依赖 Q-01 / Q-07 |

### 4.4 D 组：数据模型与互操作

| 编号 | 需求（要解决的问题） | 验收判据 | 状态 | 依据 / 阻塞 |
| --- | --- | --- | --- | --- |
| R-D-01 | decode 的目标模型必须是 CT 原生容器，不得自造 DOM 类 | ① 对象节点类型为 `Map<char*, JsonVal>`，数组为 `Vec<JsonVal>`（或 Q-07 裁定的等价原生容器）；② 遍历 `Map` / `Vec` 即可读到全部键值与元素，无需专用 getter 树；③ 不存在 `JsonNode.new()` / `children()` 一类 DOM API | 需新增 | 用户职责定位；`Vec.h.ct:37-54`；`bindings-and-patterns.md:10-79` |
| R-D-02 | 异构值必须有判别，且判别值能映射到现有 JSON kind | ① `JsonVal` 为 `{tag, union}`，tag 覆盖 null/bool/int/double/string/array/object 七类；② 表驱动：7 类输入 → tag 与 payload 断言，且能映射到 `JSON_*` kind；③ `union` 不带 trait（语言限制）；④ 标量节点不额外堆分配 | 需新增 | `language-spec.md:755-777`；`bindings-and-patterns.md:19-28` |
| R-D-03 | 树的所有权与释放规则必须唯一且可验证 | ① README 写明：Map key 不复制、必须活到 map 释放；`JsonVal` 无 `retain`/`release`，`Map`/`Vec` 释放不级联；② 提供 `json_free(JsonVal)` 递归释放；③ ASan/LSan 下构造→释放 0 泄漏；④ 负例：漏释放必须报泄漏 | 需新增 | `Vec.h.ct:53-56`、`187-207`、`517-537`；`bindings-and-patterns.md:53-56` |
| R-D-04 | 只读视图与树模型的关系必须定死 | 口径 A：两者并存，共享同一词法校验，视图为轻量路径；口径 B：树为唯一公开模型，视图降为内部；口径 C：视图为唯一模型（D 组不成立）。验收按裁定：同一输入两 API 的值集合相等，或只有一套公开 API | 待确认 | Q-01；`README.md:91-110`；`DECISIONS.md:14-23`、`69-75` |
| R-D-05 | 数字在树中的落点必须唯一 | ① 无小数/指数且在 int64 范围 → int64；② 含小数/指数或超 int64 → double 或报错（按 Q-04）；③ `-0` 的符号保留或归零需断言；④ `1e999` 行为与视图 API 一致 | 需新增 | Q-04；`json.ct:1234-1383` |
| R-D-06 | 字符串在树中必须保留长度与内嵌 NUL；键的限制必须明确 | ① 值用 `Str`（`{data,len}`）或等价长度前缀类型，`"a\u0000b"` 的 len=3 且字节相等；② 键仍为 `char*`，含 `\u0000` 的键按 Q-05 裁定拒绝或转义；③ 输出时用 R-B-04 的长度 API 往返 | 需新增 | `language-spec.md:2255`；`Vec.h.ct:216-258` |
| R-D-07 | 缺键与 null 值必须可区分 | ① `map.get("absent") == NULL`；② `map.get("k")` 非 NULL 且 `tag==NULL` 表示显式 null；③ 断言两者在读取 API 上不可混淆 | 需新增 | `Vec.h.ct:260-269` |
| R-D-08 | 重复键在树模型中的位置与值必须固定 | ① last-wins；② Map 覆盖原位（首次出现位置）或移到末尾，二选一并断言；③ 与视图 `member` 的 last-wins 一致 | 需新增 | `Vec.h.ct:232-239`；`json.ct:1019-1021` |

### 4.5 E 组：工程与交付

| 编号 | 需求（要解决的问题） | 验收判据 | 状态 | 依据 / 阻塞 |
| --- | --- | --- | --- | --- |
| R-E-01 | 包必须可 `import`，而不是复制 2,286 行含 `main` 的单文件 | ① 拆出 `.h.ct` / `.ct` 后消费者 `import json;` 可编译运行；② 生成头不含 `main`、demo、测试；③ README 给出 import 用法 | 需新增 | `json-package-refactor.md:56-78`；`README.md:145-146` |
| R-E-02 | 公开面必须最小且可枚举；实现细节不得进生成头 | ① 导出符号清单冻结并脚本比对；② 7 个 `Json*Ops` 结构体不出现；③ 公开结构体字段宽度不依赖 `JSON_OUT_DEPTH` 宏，否则消费者报未声明标识符 | 需新增 | `json-package-refactor.md:19-41`、`76`；`json.ct:69`、`99-100`、`899-918` |
| R-E-03 | 许可必须与同批包及上游权利一致，未裁定前不得发布 | ① `ct.pkg#licence`、`LICENSE`、`README` 三处一致；② 许可裁定见 Q-02；③ 静态链入闭源程序的义务在 README 写明（若保留 GPL） | 待确认 | `ct.pkg:5`；`LICENSE:1-3`；`ct-lang/LICENSE.EXCEPTION:28-46`；`ct-sse/LICENSE:1` |
| R-E-04 | 编译器下限与依赖必须声明 | ① `ct.pkg#requires` 非空且与 `//@ct-requires` 一致；② 视图 API 下限 v0.22.0（`loop`）；树 API 下限 v0.30.0（`Vec`/`Map`），用 `Str` 则 v0.36.0；③ 低于下限时 `ct get` 报 `requires` 文案 | 需新增 | `roadmap.md:38,45,52`；`json.ct:24-26` |
| R-E-05 | 每条判据必须可执行并有负例，不能只靠人读文档 | ① 现有 125 条 `ok` + 20 条 errors 保留；② 新增需求每条至少 1 正 1 负；③ 一条命令跑完全部断言，失败输出 R 编号；④ ASan/LSan 覆盖 R-D-03 / R-C-05 | 需新增 | `json.expected.out:134-135`；`json.ct:2275-2286` |
| R-E-06 | README 必须与实现一致，新增模型后不得留旧承诺 | ① 现有“零分配 / O(n) / 精度 / 不校验 UTF-8 / 无 DOM”逐条与代码一致；② 树模型落地后补所有权、性能、内存模型、与视图的分工；③ 删除或改写与 Q-01 冲突的表述 | 已满足 / 需变更 | `README.md:91-117`；`DECISIONS.md:14-23`、`69-75`、`77-88`、`99-106` |

## 5 必须先裁定的冲突（不是语言问题）

| 编号 | 冲突 | 证据 | 影响 | 状态 |
| --- | --- | --- | --- | --- |
| X-01 | **数据模型路线**：需求口述“decode 落到原生 `Map`/`Vec`”，现有实现是零分配只读视图，且既有文档明确“不做 DOM” | 需求侧：本次任务书；现状：`README.md:93-95`、`108-110`，`DECISIONS.md:14-23`、`69-75`；外部决策：`json-package-refactor.md:8-9`（“不实现可变 DOM；需要建树…直接用 cJSON”）、`:82`；`ct-pkg-agent-runtime.md:163`（保持“样例”定位） | 若选树模型：D 组全部成立，但包定位、内存模型、README、`DECISIONS.md`、`ct.pkg` 描述都要改；若选视图：D 组整体作废，B-06 作废，本文降级为“现状需求固化” | **待 Q-01** |
| X-02 | **许可来源不一致**：本包声明 GPL-3.0-only 并附 GPLv3 全文，但代码来自 `ct-lang/examples/json/`，上游明确 `examples/` 为 MIT | `ct.pkg:5`；`LICENSE:1-3`；`DECISIONS.md:3`；`ct-lang/LICENSE.EXCEPTION:28-46`（Copyright (c) 2026 Sam X. Xu） | 改 MIT 有据，但需版权人确认；未裁定前不应发布索引；静态链入闭源 Agent 的义务见 Q-02 | **待 Q-02** |
| X-03 | **包定位不一致**：README 定位“配置/小报文”，外部提案称“迁出 examples 不等于可对外承诺”，本次任务要求“需求先行 + 正式交付” | `README.md:112-117`；`json-package-refactor.md:17`；`ct-pkg-agent-runtime.md:163` | 影响版本承诺（R-E-04）、是否建 CHANGELOG、是否冻结 API；不影响单条实现判据 | **待 Q-06** |

## 6 明确不做（非目标）

以下不进入本包需求；任何实现不得顺手引入：

| 非目标 | 依据 |
| --- | --- |
| 流式 / 增量 / SAX 解析、回调驱动的事件流 | `json-package-refactor.md:83`；`README.md:112-117` |
| 注释、尾逗号、单引号、未加引号键、`NaN` / `Infinity` 字面量 | 严格 RFC 8259；`json.ct:267-314`、`207-224` |
| 可变 DOM：专用 DOM 类、节点 setter、深拷贝 API | `DECISIONS.md:69-75`；`json-package-refactor.md:82`。注意：原生 `Map`/`Vec` 本身的可变性由调用方直接使用，本包不另包一层 DOM |
| 美化输出 / 缩进 / 键排序 / 键去重策略 | `README.md:108-110` |
| JSON Schema 校验、业务类型映射、JSON Patch / Pointer / Path 查询 | 本包只做词法与结构 |
| 自定义序列化钩子、反射、注册类型、`toJSON` 回调 | 用户明确排除；CT 也无运行时反射（见 §7） |
| 任意用户自定义类型的 encode；只承诺 decode 产出的 `JsonVal` 树与显式列出的原生容器类型 | 无运行时反射，泛型入口只能对具体实例具名 |
| 精确十进制 / BigInt / 任意精度算术 | `README.md:100-104` |
| UTF-8 规范化、NFC/NFD、大小写折叠、编码转换 | `DECISIONS.md:99-106` |
| BOM 自动处理（若 Q-05 裁定不做，则明确按非法字符拒绝） | `DECISIONS.md:99-106` |
| 文件 / 网络 / 管道 I/O；多文档 / NDJSON 一次解析 | 只接受整段内存字节 |
| 线程安全、并发解析、可重入 `JsonDoc` | 现有结构体无可变共享状态以外的同步措施；不主张 |
| C ABI 稳定导出 | `json-package-refactor.md:84`（Phase 39 有 `ct build --lib`，但本包不承诺 ABI） |
| 修改 `ct-lang` 编译器、语言关键字、`Vec`/`Map` 语义 | 本次任务边界；§7 结论是硬阻塞 0 |

## 7 CT 能力依赖汇总

| 能力 | 本包用途 | 现状 / 证据 | 阻塞等级 |
| --- | --- | --- | --- |
| `trait` + `impl` + `use Trait` | 现有 `Json` / `JsonWrite` / `JsonValue` 分发 | 已支持（`json.ct:76-135`、`884-918`） | 已支持 |
| `loop(n)`（Phase 22，v0.22.0） | `as_double` 指数缩放 | 已支持（`json.ct:1366-1377`；`roadmap.md:38`） | 已支持 |
| 泛型 struct + `Vec` / `Map`（Phase 29，v0.30.0） | 树模型的对象/数组节点 | 已支持（`Vec.h.ct:37-54`；`roadmap.md:45`） | 已支持 |
| `union` + `int tag` + `Map<char*, struct>` | 异构 JSON 值的官方配方 | 已支持（`language-spec.md:755-777`；`bindings-and-patterns.md:10-79`） | 已支持 |
| `Str` 长度前缀字符串（Phase 36，v0.36.0） | 保留内嵌 NUL 的字符串值 | 已支持（`language-spec.md:2255`；`roadmap.md:52`） | 已支持 |
| 运行时反射 / 任意类型遍历 | 泛型“任意 Map/Vec 直接编码” | 不支持 | **软阻塞**：encode 只对 `Map<char*,JsonVal>` / `Vec<JsonVal>` 等具体实例具名（R-B-06） |
| 方法级可见性 | 让 helper 真正私有 | 不支持 | **软阻塞**：`.ct` 内 `static` 自由函数绕行（R-E-02） |
| 借用检查 | 防止视图/树指针逃逸 | 不支持 | **软阻塞**：契约 + 负例（R-D-03、R-E-05） |

**结论：按本文口径，CT 语言硬阻塞 0 条。** 软阻塞 3 条，均有不改语言的绕行方案。另有 2 条**非语言硬阻塞**：Q-01（数据模型路线）、Q-02（许可），未裁定前 D 组与发布动作不得开工。

## 8 待确认

> 每条写清：现状与可选口径、**不确认会卡住什么**。裁定前按“建议口径”写判据；裁定后只改对应条目。

| 编号 | 待确认项 | 现状与可选口径 | 不确认会卡住什么 |
| --- | --- | --- | --- |
| Q-01 | **数据模型路线**：视图、树、还是两者并存 | 现状：零分配视图（`README.md:93-95`、`DECISIONS.md:14-23`）；任务口述：decode 到原生 `Map`/`Vec`；外部已定：不实现可变 DOM、需要建树用 cJSON（`json-package-refactor.md:8-9`）。口径 A：两者并存（视图保留，新增树 API）；口径 B：树为唯一公开模型；口径 C：视图为唯一模型（撤销 D 组） | **整份 D 组、B-06、R-C-05、R-E-04 的版本下限**；也决定 README / `DECISIONS.md` / `ct.pkg` 描述是否要改写。这是本包最大的范围分歧 |
| Q-02 | **许可**：保持 GPL-3.0-only、改 MIT、还是双许可 | 现状：`ct.pkg:5` + `LICENSE` 均为 GPLv3；上游 `examples/` 为 MIT（`ct-lang/LICENSE.EXCEPTION:28-46`）；同批 `ct-sse` / `ct-fsguard` 为 MIT。口述影响：静态链入闭源 Agent——GPL-3.0 要求整个分发作品按 GPL 开源并提供源码；MIT 仅需保留版权与许可声明；双许可需版权人明确授权。**本文件不改许可文件，只列选项。** | 卡住发布与索引收录（R-E-03）；卡住闭源 Agent 的合规结论；也卡住 README 是否需要写 GPL 义务。版权人确认前不得改 `ct.pkg` 或 `LICENSE` |
| Q-03 | **错误模型**：错误码/位置/文案/部分失败 | 现状：解析错误 = 码 + 字节偏移 + 1-based 行列（`json.ct:1624-1653`）；访问器错误独立五值（`json.ct:56-60`）；文案由 `json_message` 提供，未声明稳定（`json.ct:1756-1783`）。口径 A：码与偏移冻结、文案冻结、树模型失败不返回部分结果；口径 B：码与偏移冻结、文案只保证非空、树模型返回部分结果 + 错误位 | 卡住 R-C-03、R-C-05 的期望值；卡住 golden 是否比对文案；卡住调用方是否需要自行清理部分树 |
| Q-04 | **数字精度承诺** | 整数：int64 精确（`json.ct:1234-1283`）。实数：19 位有效数字、指数钳 ±400、末位可能差（`json.ct:1284-1383`；`README.md:100-104`）。口径 A：实数与 `strtod` 正确舍入一致，超 int64 整数转 double；口径 B：实数保持现状但文档降级，超 int64 整数报 `JSON_READ_RANGE`；口径 C：整数优先、实数只在明确需要时转 | 卡住 R-A-09、R-D-05；卡住 encode 的最短往返文本（R-B-07）；卡住是否引入大整数/正确舍入实现 |
| Q-05 | **Unicode 承诺** | 现状：解码 `\uXXXX` + 代理对；孤立代理拒绝；输入不做 UTF-8 校验；BOM 不剥离；含 NUL 字符串在 writer 处截断（`json.ct:193-264`、`711`）。口径 A：默认宽松 + `strict` 开关校验 UTF-8，BOM 可选剥离；口径 B：始终不校验 UTF-8、BOM 一律拒绝；键含 `\u0000` 一律拒绝（Map key 是 `char*`） | 卡住 R-A-08、R-A-12、R-D-06、R-B-04；卡住“合法输入”的定义与负例集合 |
| Q-06 | **包形态、公开面与版本承诺** | 现状：单文件含 `main`、全 `static`、不可 `import`（`README.md:145-146`）；`ct.pkg` 无 `requires`；外部提案建议拆 5 个单元（`json-package-refactor.md:56-78`）。口径 A：拆单元 + 冻结最小导出面 + `requires`；口径 B：保持单文件复制，只补 `requires` 与文档 | 卡住 R-E-01、R-E-02、R-E-04；卡住消费者能否 `import`；卡住版本号与 CHANGELOG 策略 |
| Q-07 | **树的形状与所有权细节** | 候选：`JsonVal {tag, union{v_int,v_double,v_str,v_vec,v_map,...}}`；对象 `Map<char*, JsonVal>`，数组 `Vec<JsonVal>`；Map key 不复制（`Vec.h.ct:216-258`、`bindings-and-patterns.md:53-56`）；`JsonVal` 无 `retain`/`release`，容器释放不级联 | 卡住 R-D-01～D-03、D-07、D-08 的具体类型与释放函数签名；卡住 ASan/LSan 判据的写法；也卡住递归容器（`Vec<JsonVal>` 内嵌 `JsonVal`）能否直接实例化，需要设计探针 |
| Q-08 | **性能与深度上限目标值** | 现状：深度默认 64、可调高；20k 数组遍历外部实测 1,240 ms（`json-package-refactor.md:48`），本仓未复跑。口径 A：硬上限 1024、20k 遍历 < 10 ms；口径 B：只做防崩硬上限，性能另立需求 | 卡住 R-A-10、R-A-11 的阈值；阈值不同会改变 golden/基准夹具 |
| Q-09 | **编码失败与数字输出** | 现状：缓冲不足静默截断（`json.ct:852-866`）；实数 `%.17g`（`json.ct:817-831`）。口径 A：新增 `JSON_EMIT_TRUNCATED`，实数保持 `%.17g`；口径 B：截断报错 + 最短往返实数文本 | 卡住 R-B-05、R-B-07；也决定是否需要在 C locale 之外做保护 |

## 9 未纳入本文的内容

- 设计选型：`JsonVal` 的具体布局、树/视图是否共享扫描器、索引缓冲形态、错误码新增方式。
- 文件拆分、单元命名、导出符号清单的最终版本：属设计层。
- phase 卡、任务切分、排期、版本号、tag、索引提交与发布：属立项后事项。
- 修改 `ct-lang` 仓库、修改 `Vec`/`Map` 语义、新增语言关键字：不在本次边界。
- 许可变更动作：本文只列选项与影响，不修改 `ct.pkg` / `LICENSE`。
- 外部实测数字（1.9 GB/s、1,240 ms、10^6 样本）来自 `json-package-refactor.md`，本仓**未复跑**，只作为需求阈值来源，不作为现状判据。
