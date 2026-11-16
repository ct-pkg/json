# 验收映射（R-* → ACC-*）

- 基线：`src/json.h.ct`（树模型，唯一 import 入口）+ `test/j1_roundtrip.ct`；CT `v0.62.0`；锚点 `v0.2.0`（PH-2 收口）。
- 依据：[docs/requirements.md](requirements.md) 的 38 条 `R-*`、[docs/spec/ct-json-0.1.0.md](spec/ct-json-0.1.0.md)、`docs/decisions/D-001…D-006.md`。
- 旧 `json.ct`（零分配视图 + `JsonOut`）是已废止的 0.1.0 实现，只作 `g3` 的 golden；本表**不**拿它的行号当新基线的证据。
- 判定只取五值：`已满足` / `需新增` / `需变更` / `待确认` / `不做`。`待确认` 在本 phase 收口时必须清零。
- 门禁 `g2` 校验：38 条 `R-*` 全部在表内、每条有唯一 `ACC-*`、有可执行验收与去向、公开 `pub` 符号全部出现在 §3。

## 1. 需求映射

| R | 摘要 | 基线判定 | ACC | 验收方式 | 证据 | 去向 |
| --- | --- | --- | --- | --- | --- | --- |
| R-A-01 | 整段校验；空/空白/尾随有确定错误；失败后根为空 | 需变更 | ACC-01 | `bash tools/check.sh g3` + `probe: json_decode("",0)` 期望 -1 | 探针：空 -1、空白 -1、尾随 -3、失败后 root 空；offset 缺 JSON-11 | PH-5（JSON-11 补 offset） |
| R-A-02 | 嵌套对象/数组；空容器 count=0；默认深度边界 | 已满足 | ACC-02 | `test/j1_roundtrip.ct` 的 `64 levels decode` 与 `65 levels stop at depth 64` | 用例通过；`json_obj_len` / `json_arr_len` 见 access_contract | 本 phase |
| R-A-03 | 字符串 8 种转义、`\uXXXX`、代理对；短缓冲语义 | 已满足 | ACC-03 | `test/j1_roundtrip.ct` 的 `round trip: escapes` 与 `round trip: unicode escapes` | 解码为 UTF-8 并与原文往返；短缓冲语义改为 `json_as_str` 借用+长度（API 改写） | 本 phase |
| R-A-04 | 数字词法严格；int64 精确；小数/指数/越界拒绝 | 已满足 | ACC-04 | `test/j1_roundtrip.ct` 的 `as_int reads an integer literal` + 探针 1.0/1e3/2^63 | 1.0 与 1e3 返回 -11 TYPE，2^63 返回 -12 RANGE（D-001 改写码表） | 本 phase |
| R-A-05 | true/false/null 可判别，不跨类型取值 | 已满足 | ACC-05 | `test/j1_roundtrip.ct` 的 `as_bool reads true` 与 `as_bool on null is a type error` | null 只能靠 tag/is_null 判别 | 本 phase |
| R-A-06 | 重复键 last-wins；转义键可被普通键命中 | 已满足 | ACC-06 | `test/j1_roundtrip.ct` 的 `round trip: duplicate key last wins` 与 `round trip: escaped key` | 键统一 `Str`，按解码后内容比较 | 本 phase |
| R-A-07 | 缺项/类型错/越界可区分 | 已满足 | ACC-07 | `test/j1_roundtrip.ct` 的 `missing key answers an empty handle`、`get_idx(-1) answers an empty handle`、`as_int on an empty handle is a type error` | 空句柄 + `JSON_ERR_TYPE`/`RANGE`（D-001 改写，不恢复 READ_* 五值） | 本 phase |
| R-A-08 | UTF-8 校验是可判定开关 | 已满足 | ACC-08 | `CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build test/j4_decode.ct -I src -o /tmp/j4 && /tmp/j4` | 16 条断言：0xFF/overlong/UTF-8 代理/孤立续字节拒绝，合法 2/4 字节通过，BOM 两模式拒绝 | 本 phase |
| R-A-09 | 实数精度可核对；1e999 等边界有明确期望 | 已满足 | ACC-09 | `CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build test/j1_roundtrip.ct -I src -o /tmp/j1p4 && /tmp/j1p4` | 1e999/-1e999 → RANGE 且 out 不变；0.30000000000000004 bit-exact；1e-400 → 0.0（JSON-10 修复 `a57502b`） | 本 phase |
| R-A-10 | 深度是硬上限，调用方不能打穿 C 栈 | 已满足 | ACC-10 | `CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build test/depth_1m.ct -I src -o /tmp/depth1m && /tmp/depth1m` | 10^6 层返回 -9、root 空；固定 64 无调高入口（D-005） | PH-4（复核） |
| R-A-11 | 大数组/大对象重复查找不退化为 O(n²) | 已满足 | ACC-11 | `CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build test/perf_20k.ct -I src -o /tmp/perf20k && /tmp/perf20k` | 本机多次实测 0.9–2.4 ms（< 10 ms）；数组 O(1) 下标、对象 Map 索引（D-005） | PH-4（复核） |
| R-A-12 | 流首 BOM 与空白行为唯一 | 已满足 | ACC-12 | `ct build test/j4_decode.ct ... && /tmp/j4` | BOM 在宽松/严格两模式都报 -2；前后空白仍允许（D-002，`2a0ee7a`） | 本 phase |
| R-B-01 | 追写器结构错误立即拒绝 | 不做 | ACC-13 | `grep -q 'JsonOut' src/json.h.ct` 期望 1（不存在） | 旧 `JsonOut` 不在包公开面，树编码由 `json_encode` 承担（D-006） | PH-6（文档明确） |
| R-B-02 | 字符串转义 `"`、`\`、控制字节；非 ASCII 原样 | 已满足 | ACC-14 | `test/j1_roundtrip.ct` 的 `round trip: escapes`、`a NUL value round-trips` 与 `a 0x1F value round-trips` | `j1_enc_bytes`；JSON-12 修复后控制字节写 4 位（`5359fb4`） | 本 phase |
| R-B-03 | 非有限实数必须拒绝，不得写出 nan/inf | 已满足 | ACC-15 | `CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build test/j5_errors.ct -I src -o /tmp/j5 && /tmp/j5` | NaN / Inf / -Inf 返回 NULL + JSON_ERR_RANGE，合法 double 仍编码（`fdd1b2c`） | 本 phase |
| R-B-04 | 字符串/键支持长度，含 `\u0000` 可往返 | 已满足 | ACC-16 | `test/j1_roundtrip.ct` 的 `nul_value_contract` 与 `a key with an embedded NUL is data` | 值/键均为 `Str`；NUL 值 encode→decode 保持 3 字节（JSON-12 修复后） | 本 phase |
| R-B-05 | 输出缓冲不足可判定 | 不做 | ACC-17 | `grep -q 'JSON_EMIT_TRUNCATED' src/json.h.ct` 期望 1（不存在） | `json_encode` 分配缓冲返回，没有调用方缓冲可截断（D-006） | PH-6（文档明确） |
| R-B-06 | 原生 Map/Vec 树可直接编码 | 不做 | ACC-18 | `grep -q 'encode(Map' src/json.h.ct` 期望 rc=1 | 树就是 `JsonObj`（Map 索引 + 保序数组）与 `JsonArr` 的组合，编码单入口 `json_encode(JsonRef)`；无独立 Map/Vec 编码入口（D-004/D-006） | PH-6（文档明确） |
| R-B-07 | 能出就能读：编码输出可被本包解析且值等价 | 已满足 | ACC-19 | `test/j1_roundtrip.ct` 的 round trip 全组与 `a NUL value round-trips` | 文本往返 + NUL 值二次解码字节相等（JSON-12 修复后） | 本 phase |
| R-C-01 | 解析失败给出稳定错误码与位置（offset/line/column） | 已满足 | ACC-20 | `CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build test/j5_errors.ct -I src -o /tmp/j5 && /tmp/j5` | `{} {}` → offset 3 / 1:4；缺冒号 → 8 / 2:7；空输入 0 / 1:1；成功清零（`4f89a80`） | 本 phase |
| R-C-02 | 解析错误与访问器错误分离 | 已满足 | ACC-21 | `test/j1_roundtrip.ct` 的 `decode leaves last_error at JSON_OK` + 访问器失败返回码 | 访问器返回 `JSON_ERR_TYPE/RANGE`，不改写 parse 状态（D-001 改写 READ_* 五值） | 本 phase |
| R-C-03 | 错误码常量/文案/未知码成为公开契约或明确不作契约 | 已满足 | ACC-22 | `test/j5_errors.ct` 的 message_contract | 15 个已知码非空静态文案、未知码固定文案；`JsonCode` 数值冻结（`4f89a80`，D-001） | 本 phase |
| R-C-04 | 非错误情况不误报；严格 RFC 8259 | 已满足 | ACC-23 | `bash tools/check.sh g3` 的 error_contract（注释/尾逗号/NaN/+1 报错） | 20 条错误用例逐条核对 code | 本 phase |
| R-C-05 | 解码失败不返回部分树、资源可判定 | 已满足 | ACC-24 | `test/j5_errors.ct` 的 cleanup_contract + ASan | 失败时 out 不动、已建节点释放，ASan 0 命中；OOM 走 `j1_alloc` abort（D-001 注记，平台 LSan 缺口另记） | 本 phase |
| R-D-01 | 树为唯一公开模型 | 已满足 | ACC-25 | `grep -q 'pub struct JsonRef' src/json.h.ct` + `json.h.ct` 模型注释 | ADR-0001；视图仅 `json.ct` 历史文件 | 本 phase |
| R-D-02 | 异构值有 tag 判别，映射到 JSON kind | 已满足 | ACC-26 | `test/j1_roundtrip.ct` 的 `root tag is JSON_TAG_OBJ` 等 | `JsonTag` + 具名 `JsonValue` union | 本 phase |
| R-D-03 | 所有权与释放规则唯一、可验证 | 已满足 | ACC-27 | `test/j1_roundtrip.ct` 的 lifecycle_contract + `bash tools/check.sh g7` 的 ASan | 引用计数；容器显式循环释放 `[0,len)` | 本 phase |
| R-D-04 | 只读视图与树模型关系定死 | 已满足 | ACC-28 | `grep -q 'superseded' README.md` + ADR-0001 | 树为唯一公开模型，视图降级 | 本 phase |
| R-D-05 | 数字在树中落点唯一（原文 / int64 / double） | 已满足 | ACC-29 | `test/j1_roundtrip.ct` 的 `round trip: numbers keep source text` | `num_kind` 三态 + 原文回吐 | 本 phase |
| R-D-06 | 字符串保留长度与内嵌 NUL；键限制明确 | 已满足 | ACC-30 | `test/j1_roundtrip.ct` 的 `a key with an embedded NUL is data` | 值 `Str`；键 `Str` 深拷贝 | 本 phase |
| R-D-07 | 缺键与 null 值可区分 | 已满足 | ACC-31 | `test/j1_roundtrip.ct` 的 `explicit null answers a node` 与 `is_null` | 空句柄 vs tag 0 | 本 phase |
| R-D-08 | 重复键位置与值固定（last-wins，保首位） | 已满足 | ACC-32 | `test/j1_roundtrip.ct` 的 `overwriting keeps the key position` 与 duplicate round trip | `j1_obj_put` 命中即换值、位置不变 | 本 phase |
| R-D-09 | 点分对象路径写入 `json_set` | 需新增 | ACC-39 | `CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build test/j3_json_set.ct -I src -o /tmp/j3 && /tmp/j3` | 35 条断言：新建/覆盖/保位、失败契约、所有权（PH-3） | 本 phase |
| R-E-01 | 包可 import，不需复制单文件 | 已满足 | ACC-33 | `bash tools/check.sh g0` 的 `ct pkg check` + `test/pkg/consumer.ct` | JSON-4 修复；`import json::src::json;` | 本 phase |
| R-E-02 | 公开面最小且可枚举，实现细节不进生成头 | 需变更 | ACC-34 | `grep -c '^pub ' src/json.h.ct` + 导出清单脚本（计划） | 现有 `pub` 清单可枚举；无冻结脚本/清单文件 | PH-6 |
| R-E-03 | 许可与同批包及上游一致 | 需变更 | ACC-35 | `grep -q '^## License' README.md`（计划） | `ct.pkg#licence` 与 `LICENSE` 为 MIT；README 无许可段，三处不一致 | PH-6 |
| R-E-04 | 编译器下限与依赖声明 | 需变更 | ACC-36 | `grep -q 'requires = ct' ct.pkg` + `//@ct-requires` 比对 | `requires = ct >= 0.53.0` 有；`//@ct-requires` 缺 | PH-6 |
| R-E-05 | 每条判据可执行并有负例 | 需新增 | ACC-37 | `bash tools/check.sh g5`（计划） | g5 仍 exit 2；红证散在 issue/卡片 | PH-6 |
| R-E-06 | README 与实现一致，无旧承诺 | 需变更 | ACC-38 | `grep -q 'zero-allocation' README.md` 期望旧段已标注 + `g4-readme`（计划） | README 仍保留已废止视图的大段说明 | PH-6 |

