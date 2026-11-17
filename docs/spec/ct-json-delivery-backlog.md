# ct-json 交付待办

> 范围：本仓自己的交付事项——包清单、构建路径、`import` 形态、首个可消费版本，以及后续重构。
> 口径：只写本仓能自行判断的前置条件，不写外部编号、阶段号或版本号。
> 本轮边界：只改消费方式相关文档与台账；版本仍为 `0.6.0`，不改实现、不打新 tag。

## 状态总览

| 事项 | 状态 | 完成度 | 能否立即开工 | 等什么 |
| --- | --- | --- | --- | --- |
| 1. 包清单补发布方与单元根 | `done` | `publisher = ct`、`ns-root = src`；store 记录 `ct/json` | — | 已完成 |
| 2. 构建路径：第 84 行 `expected a field name` | `blocked` | 已定性为 ctc（L0）泛型解析；**store 消费也断在这里** | 否 | 上游 ctc 修泛型，或本包公共头去泛型（JSON-15） |
| 3. `import` 统一为 `<包名>::<单元名>` | `blocked` | 正确形态是 `import json;`；`ct get` 后 `ct build` 断在 ctc | 否 | JSON-15；默认 GitHub 版本还会落到 v0.1.1（JSON-16） |
| 4. 发布首个可消费版本 | `blocked` | tag `v0.1.1`…`v0.6.0` 已有，但「可消费」未成立 | 否 | 第 3 项（JSON-15） |
| 5. 可变 DOM 与 cJSON 边界重构 | `deferred` | 未开始 | 否 | 本仓排期，不是能力阻塞 |

## 本仓的推进判断

前置更正后，原先「等包管理器能力」的判断作废。按事实重排：

- **A（第 2 项：构建路径）**：从「文档二选一」升级为真实阻塞——store 消费也断在 ctc 泛型解析（JSON-15）。
- **B（第 1、3 项：包清单 + `import`）**：清单已完成（`publisher`/`ns-root` 已提交，store 记录 `ct/json`）；import 形态已定为 `import json;`，但编译被 JSON-15 挡住。
- **C（第 4 项：首版发布）**：tag `v0.1.1`…`v0.6.0` 已有；「可消费」未成立，等 JSON-15。
- **第 5 项**：不排期。

**当前顺序：A/B 都卡在 JSON-15。** 先等上游 ctc 修泛型，或单独立项做公共头去泛型重构；在此之前不改推荐写法、不把第 3 项标记完成。

### 开工顺序与第一步

1. **B 第一步（验证）**：实测 `ct get` 的 store 模型：本地路径与 GitHub URL 都写入 `~/.ct/pkg/ct/json/<version>` 与消费方 `ct.lock`（v2），**没有 `vendor/`**；正确 import 是 `import json;`。清单的 `publisher`/`ns-root` 已提交，store 记录为 `ct/json`。
2. **B 第二步（收口）**：`test/pkg/consumer.ct` 在 v0.63.2 上因 ctc 泛型解析失败（JSON-15），第 3 项不能标记完成；等上游修或本包头文件去泛型后再收口。
3. **A**：owner 确认后按选定方案收口；选「直编不受支持」时只改文档与构建说明。
4. **C**：A、B 完成后打首个可消费 tag，按第 4 项的规则核对。
5. **第 5 项不推进**，等本仓另排期。

## 1. 包清单补发布方与单元根

- **为什么需要**：同名包会来自不同发布方，消费方的 store 需要能区分；本仓的单元在 `src/` 下，安装后应能按包清单声明的根解析，而不是把目录结构写进消费方源码。
- **要做什么**：`ct.pkg` 增加 `publisher = ct`、`ns-root = src`。
- **能否立即开工**：已完成。
- **验收（2026-11-17 实测）**：
  1. `ct get /path/to/ct-json` → `installed 1 package(s)`；store 路径 `~/.ct/pkg/ct/json/0.6.0`；
  2. 消费方 `ct.lock` 为 `# ct-lock 2` + `ct/json 0.6.0 dir <path> - src sha256:...`；
  3. GitHub 来源：`ct get https://github.com/ct-pkg/json@0.6.0` 落 `0.6.0`（不带 `@` 会落到 `0.1.1`，JSON-16）。
- **status**：`done`
- **证据**：见 `issues/JSON-4.md`「重新打开」段与 README「安装」。

