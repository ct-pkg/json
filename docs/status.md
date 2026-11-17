# 项目状态与基线

- 纳管基线：`ad5f1dc`（规范 1.15.0 落库提交）

| 项 | 值 |
| --- | --- |
| 当前版本 | `0.6.0`（落点见 `AGENTS.md` 的 `版本落点`） |
| 当前 phase | **PH-6 已收口**（2026-11-17，`v0.6.0`）；roadmap 的 PH-1…PH-6 全部收口 |
| 门禁入口 | `bash tools/check.sh <g0…g9|all>` |
| 消费方式 | `ct get`（store + `ct.lock`，v0.62.0 起无 `vendor/`）；v0.63.2 下 `ct build` 断在 ctc 泛型（JSON-15），GitHub 默认版本落到 v0.1.1（JSON-16） |

## 门禁现状

| 门禁 | 状态 | 说明 |
| --- | --- | --- |
| g0 | 可运行 | 规范块、实例化 8 行、session-map、`ct pkg check`、版本落点 |
| g1 | 可运行 | 需求编号、无待定项、phase 卡十项与冻结摘要（无卡时只报 note） |
| g2 | 可运行 | 验收映射 39 条 R-*、39 个 ACC、34 个公开符号；负例删行/删公开符号即红 |
| g3 | 可运行 | J1 往返用例 + `json.expected.out` + 零警告 |
| g4 | 可运行 | doc-size / snippets / anchors / readme / applies-to / version / tag |
| g5 | 可运行 | 22 个任务红证登记、baseline 祖先、门禁负例覆盖 |
| g6 | 可运行 | issue 状态与证据 |
| g7 | 可运行 | 密钥扫描 + ASan（本平台不支持 `detect_leaks`）；基线自命中已由 JSON-7 修复 |
| g8 | 可运行 | 基线后的版本移动、phase 冻结、收口 tag |
| g9 | 可运行 | 生成块 pin 与主规范一致 |

退出 2 的检查不计入「通过」：它们缺前置产物，补上前不得宣称门禁全绿。

> **工具链告警（2026-11-17）**：当前 `ct v0.63.2`（`~/.local/bin/ct`，mtime 08:04）在
> `src/json.h.ct:86` 报 `expected a field name`；`v0.4.0`、`v0.5.0`、`HEAD` 的干净
> `git archive` 都复现，`g3`/`g4`/`g7` 与消费方 `ct build` 同时红。见 `issues/JSON-15.md`。
