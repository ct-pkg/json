# PH-5 卡：编码边界与错误契约

- 编号：PH-5
- phase 目录：`docs/phases/PH-5/`
- version-minor：5
- 规范版本：1.15.0
- 状态：in-progress
- criteria-sha256：10e4a30dfadffa8a386dd89271739dc9771e8f9b279f3cf2a7672ca816749426
- tasks-sha256：77d4f9964d7714a30ee7ab5b7271904b1ad961622ce6e18066d1444e60d6e666

## 0. 编号与元信息

| 项 | 值 |
| --- | --- |
| 编号 | PH-5（与目录 `docs/phases/PH-5/` 一致） |
| 对应 roadmap | [roadmap](../planning/roadmap.md) 的 PH-5（编码边界与错误契约） |
| 需求 / issue | R-B-03（JSON-9）、R-C-01（JSON-11）、R-C-03、R-C-05；回归 R-B-04/07 |
| 版本 | 收口时 `ct.pkg#version` 为 `0.5.0`（MINOR=5，PATCH=0） |
| 不为 | 不做 JsonOut/截断码（D-006）；不做 OOM 故障注入；不改错误码已有数值 |

## 1. 目标

收口编码与错误契约：NaN 必须拒绝、解析错误可定位到字节偏移与行列、错误文案有非空契约、失败不返回部分树。

## 2. 范围

### 2.1 做什么

- `j1_enc_double` 拒绝 NaN（Inf 已拒绝），`json_encode` 返回 `NULL` + `JSON_ERR_RANGE`（JSON-9）。
- 新增 `json_error_offset()` / `json_error_line()` / `json_error_column()`：最近一次 `json_decode*` 失败的 0-based 字节偏移与 1-based 行列（列按字节）；成功时为 0（JSON-11）。
- 新增 `json_message(int)`：已知码返回静态非空文案，未知码返回固定非空文案；调用方不释放（R-C-03）。
- 失败清理：解析失败时 `out` 不动，已建节点释放；用 ASan 跑夹具留证（R-C-05）。
- 文档：规范 §3.1/§3.9、README 错误码表、映射与需求状态。

### 2.2 不做什么

- 不恢复 `JsonOut`、不新增 `JSON_EMIT_TRUNCATED`（D-006）。
- 不做 OOM 与语法错误的运行时区分（分配失败仍按 `j1_alloc` abort）。
- 不冻结错误文案原文，只保证非空。

## 3. 交付物清单

| 路径 | 内容 |
| --- | --- |
| `test/j5_errors.ct` | NaN、偏移/行列、文案、失败清理断言 |
| `src/json.h.ct` | NaN 拒绝、错误位置全局与访问器、`json_message` |
| `docs/spec/ct-json-0.1.0.md` | §3.1 位置/文案、§3.9 编码失败 |
| `docs/acceptance-map.md`、`docs/requirements.md` | R-B-03/R-C-01/R-C-03/R-C-05 状态 |
| `issues/JSON-9.md`、`JSON-11.md` | 处置段与 fixed |
| `docs/evidence/error-contract.md` | ASan 与失败清理原始输出 |

## 4. 任务清单

| ID | 交付物 | 提交 | 回滚 | verify | effort | 覆盖 |
| --- | --- | --- | --- | --- | --- | --- |
| T1 | `test/j5_errors.ct`（NaN 段）+ `src/json.h.ct` | `test 红` + `fix`（T-7） | NaN 又输出 `{"x":nan}` | `CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build test/j5_errors.ct -I src -o /tmp/j5 && /tmp/j5` | S | E-P5-1 |
| T2 | `test/j5_errors.ct`（位置/文案/清理段）+ `src/json.h.ct` | `test 红` + `feat`（T-7） | 错误位置/文案访问器不存在 | 同上 | M | E-P5-2 |
| T3 | `docs/spec/ct-json-0.1.0.md`、`docs/acceptance-map.md`、`docs/requirements.md`、`issues/JSON-9.md`、`issues/JSON-11.md`、`docs/evidence/error-contract.md` | `docs: PH5-T3 错误契约入规范与映射` | 映射仍标未满足 | `bash tools/check.sh g2` | M | E-P5-3 |

## 5. 退出判据（冻结）

| 编号 | 判据 | 核对方式 |
| --- | --- | --- |
| E-P5-1 | NaN 编码返回 `NULL` + `JSON_ERR_RANGE`；Inf 同；合法实数仍可编码 | `ct build test/j5_errors.ct -I src -o /tmp/j5 && /tmp/j5` rc=0，输出含 `nan encode rejected` |
| E-P5-2 | 偏移/行列/文案/失败清理全部由夹具覆盖 | 同上 rc=0，末行 `all checks passed`；ASan 构建运行 0 命中 |
| E-P5-3 | R-B-03/R-C-01/R-C-03/R-C-05 在映射中标「已满足」；JSON-9/11 fixed；g2 39 R / 33 symbols | `bash tools/check.sh g2` rc=0；`grep -q 'status: fixed' issues/JSON-9.md issues/JSON-11.md` |
| E-P5-4 | 任务清单每项可独立验收（6.6 T-6） | 逐项贴 T1–T3 的 `verify` 原始输出 |

## 6. 红证方式

- 基线：`v0.4.0`（`f2a624e`）。
- T1 红：`{"x":nan}` 编码成功；T2 红：`json_error_offset` / `json_message` 未声明（编译失败）。
- 红证由 VERIFY 认定；test 提交是实现提交的父提交。

## 7. 依赖

| 类型 | 依赖 | 状态 | 说明 |
| --- | --- | --- | --- |
| phase | PH-4 | closed | strict/边界已就绪 |
| 决策 | D-001、D-006 | accepted | 错误模型与编码口径 |

## 8. 已知风险

| # | 风险 | 触发信号 | 处置 |
| --- | --- | --- | --- |
| 1 | 行列按字节算，遇多字节字符列数不符合「字符」直觉 | 中文行号对不上 | 文档写明按字节；与 R-C-01 一致 |
| 2 | 错误位置只在 decode 失败时有效，成功后被清零 | 成功后再读得到 0 | 文档写明；夹具覆盖 |
| 3 | 静态文案被调用方 free | 崩溃 | 文档写明不释放；不返回堆指针 |

## 9. 收口动作

| # | 动作 | 证据 |
| --- | --- | --- |
| 1 | 逐条核对第 5 节，贴 T1–T3 原始输出 | 本卡收口段 |
| 2 | 版本四项核对：`0.5.0`，MINOR=5，PATCH=0 | `ct.pkg`、`CHANGELOG.md` |
| 3 | 每个 issue 登记唯一去向 | `issues/JSON-9.md`、`JSON-11.md` |
| 4 | 打 annotated tag `v0.5.0` 并推送（V-7） | `git cat-file -t v0.5.0` |
| 5 | 写收口回顾（`lessons` 带 `landing`） | `reviews/closeout-PH-5.md` |
| 6 | 更新 `docs/session-map.md` 与本目录清单 | 同上 |