## 2. 构建路径：第 84 行 `expected a field name`

- **为什么需要**：`ctc`（L0）在消费方编译本包时会失败；必须定下支持哪条构建路径。
- **要做什么**：处理 `src/json.h.ct:86` 的 `Map<Str, int> *index;` 在 ctc 下报 `expected a field name` 的问题。
- **能否立即开工**：否。v0.63.2 下这条错误已经挡住 `ct get` 后的消费方 `ct build`（JSON-15），不再只是「直编」路径的问题。
- **先做什么**：等上游 ctc 支持泛型声明，或本包把公共头的泛型字段改成不透明类型（需要重构，另立项）。
- **建议顺序**：阻塞第 3、4 项。
- **阻塞**：上游 ctc（JSON-15）；本包不改 `ct-lang`。
- **现状与定性**：`ct get` 装到 store 后，消费方 `ct build main.ct`（`import json;`）解析到
  `src/json.h.ct:86`，ctc 报 `expected a field name`，rc=1；本地与 GitHub 来源都一样。
  仓库内 `ct build test/... -I src` 能过，是包自身上下文，不代表第三方可消费。
- **验收**：`ct get` + `ct build main.ct` 返回 0，且 `test/pkg/consumer.ct` 可跑；当前不满足。
- **status**：`blocked`
- **证据**：`issues/JSON-15.md` 的最小复现与原始输出；`issues/JSON-4.md`「重新打开」段。

## 3. `import` 形态

- **为什么需要**：消费方只该写包名，不该知道包内目录结构。
- **正确形态**：`import json;`（store 模型实测；`json::json` 与 `json::src::json` 都不可解析）。
- **能否立即开工**：路径已定，但消费链断在编译（JSON-15），不能标记完成。
- **现状**：
  - `ct get` 写 `~/.ct/pkg/ct/json/<version>` 与消费方 `ct.lock`（v2），没有 `vendor/`；
  - `ct install` 打印 `ct build <unit>.ct -o build`，不再发 `-I vendor/json`；
  - 消费方 `ct build` 在 `src/json.h.ct:86` 被 ctc 泛型解析拦住（JSON-15）；
  - GitHub 不带 `@<version>` 时默认落 `v0.1.1`（JSON-16），必须显式写版本。
- **验收**：
  1. 消费方源码只出现 `import json;`；
  2. `ct get` + `ct install` + `ct build` 返回 0，`test/pkg/consumer.ct` 可跑；
  3. 全仓文档不再把 `-I vendor/json`、`import json::src::json` 写成推荐写法。
- **status**：`blocked`
- **证据**：`issues/JSON-15.md`、`issues/JSON-16.md`；README「安装」与规范 §〇 的实测段。

## 4. 发布首个可消费版本

- **为什么需要**：只有「装完可用」，tag 才是可复现的消费锚点。
- **现状**：annotated tag `v0.1.1`…`v0.6.0` 已有，但「可消费」在 v0.63.2 上不成立（JSON-15）。
- **能否立即开工**：否。
- **规则**：annotated tag；从默认分支可达；tag 名与 `ct.pkg#version` 一致（当前 `0.6.0` → `v0.6.0`）。
- **验收**：第 3 项验收通过后再核 tag 与安装；当前只核到 tag 存在。
- **status**：`blocked`
- **证据**：`git tag -l 'v0.*'`；`issues/JSON-15.md`。

## 5. 可变 DOM 与 cJSON 边界重构（路线图）

- **为什么需要**：当前公开形态是引用计数树加 `JsonRef` 句柄，适合正确性优先的 0.1.x；若后续要走可变 DOM、或把部分编解码边界交给 cJSON 一类实现，需要先定范围与兼容策略。
- **要做什么**：单独立项，评估数据模型、兼容层与迁移成本；不并入包清单或 `import` 形态的对齐工作。
- **能否立即开工**：否，本仓主动不排期，不是能力阻塞。
- **先做什么**：等 0.1.x 稳定后评估是否值得做。
- **建议顺序**：不排期。
- **验收**：形成本仓的重构计划文档（范围、数据模型、兼容策略、迁移与回滚），批准后另开任务；本项本身不以代码或命令验收。
- **status**：`deferred`
- **证据**：本仓尚无重构计划文档。

## 工作区待决项

无。`ct.pkg` 的 `publisher = ct`、`ns-root = src` 已提交；2026-11-17 复核时工作树干净。
