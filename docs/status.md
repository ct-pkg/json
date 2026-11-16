# 项目状态与基线

- 纳管基线：`ad5f1dc`（规范 1.15.0 落库提交）

| 项 | 值 |
| --- | --- |
| 当前版本 | `0.1.1`（落点见 `AGENTS.md` 的 `版本落点`） |
| 当前 phase | **PH-2**（需求基线与验收映射）；PH-1 已收口（`v0.1.1`） |
| 门禁入口 | `bash tools/check.sh <g0…g9|all>` |

## 门禁现状

| 门禁 | 状态 | 说明 |
| --- | --- | --- |
| g0 | 可运行 | 规范块、实例化 8 行、session-map、`ct pkg check`、版本落点 |
| g1 | 可运行 | 需求编号、无待定项、phase 卡十项与冻结摘要（无卡时只报 note） |
| g2 | 退出 2 | 归 PH-2：接入 `docs/acceptance-map.md`（R-* → ACC-*）时实现 |
| g3 | 可运行 | J1 往返用例 + `json.expected.out` + 零警告 |
| g4 | 退出 2 | 归 PH-6：snippet / 锚点 / 300 行 / `g4-version` 一并接入；`ct-json-0.1.0.md` 366 行待拆分（backlog #9） |
| g5 | 退出 2 | 归 PH-6：各 phase 的红证先落卡片 / issue，PH-6 统一机器化 |
| g6 | 可运行 | issue 状态与证据 |
| g7 | 可运行 | 密钥扫描 + ASan（本平台不支持 `detect_leaks`）；基线自命中已由 JSON-7 修复 |
| g8 | 可运行 | 基线后的版本移动、phase 冻结、收口 tag |
| g9 | 可运行 | 生成块 pin 与主规范一致 |

退出 2 的检查不计入「通过」：它们缺前置产物，补上前不得宣称门禁全绿。