## 2. 统计

| 判定 | 条数 |
| --- | --- |
| 已满足 | 29 |
| 需新增 | 2 |
| 需变更 | 5 |
| 待确认 | 0 |
| 不做 | 3 |
| 合计 | 39 |

## 3. 公开接口索引

`g2` 要求 `src/json.h.ct` 的每个 `pub` 函数/方法名出现在本表。

| 符号 | 类型 | ACC |
| --- | --- | --- |
| `JsonTag` | enum | ACC-26 |
| `JsonCode` | enum | ACC-22 |
| `JsonRef` | struct | ACC-25 |
| `JsonValue` | union | ACC-26 |
| `JsonNode` | struct | ACC-27 |
| `JsonObj` | struct | ACC-31 |
| `JsonArr` | struct | ACC-18 |
| `json_retain` | 函数 | ACC-27 |
| `json_release` | 函数 | ACC-27 |
| `json_free` | 函数 | ACC-27 |
| `json_last_error` | 函数 | ACC-21 |
| `json_decode` | 函数 | ACC-01 |
| `json_decode_strict` | 函数 | ACC-08 |
| `json_encode` | 函数 | ACC-18 |
| `json_tag` | 函数 | ACC-26 |
| `json_is_null` | 函数 | ACC-31 |
| `json_as_bool` | 函数 | ACC-05 |
| `json_as_int` | 函数 | ACC-04 |
| `json_as_double` | 函数 | ACC-09 |
| `json_as_str` | 函数 | ACC-03 |
| `json_obj_len` | 函数 | ACC-02 |
| `json_arr_len` | 函数 | ACC-02 |
| `json_member` | 函数 | ACC-06 |
| `json_obj_key_at` | 函数 | ACC-32 |
| `get` | 方法 | ACC-06 |
| `set` | 方法 | ACC-32 |
| `has` | 方法 | ACC-07 |
| `get_idx` | 方法 | ACC-07 |
| `push` | 方法 | ACC-18 |
| `set_idx` | 方法 | ACC-18 |
| `set_str` | 方法 | ACC-16 |
| `set_int` | 方法 | ACC-29 |
| `set_double` | 方法 | ACC-15 |
| `set_bool` | 方法 | ACC-05 |
| `set_null` | 方法 | ACC-31 |
| `remove` | 方法 | ACC-32 |
| `json_set` | 函数 | ACC-39 |
| `json_error_offset` | 函数 | ACC-20 |
| `json_error_line` | 函数 | ACC-20 |
| `json_error_column` | 函数 | ACC-20 |
| `json_message` | 函数 | ACC-22 |

