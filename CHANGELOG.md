# Changelog

项目产品版本见 `ct.pkg#version`。本文件按生成块 §6.7 记录版本：`MINOR` 与 phase 同步，`PATCH` 与 fix 同步；fix 不打 tag，phase 收口时打 annotated tag。

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
