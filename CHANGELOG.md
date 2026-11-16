# Changelog

项目产品版本见 `ct.pkg#version`。本文件按生成块 §6.7 记录版本：`MINOR` 与 phase 同步，`PATCH` 与 fix 同步；fix 不打 tag，phase 收口时打 annotated tag。

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