## 4. 缺口登记

| Issue | 需求 | 现象 | 去向 |
| --- | --- | --- | --- |
| JSON-9 | R-B-03 | `set_double(NaN)` 后 `json_encode` 输出 `{"x":nan}`；已修（`fdd1b2c`） | 已收口 |
| JSON-10 | R-A-09 | `json_as_double("1e999")` 返回 inf 且 rc=0；已修（`a57502b`），期望 `JSON_ERR_RANGE` | 已收口 |
| JSON-11 | R-A-01、R-C-01 | 解析失败只有错误码；已补 offset/line/column（`4f89a80`） | 已收口 |
| JSON-12 | R-B-02、R-B-04、R-B-07 | 控制字节转义写 6 位，含 NUL 的值编码后 3 字节变 5 字节（`5359fb4` 已修） | PH-5（复核回归） |

## 5. 与 roadmap 的对应

| phase | 本表里归它的条目 |
| --- | --- |
| PH-3 | R-D-09（ACC-39）、R-D-08（复核）、R-D-03（证据） |
| PH-4 | R-A-08、R-A-09（JSON-10）、R-A-10、R-A-11（复核 D-005）、R-A-12（补用例） |
| PH-5 | 本 phase 收口 R-A-01、R-B-03（JSON-9）、R-C-01（JSON-11）、R-C-03、R-C-05；R-B-04/R-B-07 已满足 |
| PH-6 | R-B-01、R-B-05、R-B-06（文档明确不做）、R-E-02、R-E-03、R-E-04、R-E-05、R-E-06；R-E-01 已满足，只做复核 |
