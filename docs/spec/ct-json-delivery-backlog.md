# ct-json 交付待办

> 范围：本仓自己的交付事项——包清单、构建路径、`import` 形态、首个可消费版本，以及后续重构。
> 口径：只写本仓能自行判断的前置条件，不写外部编号、阶段号或版本号。
> 本轮边界：按更正后的前置重判状态，只改文档。不改 `ct.pkg`、不打 tag、不动版本号（当前 `0.1.1`）、不改实现。

## 状态总览

| 事项 | 状态 | 完成度 | 能否立即开工 | 等什么 |
| --- | --- | --- | --- | --- |
| 1. 包清单补发布方与单元根 | `open` | 清单草稿 2 行；验收 0/3 | 能 | 无能力前置；只差提交与验收 |
| 2. 构建路径：第 84 行 `expected a field name` | `open` | 定性完成；收口 0 | 能（文档收口）；改源码不能 | owner 对「修」的含义一句话确认 |
| 3. `import` 统一为 `<包名>::<单元名>` | `open` | 目标已定；验收 0/3 | 能 | 无能力前置；只差 consumer 与文档 |
| 4. 发布首个可消费版本 | `open` | 未开始 | 否 | 第 1、3 项验收通过；tag 前缀待定 |
| 5. 可变 DOM 与 cJSON 边界重构 | `deferred` | 未开始 | 否 | 本仓排期，不是能力阻塞 |

## 本仓的推进判断

前置更正后，原先「等包管理器能力」的判断作废。按事实重排：

- **A（第 2 项：构建路径收口）**：不再等任何能力，只等 owner 对「修」的含义确认。若选「直编不受支持」，一轮文档即可收口；若选「让直编也能编」，才需要改数据结构。
- **B（第 1、3 项：包清单 + `import`）**：两项能力都已具备（安装时记录发布方；清单声明的单元根参与 include 根展开；lock 记录发布方与单元根；构建默认读 lock）。原先「合并成一批避免消费方改两次路径」的理由**不再成立**——能力同时具备，路径本来就只改一次；合并的真正理由改为「同一份清单变更、同一次验收」，避免清单与文档分两次改、留下半新半旧的 `import` 写法。
- **C（第 4 项：首版发布）**：仍排在 B 之后，不需要额外能力。
- **第 5 项**：不排期，与能力无关。

**建议顺序：B → A → C。** B 先做，因为发布方与单元根决定消费方路径，README、`ct.pkg` 注释、`test/pkg/consumer.ct` 会随之改一次；A 再改构建路径说明，避免同一批文件二次编辑。A 与 B 不并行改 README 与 `ct.pkg`。

### 开工顺序与第一步

1. **B 第一步（验证）**：临时改工作区验证 `publisher` + `ns-root` + 保留 `namespace` 的组合能让 `ct get` / `ct install` 发出 `vendor/json/src`，且消费方 `import json::json;` 解析成功；预期 `namespace` 仍需保留（它负责剥包名），`ns-root` 负责单元根。验证通过后一次性提交清单、consumer 与文档，不留中间态。
2. **B 第二步（收口）**：`test/j1_roundtrip.ct`、`test/pkg/consumer.ct` 全绿后，把第 1、3 项标记为完成。
3. **A**：owner 确认后按选定方案收口；选「直编不受支持」时只改文档与构建说明。
4. **C**：A、B 完成后打首个可消费 tag，按第 4 项的规则核对。
5. **第 5 项不推进**，等本仓另排期。

## 1. 包清单补发布方与单元根

- **为什么需要**：同名包会来自不同发布方，消费方的 store 需要能区分；本仓的单元在 `src/` 下，安装后应能按包清单声明的根解析，而不是把目录结构写进消费方源码。
- **要做什么**：`ct.pkg` 增加 `publisher = ct`、`ns-root = src`。
- **能否立即开工**：能。安装时记录发布方、清单声明的单元根参与 include 根展开、lock 记录发布方与单元根、构建默认读 lock——这些都已具备，不再需要等。
- **先做什么**：先做 B 批第一步验证（`publisher` + `ns-root` + 保留 `namespace` 的组合能装能 import），再提交工作区已有的两行，并订正清单头注释。
- **建议顺序**：B 批第一项，与第 3 项同批。
- **验收**：
  1. `ct get <本仓库>` 后，store 记录中发布方为 `ct`；
  2. `ct install` / `ct build` 的 include 根指向 `vendor/json/src`，消费方 `import json::json;` 解析成功（与第 3 项同一验收）；
  3. `test/j1_roundtrip.ct` 与 `test/pkg/consumer.ct` 仍全绿。
- **status**：`open`
- **证据**：工作区 `ct.pkg` 已有这两行未提交改动（见「工作区待决项」）。

## 2. 构建路径：第 84 行 `expected a field name`

- **为什么需要**：有人按 `ctc` 直接编译单元时会失败；必须先定下本仓支持哪条构建路径，否则文档与外部用法会继续分叉。
- **要做什么**：处理 `src/json.h.ct:84` 的 `Map<Str, int> *index;` 在 `ctc` 下报 `expected a field name` 的问题。
- **能否立即开工**：文档收口能立即做；改源码不能，需 owner 先选方案。
- **先做什么**：owner 一句话确认按「直编不受支持」收口（本仓倾向该方案：构建入口本来就该是 `ct build`）。确认后改构建说明并留一条可核对判据。
- **建议顺序**：B 之后，单独一笔文档提交。
- **阻塞**：owner 对「修」的含义裁定，不是能力前置。
- **现状与定性**：该报错只在 `ctc` 直编路径出现，原始输出为 `src/json.h.ct:84:8: error: expected a field name`；同一份代码用 `ct build` 可编（库单元仅缺 `_main`），作为被 `import` 的包单元也可编可跑。最小探针显示 `Map<char *, int>`、`Vec<int>`、`Map<Str, int>` 在 `ctc` 下报同一条错，而 `Str` 字段两种写法都通过——触发条件是**声明里出现泛型实参**，与键类型、`-I`、`namespace`、单元位置无关；`ctc` 同时提示 `-I is ignored by compile mode`。
- **验收**（二选一）：
  - A. 若要让 `ctc` 也能编：`ctc -I src src/json.h.ct` 返回 0，且现有公开 API 与行为不变；
  - B. 若按「直编不受支持」收口：构建说明只允许 `ct build`，并留一条可核对判据（例如构建入口检查）。
