# ct-json 交付待办

> 范围：本仓自己的交付事项——包清单、构建路径、`import` 形态、首个可消费版本，以及后续重构。
> 口径：只写本仓能自行判断的前置条件，不写外部编号、阶段号或版本号。
> 本轮边界：只登记状态。不改 `ct.pkg` 的 `publisher` / `ns-root`，不打 tag，不动版本号（当前 `0.1.1`），不改实现。

## 状态总览

| 事项 | 状态 | 完成度 | 等什么 |
| --- | --- | --- | --- |
| 1. 包清单补发布方与单元根 | `open` | 清单草稿 2 行（未提交）；验收 0/3 | 包管理器安装时能记录发布方，并认包内声明的单元根 |
| 2. 构建路径：第 84 行 `expected a field name` | `open` | 定性完成；修复 0 | owner 先定「修」的含义 |
| 3. `import` 统一为 `<包名>::<单元名>` | `open` | 目标已定；验收 0/3 | 包管理器的 include 根能取到单元根 |
| 4. 发布首个可消费版本 | `open` | 未开始 | 第 1、3 项完成，且构建能默认读 lock |
| 5. 可变 DOM 与 cJSON 边界重构 | `deferred` | 未开始 | owner 排期 |

## 本仓的推进判断

当前不另立阶段卡片：本仓还没有门禁脚本与阶段卡，硬套分期只会多一层空壳。按三个批次推进，每批以可复现的验收收口；批次之间不并行改同一份文件。

| 批次 | 内容 | 现在做不做 | 收口判据 |
| --- | --- | --- | --- |
| A | 第 2 项：构建路径收口 | 等 owner 裁定；裁定后一轮内收口，若选「直编不受支持」则只改文档 | 第 2 项验收 |
| B | 第 1、3 项：包清单 + `import` 形态 | 等包管理器两项能力；到位后合并成一批，避免消费方改两次路径 | 第 1、3 项验收 |
| C | 第 4 项：首版发布 | 批次 B 之后 | tag 三项核对 |
| 待评估 | 第 5 项：重构 | 不排期；等 0.1.x 稳定后再评估是否值得做 | 形成计划文档 |

**下一步只做两件事**：一是等 owner 对第 2 项裁定；二是在包管理器具备「记录发布方」和「认单元根」两项能力后，一次性提交 `ct.pkg` 两行、`test/pkg/consumer.ct` 的 import 路径与相关文档订正。其余事项不提前推进，也不为未落地能力预埋代码。

## 1. 包清单补发布方与单元根

- **为什么需要**：同名包会来自不同发布方，消费方的 store 需要能区分；本仓的单元在 `src/` 下，安装后应能按包清单声明的根解析，而不是把目录结构写进消费方源码。
- **要做什么**：`ct.pkg` 增加 `publisher = ct`、`ns-root = src`。
- **等什么**：包管理器在 `ct get` 时记录并读取 `publisher`，在安装 / 构建时把 `ns-root` 作为 include 根。两点都不具备时，加了键也无法验证，先不提交。
- **验收**：
  1. `ct get <本仓库>` 后，store 记录中发布方为 `ct`；
  2. `ct install` / `ct build` 的 include 根指向 `vendor/json/src`，消费方 `import json::json;` 解析成功（与第 3 项同一验收）；
  3. `test/j1_roundtrip.ct` 与 `test/pkg/consumer.ct` 仍全绿。
- **status**：`open`
- **证据**：工作区 `ct.pkg` 已有这两行未提交改动（见「工作区待决项」）。

## 2. 构建路径：第 84 行 `expected a field name`

