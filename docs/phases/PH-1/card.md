# PH-1 卡：J1 收口——链式访问解禁与 JSON-1/2 收口

- 编号：PH-1
- phase 目录：`docs/phases/PH-1/`
- version-minor：1
- 规范版本：1.15.0
- 状态：in-progress
- criteria-sha256：d92c647b8a1fefce6b4bde713d7ec50627f5f392187d1da8684a48d843dbd3c3
- tasks-sha256：a717981c75ad4916398ce8509cf74e07546901f7fd77140ea86f544bd16ce5cc

## 0. 编号与元信息

| 项 | 值 |
| --- | --- |
| 编号 | PH-1（与目录 `docs/phases/PH-1/` 一致） |
| 对应 roadmap | [roadmap](../planning/roadmap.md) 的 PH-1（别名 J1 收口） |
| 需求 / issue | `JSON-1`、`JSON-2`；残余限制新开 `JSON-5`、`JSON-6` |
| 版本 | 收口时 `ct.pkg#version` 为 `0.1.1`（MINOR=1；PATCH=1 来自 JSON-4 的一次 fix） |
| 不为 | 不改 `src/`；不实现写链、数字下标、属性访问、J4 错误对象；不降级任何需求 |

## 1. 目标

把 CT `v0.62.0` 已支持的三级读链与方法结果链固化进回归用例、样例与文档，收口 `JSON-1`、`JSON-2`，并把仍然失败的写链与临时值位置登记成新 issue。

## 2. 范围

### 2.1 做什么

- 在 `test/j1_roundtrip.ct` 增加三级读链（声明初始化、赋值、return）、下标结果调方法、方法结果链的断言。
- 新增可运行样例 `docs/snippets/chain3.ct`；把已能编译的 `docs/snippets/fail/three_level_chain.ct` 迁出 `fail/`。
- 更新 `docs/spec/ct-json-0.1.0.md` §四/§五与 `README.md` 的访问边界。
- `JSON-1` / `JSON-2` 写处置段并置 `fixed`；残余限制开 `JSON-5`（临时值作实参/条件）、`JSON-6`（三级写链）。

### 2.2 不做什么

- 不改 `src/json.h.ct` 的任何行为；本 phase 没有实现提交。
- 不实现 `doc["a"]["b"]["c"] = x`、`v[0]`、`doc.server`、`for x in vec`、`char *` 自动转 `Str`。
- 不把「读链可用」说成「写链可用」；写链仍登记为语言侧依赖。
- 不改已冻结的 0.1.0 验收判据；口径变化只写在 §五「v0.62.0 复评」一节。

## 3. 交付物清单

| 路径 | 内容 |
| --- | --- |
| `test/j1_roundtrip.ct` | 链式读的回归断言 |
| `docs/snippets/chain3.ct` | 三级读链可运行样例 |
| `docs/snippets/README.md` | 样例索引与 `fail/` 迁移说明 |
| `docs/spec/ct-json-0.1.0.md` | §四 J11、§五访问边界更新 |
| `README.md` | 限制一节与实现对齐 |
| `issues/JSON-1.md`、`JSON-2.md` | 处置段与状态 |
| `issues/JSON-5.md`、`JSON-6.md` | 残余限制的新条目 |

## 4. 任务清单

| ID | 交付物 | 提交 | 回滚 | verify | effort | 覆盖 |
| --- | --- | --- | --- | --- | --- | --- |
| T1 | `test/j1_roundtrip.ct` 链式读断言 | `test(json): PH1-T1 链式读回归` | revert 后 g3 仍绿但少 4 条链式断言 | `CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build test/j1_roundtrip.ct -I src -o /tmp/ctjson_p1 && /tmp/ctjson_p1 > /tmp/ctjson_p1.out && grep -c -e '3-level chain' -e 'method-result chain' -e 'method on subscript' /tmp/ctjson_p1.out` | M | E-P1-1 |
| T2 | `docs/snippets/chain3.ct`、`docs/snippets/README.md` | `docs(snippet): PH1-T2 三级读链样例` | revert 后 `chain3.ct` 不存在，E-P1-2 无样例可跑 | `CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build docs/snippets/chain3.ct -I src -o /tmp/chain3 && /tmp/chain3` | S | E-P1-2 |
| T3 | `docs/spec/ct-json-0.1.0.md`、`README.md` | `docs: PH1-T3 访问边界对齐 v0.62.0` | revert 后文档仍把三级链写成不支持 | `grep -q '可用（声明初始化/赋值/return）' docs/spec/ct-json-0.1.0.md` | S | E-P1-3 |
| T4 | `issues/JSON-1.md`、`JSON-2.md`、`JSON-5.md`、`JSON-6.md` | `docs(issues): PH1-T4 链式访问收口` | revert 后 JSON-1/2 仍 open，残余限制无登记 | `bash tools/check.sh g6` | S | E-P1-4 |

