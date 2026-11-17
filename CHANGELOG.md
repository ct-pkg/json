# Changelog

项目产品版本见 `ct.pkg#version`。本文件按生成块 §6.7 记录版本：`MINOR` 与 phase 同步，`PATCH` 与 fix 同步；fix 不打 tag，phase 收口时打 annotated tag。

## 0.6.0 — 2026-11-17（PH-6 收口）

### Added

- `g4`：doc-size（≤300 行）、snippets 可编可跑/fail 必失败、相对链接、README 七节、applies-to、CHANGELOG/tag/version 一致性（`e43eaac`）。
- `g5`：22 个任务的逐任务红证登记（`docs/evidence/red-proofs.md`）、baseline 祖先校验、已实现门禁的负例覆盖（`894ade0`）。
- `tools/check-doc-size.sh`、`tools/export-surface.sh`、`docs/api-surface.txt`（41 个公开符号）、`//@ct-requires`（`0227fd8`、`27b9069`）。
- README 重写为树 API（安装/示例/API 索引/限制/版本/许可/applies-to）（`66b0cb2`）。

### Changed

- 规范拆为 `ct-json-0.1.0.md` + `-details.md`；评审合论/反证拆为编号分册 + 索引，全部文档 ≤300 行。
- R-E-02…R-E-06 在验收映射中标「已满足」；R-A-01、R-D-09 一并收口。

### Fixed

- 8 张 phase 卡、roadmap 与 `_template` 的 9 处死链（g4 首次抓出）。

### Known limitations

- g4 只编译 `docs/snippets/` 下的完整程序；文档行内片段由测试覆盖，不逐个编译。
- macOS 无 `detect_leaks`；泄漏以 `leaks --atExit` 单机补测。
- 0.x 不承诺 C ABI；包根迁移不做（D-003）。

## 0.5.0 — 2026-11-17（PH-5 收口）

### Added

- `json_error_offset()` / `json_error_line()` / `json_error_column()`：最近一次解码失败的 0-based 偏移与 1-based 行列（列按字节），成功清零（`4f89a80`）。
- `json_message(int)`：15 个已知错误码的静态非空文案，未知码固定文案，调用方不释放。
- `test/j5_errors.ct`：31 条断言，覆盖 NaN、位置、文案与失败清理（红证 `31a6798`、`f3d37ce`）。

### Fixed

- **JSON-9**：NaN 编码输出 `{"x":nan}`；改为 `NULL` + `JSON_ERR_RANGE`（`fdd1b2c`）。
- **JSON-11**：解析失败只有错误码；补 offset/line/column（`4f89a80`）。
- **JSON-13**：CT v0.63.0 把 `9223372036854775808ULL` 钳成 INT64_MAX，导致 g3 红与 INT64_MIN 误报 RANGE；改用 `+1ULL` 绕行（`deaa657`）。
- **JSON-14**：每个对象泄漏 32B Map 头；`j1_obj_new` 移交 `z.h` 后 0 leaks（`de87c01`）。

### Changed

- 规范 §3.6 补非有限实数拒绝；新增 §3.9 位置与文案契约；R-B-03/R-C-01/R-C-03/R-C-05 在映射中标「已满足」。
- D-001 追加注记：OOM 与语法错误不可区分（分配走 `j1_alloc` abort）。

### Known limitations

- 错误位置只描述最近一次 decode，线程不安全（沿用 `json_last_error` 的全局约定）。
- macOS 无 `detect_leaks`，泄漏检测只有 ASan 非泄漏项。
- `g4` / `g5` 仍退出 2：归 PH-6。

## 0.4.0 — 2026-11-17（PH-4 收口）

### Added

- **`json_decode_strict`** 与 `JSON_ERR_UTF8`（-14）：严格校验字符串值/键的 UTF-8，拒绝 overlong、UTF-8 编码代理、>U+10FFFF 与孤立续字节；宽松入口行为不变（`2a0ee7a`）。
- `test/j4_decode.ct`：16 条断言，覆盖 strict/宽松差异、BOM 拒绝与两模式同根（红证 `d97c790`）。

### Fixed

- **JSON-10**：`json_as_double("1e999")` 返回 `inf` rc=0；改为非有限值返回 `JSON_ERR_RANGE` 且 `out` 不变（红证 `2b88322`，修复 `a57502b`）。

### Changed

- 规范 §3.1 补 strict 入口与 `JSON_ERR_UTF8`；R-A-08/R-A-09 在验收映射中标「已满足」。
- `docs/evidence/decode-bounds.md`：10^6 层、20k 遍历、strict/BOM、精度的原始输出。

### Known limitations

- BOM 一律拒绝，不自动剥离；深度固定 64 层，无调高入口。
- `g4` / `g5` 仍退出 2：归 PH-6。

## 0.3.0 — 2026-11-17（PH-3 收口）

