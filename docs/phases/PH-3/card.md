# PH-3 卡：函数式路径写入 `json_set`

- 编号：PH-3
- phase 目录：`docs/phases/PH-3/`
- version-minor：3
- 规范版本：1.15.0
- 状态：in-progress
- criteria-sha256：e5c16eec956f0d6e9b1e80abd5310062699c066a44738cd2e4b16d291023a329
- tasks-sha256：efd3b3a0952da031dfa0195f1b80ed11ecb2736870f39eeb639831dce9d4055b

## 0. 编号与元信息

| 项 | 值 |
| --- | --- |
| 编号 | PH-3（与目录 `docs/phases/PH-3/` 一致） |
| 对应 roadmap | [roadmap](../planning/roadmap.md) 的 PH-3（J3 写能力） |
| 需求 / issue | 新增 `R-D-09`（路径写入）；复核 R-D-08、R-D-03 |
| 版本 | 收口时 `ct.pkg#version` 为 `0.3.0`（MINOR=3，PATCH=0） |
| 不为 | 不做三级写链 `a["b"]["c"] = x`（JSON-6 语言层）；不做数组路径下标；不做删除/移动 |

## 1. 目标

新增 `json_set(JsonRef root, Str path, JsonRef value)`：按点分对象路径写入，缺失的中间对象自动创建，类型冲突不改树，值与调用方共享引用。

## 2. 范围

### 2.1 做什么

- 新 API `json_set`：`"a.b.c"` 风格的路径；创建缺失中间对象；覆盖已存在键时保持首次位置（R-D-08）。
- 失败契约：空路径/空段 → `JSON_ERR_RANGE`；根或中间不是对象 → `JSON_ERR_TYPE`；值为空句柄 → `JSON_ERR_TYPE`；分配失败 → `JSON_ERR_MEMORY`。
- 原子性：类型冲突在**不改树**的前提下返回；分配失败允许留下已创建的前缀并返回 MEMORY（文档写明）。
- 所有权：容器 retain 一份，调用方保留自己的引用（与 `JsonRef.set` 一致）。
- 文档：`docs/spec/ct-json-0.1.0.md` §三补签名与语义；`R-D-09` 进验收映射 `ACC-39`。

### 2.2 不做什么

- 不把 `json_set` 做成语言级下标写语法；`a["b"]["c"] = x` 仍登记为 `JSON-6`。
- 不支持数组下标段（`a.0` 当作字面键 `"0"`），数组写仍用 `set_idx` / `push`。
- 不支持转义点号；含 `.` 的键无法用路径写入（可直接用 `set`）。

## 3. 交付物清单

| 路径 | 内容 |
| --- | --- |
| `test/j3_json_set.ct` | 正向、失败契约、所有权、保位断言 |
| `src/json.h.ct` | `json_set` 声明与实现、内部新对象 helper |
| `docs/spec/ct-json-0.1.0.md` | §三公开 API 补 `json_set` |
| `docs/requirements.md` | 新增 `R-D-09`（需新增） |
| `docs/acceptance-map.md` | `ACC-39` 与接口索引 |

## 4. 任务清单

| ID | 交付物 | 提交 | 回滚 | verify | effort | 覆盖 |
| --- | --- | --- | --- | --- | --- | --- |
| T1 | `test/j3_json_set.ct` + `src/json.h.ct` | `test(json): PH3-T1 红` + `feat(json): PH3-T1 json_set`（T-7） | revert 后 `json_set` 不存在，夹具编译失败 | `CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build test/j3_json_set.ct -I src -o /tmp/j3 && /tmp/j3` | M | E-P3-1 |
| T2 | `docs/spec/ct-json-0.1.0.md`、`docs/requirements.md`、`docs/acceptance-map.md` | `docs: PH3-T2 API 入规范与映射` | revert 后 g2 仍 38 条、规范无 json_set | `bash tools/check.sh g2` | S | E-P3-2 |

## 5. 退出判据（冻结）

| 编号 | 判据 | 核对方式 |
| --- | --- | --- |
| E-P3-1 | `json_set` 的正向、失败契约、所有权与保位全部由夹具覆盖并绿 | `CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build test/j3_json_set.ct -I src -o /tmp/j3 && /tmp/j3` rc=0，末行 `all checks passed` |
| E-P3-2 | `json_set` 进入规范与验收映射，g2 覆盖 39 条 R-* | `bash tools/check.sh g2` rc=0，输出 `39 R rows`；`grep -q 'json_set' docs/spec/ct-json-0.1.0.md` |
| E-P3-3 | 任务清单每项可独立验收（6.6 T-6） | 逐项贴 T1–T2 的 `verify` 原始输出 |

## 6. 红证方式

- 基线：`v0.2.0`（`875b0d8`）；T1 的 `test` 提交先落夹具，编译失败或断言失败即红。
- 复跑：`git archive <baseline> | tar -x -C /tmp/ph3-base` 后按项目方式构建，不使用工作树产物。
- 红证由 VERIFY 认定；`json_set` 的实现提交紧随 test 提交。

## 7. 依赖

| 类型 | 依赖 | 状态 | 说明 |
| --- | --- | --- | --- |
| phase | PH-2 | closed | 验收基线与 g2 已就绪 |
| 语言 | 无新增 | — | 只用现有 `Str` / `Map` / 函数 |

## 8. 已知风险

| # | 风险 | 触发信号 | 处置 |
| --- | --- | --- | --- |
| 1 | 路径段构造借用 `Str` 被 Drop 释放 | 运行崩溃 / ASan 报错 | 每段用 `str_from_len` 复制，用完 `release` |
| 2 | 类型冲突前已创建中间对象，树被半改 | 失败后 `obj_len` 变大 | 先做只读校验 pass，再进入创建 pass |
| 3 | 点号键被误当路径 | `"a.b"` 键写不进去 | 文档写明限制；键直接用 `set` |

## 9. 收口动作

| # | 动作 | 证据 |
| --- | --- | --- |
| 1 | 逐条核对第 5 节，贴 T1–T2 原始输出 | 本卡收口段 |
| 2 | 版本四项核对（6.7 `g4-version`）：`0.3.0`，MINOR=3，PATCH=0 | `ct.pkg`、`CHANGELOG.md` |
| 3 | 每个 issue 登记唯一去向 | `issues/` |
| 4 | 打 annotated tag `v0.3.0` 并推送（V-7） | `git cat-file -t v0.3.0` |
| 5 | 写收口回顾（`lessons` 带 `landing`） | `reviews/closeout-PH-3.md` |
| 6 | 更新 `docs/session-map.md` 与本目录清单 | 同上 |