## 5. 退出判据（冻结）

| 编号 | 判据 | 核对方式 |
| --- | --- | --- |
| E-P1-1 | 三级读链、下标结果调方法、方法结果链都有回归断言且在 v0.62.0 绿 | `... /tmp/ctjson_p1 > /tmp/ctjson_p1.out && grep -c -e '3-level chain' -e 'method-result chain' -e 'method on subscript' /tmp/ctjson_p1.out` 输出 ≥4；`bash tools/check.sh g3` rc=0 |
| E-P1-2 | `chain3.ct` 可编可跑，输出 `chain3 ok` | `ct build ... && /tmp/chain3` rc=0，末行等于 `chain3 ok` |
| E-P1-3 | 规范 §五把三级读链标为可用，README 不再承诺相反行为 | `grep -q '可用（声明初始化/赋值/return）' docs/spec/ct-json-0.1.0.md` rc=0，且 `! grep -q '三级链.*不支持' README.md` |
| E-P1-4 | 台账闭合：JSON-1/2 `fixed` 带处置段，JSON-5/6 `open` 带复现 | `bash tools/check.sh g6` rc=0；`grep -q '^status: fixed' issues/JSON-1.md issues/JSON-2.md` |
| E-P1-5 | 任务清单每项可独立验收（6.6 T-6） | 逐项贴 T1–T4 的 `verify` 原始输出 |

## 6. 红证方式

- 本 phase 不改 `src/`，没有实现提交，因此不产生 T-7 的 `test 红 → impl` 配对。
- 旧红证：`issues/JSON-1.md`、`issues/JSON-2.md` 保留了 v0.53.0 的原始报错与命令；本 phase 的绿证是同一形态在 v0.62.0 的复跑输出。
- 新 issue `JSON-5` / `JSON-6` 的复现必须在当前 v0.62.0 上实跑并贴原始报错。
- 若后续任务改 `src/`，从该任务起按 T-7 执行，不得沿用本节豁免。

## 7. 依赖

| 类型 | 依赖 | 状态 | 说明 |
| --- | --- | --- | --- |
| 工具链 | CT `v0.62.0` | 已装 | 三级读链/方法结果链/下标结果调方法已实测通过 |
| issue | `JSON-1`、`JSON-2` | open | 本 phase 收口 |
| 外部 | 写链、数字下标、属性访问 | blocked | 不在本 phase，登记为 `JSON-6` / roadmap 语言侧依赖 |

## 8. 已知风险

| # | 风险 | 触发信号 | 处置 |
| --- | --- | --- | --- |
| 1 | 把「读链可用」误写成「链式访问全部可用」 | 文档出现「链式访问已支持」而无位置限定 | 只写「声明初始化/赋值/return」，并保留写链/实参/条件的反例 |
| 2 | 旧 `fail/` 样例迁移后 README 链接失效 | `grep -rn 'fail/three_level_chain'` 仍有引用 | 迁移时同步搜索全仓引用 |
| 3 | 新用例只在单文件路径绿、整包构建红 | `ct build test/j1_roundtrip.ct` 通过但 `ct build` 整包失败 | 以 g3 的整包构建为收口命令 |

## 9. 收口动作

| # | 动作 | 证据 |
| --- | --- | --- |
| 1 | 逐条核对第 5 节，贴 T1–T4 原始输出 | 本卡收口段 |
| 2 | 版本四项核对（6.7 `g4-version`）：`0.1.1`，MINOR=1，PATCH=1（JSON-4 一次 fix） | `ct.pkg`、`issues/JSON-4.md` |
| 3 | 每个 issue 登记唯一去向：JSON-1/2 本 phase 修；JSON-5/6 登记到语言侧 | `issues/` |
| 4 | 打 annotated tag 并推送该 tag（V-7） | `v0.1.1` |
| 5 | 写收口回顾（`lessons` 带 `landing`） | `reviews/closeout-PH-1.md` |
| 6 | 更新 `docs/session-map.md` 与本目录清单 | 同上 |