### Added

- **R-D-09 `json_set(root, path, value)`**：点分对象路径写入；缺失中间对象自动创建，覆盖保持首次位置；类型冲突在改动树前校验；容器 retain、调用方保留句柄（`54ec376`）。
- 需求 R-D-09 与验收映射 ACC-39；规范 §3.8（`b6ba7ab`）。
- `test/j3_json_set.ct`：55 条断言，覆盖新建/覆盖/保位、失败契约（含缺失前缀后的畸形路径）、所有权（红证 `b3bd964`、`e7503c8`）。

### Changed

- 规范 §3.2 删除「不能写 `v["a"]["b"]`」的过期句（v0.62.0 读链已可用）。

### Known limitations

- 路径只支持对象键，不支持数组下标段与转义点号；键含 `.` 时用 `set`。
- 三级写链 `a["b"]["c"] = x` 仍属语言层（JSON-6）。
- `g4` / `g5` 仍退出 2：归 PH-6。

## 0.2.0 — 2026-11-17（PH-2 收口）

### Added

- `docs/acceptance-map.md`：38 条 `R-*` 逐条映射到 `ACC-01…ACC-38`，含判定、验收、证据与去向；35 个公开符号（7 类型 + 28 函数/方法）进接口索引（`3806554`、`3d91f91`）。
- `tools/check.sh g2`：校验映射完整性与公开符号覆盖；负例删一行即红（`6780200`）。
- `docs/decisions/D-001…D-006.md`：Q-03/05/06/07/08/09 裁定（`fe6bb5a`）。
- `issues/JSON-9/10/11.md`：NaN 编码、`as_double` 溢出、解析错误无位置（`2b9e9c4`）。
- `test/depth_1m.ct`、`test/perf_20k.ct`：R-A-10/R-A-11 的可执行夹具（`28e97ad`）。

### Changed

- `docs/requirements.md` §3/§4 标注为 0.1.0 视图实现时期的历史判定，当前基线以验收映射为准；R-A-12/R-C-03 状态按 D-002/D-001 更新。
- roadmap 的 PH-4/PH-5 范围补 JSON-10、JSON-9、JSON-11。

### Known limitations

- JSON-9（PH-5）、JSON-10（PH-4）、JSON-11（PH-5）仍 `open`。
- `g4` / `g5` 仍退出 2：归 PH-6。本版不宣称全门禁绿。

## 0.1.3 — 2026-11-17

### Fixed

- **JSON-12**：控制字节转义写成 `\u00` + 4 位，含 U+0000 的值 encode→decode 后从 3 字节变 5 字节；改为 4 位十六进制（`5359fb4`，红证 `d804224`）。

## 0.1.2 — 2026-11-17

### Fixed

- **JSON-8**：`g8` 把 phase 收口的 MINOR 版本移动当成 fix，合法收口被判红；改为按 MINOR/PATCH 分支校验（`7a6c599`）。

## 0.1.1 — 2026-11-17（PH-1 收口）

### Fixed

- **JSON-4**：包无法被 `ct get` / `ct install` 消费。`ct.pkg` 增加 `namespace = json`，消费方 `import json::src::json;` 可解析，`test/pkg/consumer.ct` 从红转绿（`1df313b`）。

### Changed

- **JSON-1 / JSON-2**：CT v0.62.0 放开临时值接收者，三级读链（声明初始化/赋值/return）、下标结果作接收者、方法结果链改为可用；规范 §四/§五与 README 同步，新增可运行样例 `docs/snippets/chain3.ct` 与 `test/j1_roundtrip.ct` 回归断言（`9783f6e`、`8471a5b`、`79d6d25`、`45af73d`）。
- **JSON-7**：g7 密钥扫描不再把负例夹具自身当命中（`171985d`，测试夹具修正，不 +PATCH）。

### Docs

- 规划补齐门禁接入与 Q 项归属：g2 归 PH-2，g4/g5 归 PH-6（`8fb490c`）。
- 台账：JSON-1/2 处置段，JSON-5/6 新立，JSON-7 收口（`1d405a9`）。

### Known limitations

- `JSON-3`（`char *`→`Str` 诊断分级）、`JSON-5`（链式结果作实参/条件/字段）、`JSON-6`（三级写链）、`v[0]` 数字下标仍不可用，均属语言层。
- `g2` / `g4` / `g5` 仍退出 2：g2 归 PH-2，g4/g5 归 PH-6。本版不宣称全门禁绿。

## 0.1.0 — 2026-11-15

- 树模型重写版：`JsonRef` 引用计数句柄、`Str` 键、双轨数字、读 + 写、循环检测（ADR-0001～0007）。
- `test/j1_roundtrip.ct` 与 `json.expected.out` 作为验收驱动；125 条 `ok` + 20 条错误用例。