- **为什么需要**：有人按 `ctc` 直接编译单元时会失败；必须先定下本仓支持哪条构建路径，否则文档与外部用法会继续分叉。
- **要做什么**：处理 `src/json.h.ct:84` 的 `Map<Str, int> *index;` 在 `ctc` 下报 `expected a field name` 的问题。
- **等什么**：owner 先裁定「修」指改数据结构以避开泛型字段，还是确认直编不受支持、把 `ct build` 定为唯一入口。两条验收不同，未裁定前不动源码。
- **现状与定性**：该报错只在 `ctc` 直编路径出现，原始输出为 `src/json.h.ct:84:8: error: expected a field name`；同一份代码用 `ct build` 可编（库单元仅缺 `_main`），作为被 `import` 的包单元也可编可跑。最小探针显示 `Map<char *, int>`、`Vec<int>`、`Map<Str, int>` 在 `ctc` 下报同一条错，而 `Str` 字段两种写法都通过——触发条件是**声明里出现泛型实参**，与键类型、`-I`、`namespace`、单元位置无关；`ctc` 同时提示 `-I is ignored by compile mode`。
- **验收**（二选一）：
  - A. 若要让 `ctc` 也能编：`ctc -I src src/json.h.ct` 返回 0，且现有公开 API 与行为不变；
  - B. 若按「直编不受支持」收口：构建说明只允许 `ct build`，并留一条可核对判据（例如构建入口检查）。
- **status**：`open`
- **证据**：`ctc src/json.h.ct -I src` 的原始输出；`ct build src/json.h.ct -I src` 通过。

## 3. `import` 统一为 `<包名>::<单元名>`

- **为什么需要**：消费方不该知道包内目录结构，也不该在源码里写发布方；`import` 只应出现包名与单元名。
- **要做什么**：消费方统一写 `import json::json;`；单元位置由包清单的 `ns-root` 决定。
- **等什么**：安装 / 构建时 include 根能取到包清单声明的单元根。
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
- **等什么**：第 1、3 项完成；构建能默认读 lock，保证消费方不靠手工 `-I` 也能验收。
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
- **等什么**：owner 排期；本项不占本轮。
- **验收**：形成本仓的重构计划文档（范围、数据模型、兼容策略、迁移与回滚），批准后另开任务；本项本身不以代码或命令验收。
- **status**：`deferred`
- **证据**：本仓尚无重构计划文档。

## 工作区待决项

`ct.pkg` 存在**未提交**改动，内容为：

```ini
publisher = ct
ns-root = src
```

- 两条都属于第 1 项；前置未具备，按指令**不提交、不丢弃**，保持工作区原样。
- 同样的两行已存在于一个未并入 `main` 的本地提交 `f205c3d`（`chore(pkg): align ct.pkg with shared-store identity`）上，并被本地轻量 tag `backup/pre-s4-rollback` 指向。前置具备后是复用该提交还是重做，由 owner 决定，本轮不操作。
- 该文件的头部注释仍写 `consumers import json::src::json` 与「`namespace` 键剥首段」，与第 3 项的目标形态不一致；待正式提交时一并订正，本轮不改。
- 当前 `ct.pkg` 同时存在 `namespace = json` 与 `ns-root = src`，两者是否并存见下节。

## 需要 owner 拍板

1. **第 2 项的「修」指什么**：改数据结构以避开泛型字段，还是确认直编不受支持、把 `ct build` 定为唯一入口。
2. **`namespace` 与 `ns-root` 是否并存**：若 `ns-root` 已决定单元根，`namespace` 是否删除。
3. **第 5 项的排期**：是否单独立项；若立，可变 DOM 与 cJSON 边界的范围由谁定。
4. **tag 前缀**：`v0.1.1` 还是 `0.1.1`。

## 本仓实际状态

- 版本：`ct.pkg` 的 `version = 0.1.1`（未改动）。
- tag：存在 1 个**本地轻量** tag `backup/pre-s4-rollback`，指向未并入 `main` 的提交 `f205c3d`，属备份用途；它不是发布 tag，也不满足第 4 项的 annotated / 默认分支可达要求。本轮未新建 tag。
- 分支：`main`；本地 `main` 比 `origin/main` 多本次文档提交，按指令未推送。
- 工作区：仅有 `ct.pkg` 一处未提交改动（见上节）。
- `.git/refs/remotes/origin/main.lock`：登记时**不存在**（0 字节残留未发现），无需删除。
- 本轮提交只含文档，不含 `ct.pkg`、不推送、不打 tag。
