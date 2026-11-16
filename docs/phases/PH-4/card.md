# PH-4 卡：解码边界（严格 UTF-8、实数溢出、深度与性能复核）

- 编号：PH-4
- phase 目录：`docs/phases/PH-4/`
- version-minor：4
- 规范版本：1.15.0
- 状态：closed
- criteria-sha256：55f8f1dcad4253e79f73090b69e11b589599111794494912ea374ca4a9922f66
- tasks-sha256：eb02202df1568f497aaf5c3608a200e91ebf5796196693627142d2247020bc3c

## 0. 编号与元信息

| 项 | 值 |
| --- | --- |
| 编号 | PH-4（与目录 `docs/phases/PH-4/` 一致） |
| 对应 roadmap | [roadmap](../planning/roadmap.md) 的 PH-4（解码边界） |
| 需求 / issue | R-A-08、R-A-09（JSON-10）、R-A-10、R-A-11、R-A-12；引用 D-002、D-005 |
| 版本 | 收口时 `ct.pkg#version` 为 `0.4.0`（MINOR=4，PATCH=0） |
| 不为 | 不改深度上限 64；不引入游标/索引 API；不做错误 offset（归 PH-5）；不支持 BOM 剥离 |

**补立说明：** 本卡在 T1/T2 的实现提交之后补立（流程偏差，已在收口报告登记）。
任务与判据按已发生的事实写，不追溯改写提交；后续 phase 必须先立卡再实现。

## 1. 目标

补齐解码边界：严格 UTF-8 入口、实数溢出错误、BOM 用例，并用已入库夹具复核深度与性能承诺。

## 2. 范围

### 2.1 做什么

- `json_decode_strict` + `JSON_ERR_UTF8`；宽松入口行为不变（D-002）。
- `json_as_double` 对 `1e999` / `-1e999` 返回 `JSON_ERR_RANGE`，`out` 不变（JSON-10）。
- 精度用例：`0.30000000000000004` bit-exact、`1e-400 → +0.0`。
- BOM 两种模式都拒绝；空白仍允许。
- 深度/性能复核：`test/depth_1m.ct`、`test/perf_20k.ct` 实跑并留证（D-005）。

### 2.2 不做什么

- 不加 `depth_limit` 调高入口；不改 64 层硬上限。
- 不做错误 offset/行列（JSON-11 / PH-5）。
- 不做 BOM 剥离、UTF-8 规范化。

## 3. 交付物清单

| 路径 | 内容 |
| --- | --- |
| `test/j1_roundtrip.ct` | 1e999/-1e999、精度、1e-400 断言 |
| `test/j4_decode.ct` | 严格 UTF-8、BOM、两种模式一致 |
| `src/json.h.ct` | `json_decode_strict`、`j1_utf8_valid`、`json_as_double` 溢出 |
| `docs/spec/ct-json-0.1.0.md` | §3.1 strict 入口与 `JSON_ERR_UTF8` |
| `docs/acceptance-map.md`、`docs/requirements.md` | R-A-08/09/12 状态与证据 |
| `docs/evidence/decode-bounds.md` | 深度/性能/BOM 复核原始输出 |
| `issues/JSON-10.md` | 处置段与 fixed |

## 4. 任务清单

| ID | 交付物 | 提交 | 回滚 | verify | effort | 覆盖 |
| --- | --- | --- | --- | --- | --- | --- |
| T1 | `test/j1_roundtrip.ct` + `src/json.h.ct` | `test 红` + `fix`（T-7，`2b88322`、`a57502b`） | revert 后 1e999 又返回 inf | `CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build test/j1_roundtrip.ct -I src -o /tmp/j1p4 && /tmp/j1p4` | M | E-P4-1 |
| T2 | `test/j4_decode.ct` + `src/json.h.ct` | `test 红` + `feat`（T-7，`d97c790`、`2a0ee7a`） | revert 后 strict 入口不存在 | `CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build test/j4_decode.ct -I src -o /tmp/j4 && /tmp/j4` | M | E-P4-2 |
| T3 | `docs/spec/ct-json-0.1.0.md`、`docs/acceptance-map.md`、`docs/requirements.md`、`issues/JSON-10.md` | `docs: PH4-T3 边界入规范与映射` | 映射仍把 R-A-08/09 标未满足 | `bash tools/check.sh g2` | S | E-P4-3 |
| T4 | `docs/evidence/decode-bounds.md` | `docs(evidence): PH4-T4 边界复核` | 深度/性能无留证 | `bash tools/check.sh g3` | S | E-P4-4 |