- **status**：`open`
- **证据**：`ctc src/json.h.ct -I src` 的原始输出；`ct build src/json.h.ct -I src` 通过。

## 3. `import` 统一为 `<包名>::<单元名>`

- **为什么需要**：消费方不该知道包内目录结构，也不该在源码里写发布方；`import` 只应出现包名与单元名。
- **要做什么**：消费方统一写 `import json::json;`；单元位置由包清单的 `ns-root` 决定。
- **能否立即开工**：能。单元根参与 include 根展开、lock 含单元根、构建默认读 lock 都已具备。
- **先做什么**：与第 1 项同批验证 `import json::json;`，再改 `test/pkg/consumer.ct`、README、规范 §〇、`issues/JSON-4.md`。
- **建议顺序**：B 批，与第 1 项同批。
- **现状**：`ct install` 目前只发 `-I vendor/json`，消费方必须写 `import json::src::json;`；写 `json::json` 会报 `ctc: cannot resolve import 'json/json'`。README「As a package」、规范 §〇、验收记录 §5.3、`issues/JSON-4.md` 记录的都是这一过渡形态。
- **验收**：
  1. 消费方源码只出现 `import json::json;`，不出现 `src` 段、不出现发布方段；
  2. `ct build -I vendor/json/src`（或默认读 lock 的 `ct build`）解析成功，`test/pkg/consumer.ct` 改路径后仍 `consumer fails=0`；
  3. 全仓文档不再把 `json::src::json` 写成推荐写法。
- **status**：`open`
- **证据**：`ctc: cannot resolve import 'json/json'`（当前）；`ctc: cannot resolve import 'json/src/json'`（无 `namespace` 键时）。

## 4. 发布首个可消费版本

- **为什么需要**：只有打出版本，第三方才能按固定版本安装并复现验收；tag 也是「装完可用」的唯一外部锚点。
- **要做什么**：在第 1、3 项验收通过后，打首个可消费版本 tag。
- **能否立即开工**：否，等第 1、3 项验收。
- **先做什么**：先定 tag 前缀（`v0.1.1` 或 `0.1.1`）；B 完成后再打。
- **建议顺序**：C，排最后。
- **规则**：annotated tag；从默认分支可达；tag 名与 `ct.pkg` 的 `version` 一致（当前 `0.1.1` → `v0.1.1`，前缀以本仓发布约定为准）。
- **验收**：
  1. `git cat-file -t <tag>` 输出 `tag`（annotated）；
  2. `git merge-base --is-ancestor <tag> origin/main` 返回 0；
  3. `ct.pkg` 的 `version` 与 tag 去掉前缀后逐字相等。
- **status**：`open`
- **证据**：尚无发布 tag；`version = 0.1.1`。

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

`ct.pkg` 存在**未提交**改动，内容为：

```ini
publisher = ct
ns-root = src
```

- 两条都属于第 1 项；前置已具备，但本轮只做文档，仍**不提交、不丢弃**，保持工作区原样；B 批开工时一次性提交。
- 同样的两行已存在于一个未并入 `main` 的本地提交 `f205c3d`（`chore(pkg): align ct.pkg with shared-store identity`）上，并被本地轻量 tag `backup/pre-s4-rollback` 指向。B 批开工时决定是复用该提交还是按工作区内容重做，本轮不操作。
- 该文件的头部注释仍写 `consumers import json::src::json` 与「`namespace` 键剥首段」，与第 3 项的目标形态不一致；B 批提交时一并订正，本轮不改。
- 当前 `ct.pkg` 同时存在 `namespace = json` 与 `ns-root = src`；按「`namespace` 剥包名、`ns-root` 定单元根」的分工，两者预期并存，由 B 批第一步验证确认。

## 需要 owner 拍板

1. **第 2 项的「修」指什么**：改数据结构以避开泛型字段，还是确认直编不受支持、把 `ct build` 定为唯一入口。本仓倾向后者。
2. **第 5 项的排期**：是否单独立项；若立，可变 DOM 与 cJSON 边界的范围由谁定。
3. **tag 前缀**：`v0.1.1` 还是 `0.1.1`。

## 本仓实际状态

- 版本：`ct.pkg` 的 `version = 0.1.1`（未改动）。
- tag：存在 1 个**本地轻量** tag `backup/pre-s4-rollback`，指向未并入 `main` 的提交 `f205c3d`，属备份用途；它不是发布 tag，也不满足第 4 项的 annotated / 默认分支可达要求。本轮未新建 tag。
- 分支：`main`；本轮提交后推送，推送前先 `git fetch` 确认远端未变，推送后核对 `origin/main` 与本地一致。
- 工作区：仅有 `ct.pkg` 一处未提交改动（见上节）。
- `.git/refs/remotes/origin/main.lock`：登记时**不存在**（0 字节残留未发现），无需删除。
- 本轮提交只含文档，不含 `ct.pkg`、不打 tag。