## 5. 退出判据（冻结）

| 编号 | 判据 | 核对方式 |
| --- | --- | --- |
| E-P4-1 | 实数溢出与精度：`1e999`/`-1e999` → RANGE 且 out 不变，`1e-400` → 0.0，小数 bit-exact | `ct build test/j1_roundtrip.ct -I src -o /tmp/j1p4 && /tmp/j1p4` rc=0，末行 `all checks passed` |
| E-P4-2 | 严格 UTF-8 与 BOM：非法序列报 `JSON_ERR_UTF8`，BOM 两模式拒绝，合法文档两模式同根 | `ct build test/j4_decode.ct -I src -o /tmp/j4 && /tmp/j4` rc=0，末行 `all checks passed` |
| E-P4-3 | R-A-08/09/12 在映射中标「已满足」并有可执行验收；JSON-10 fixed | `bash tools/check.sh g2` rc=0；`grep -q 'status: fixed' issues/JSON-10.md` |
| E-P4-4 | 深度/性能复核：10^6 层 rc=0、20k 遍历 rc=0，原始输出入库 | `bash tools/check.sh g3` rc=0；`test -f docs/evidence/decode-bounds.md` |
| E-P4-5 | 任务清单每项可独立验收（6.6 T-6） | 逐项贴 T1–T4 的 `verify` 原始输出 |

## 6. 红证方式

- 基线：T1 `e67adc5`、T2 `a57502b`；test 提交分别是 `2b88322`、`d97c790`，实现提交紧随其后。
- T1 红：`1e999 is a range error` 等 3 条失败；T2 红：`call to undeclared function 'json_decode_strict'`。
- 红证由 VERIFY 认定；本卡补立不改变红证事实。

## 7. 依赖

| 类型 | 依赖 | 状态 | 说明 |
| --- | --- | --- | --- |
| phase | PH-2、PH-3 | closed | 基线、映射与写入已就绪 |
| 决策 | D-002、D-005 | accepted | strict/BOM 与深度/性能口径 |

## 8. 已知风险

| # | 风险 | 触发信号 | 处置 |
| --- | --- | --- | --- |
| 1 | bool 的 UTF-8 校验漏掉键 | 键含非法字节仍通过 | 断言覆盖键与值（`j1_string` 两处共用） |
| 2 | 严格模式误伤转义代理对 | 合法 `\ud83d\ude00` 被拒 | 解出后再校验；用例覆盖 |
| 3 | 1e999 修复误伤 1e-400 下溢 | 0.0 被当异常 | 只拒非有限值；用例覆盖 |

## 9. 收口动作

| # | 动作 | 证据 |
| --- | --- | --- |
| 1 | 逐条核对第 5 节，贴 T1–T4 原始输出 | 本卡收口段 |
| 2 | 版本四项核对：`0.4.0`，MINOR=4，PATCH=0 | `ct.pkg`、`CHANGELOG.md` |
| 3 | 每个 issue 登记唯一去向 | `issues/JSON-10.md` |
| 4 | 打 annotated tag `v0.4.0` 并推送（V-7） | `git cat-file -t v0.4.0` |
| 5 | 写收口回顾（`lessons` 带 `landing`） | `reviews/closeout-PH-4.md` |
| 6 | 更新 `docs/session-map.md` 与本目录清单 | 同上 |

## 10. 收口记录（2026-11-17）

- E-P4-1…E-P4-5 逐条通过，原始输出见 [reviews/closeout-PH-4.md](../../../reviews/closeout-PH-4.md)。
- 独立 VERIFY 通过（基线 `36d9cc3`）；F1–F4 已按非阻断项修正（`f38f400`）。
- 版本四项：`ct.pkg#version = 0.4.0`，MINOR=4=PH-4，PATCH=0（JSON-10 属 phase 内修复）。
- JSON-10 本 phase 收口；JSON-11/9 归 PH-5；JSON-3/5/6 语言层。
- tag：`v0.4.0`（annotated），随收口提交创建并推送（6.7 V-7）。
- 流程偏差：本卡在 T1/T2 实现后补立，已在卡内与回顾登记；后续 phase 先立卡。
- 未覆盖：g4/g5 归 PH-6；不宣称全门禁绿。
