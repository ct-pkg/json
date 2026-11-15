# ct-json 包外移入事项（EXT-JSON-01～05）

- 来源：CT 仓移出的包外事项清单（提案 §10 S4，以及已从 CT 删除的 json 重构提案）。自本文件建立之日起，这些事项归本仓自行负责，不再跨仓跟踪。
- 口径：只引用**能力前置**（C1/C2/C3），不引用任何 CT 版本号。
- 本轮边界：**只做认领与状态登记**。不改 `ct.pkg` 的 `publisher` / `ns-root`，不打 tag，不动版本号（当前 `version = 0.1.1`），不改实现。
- 状态词遵循 AGENTS §5.4：`open` / `deferred` / `fixed` / `verified` 等；阻塞原因单独写在 `blocked-by`，不写进 `status`。

## 一、前置能力

| 代号 | 能力 | 影响条目 |
| --- | --- | --- |
| C1 | `ct get` 落 store 并读取 `publisher` | EXT-JSON-01、EXT-JSON-04 |
| C2 | `ns-root` 进入 `-I` | EXT-JSON-01、EXT-JSON-03 |
| C3 | `ct build` 默认读 lock | EXT-JSON-04 |

三项能力当前都未落地。前置未满足时，相关条目只登记、不开工。

## 二、条目

### EXT-JSON-01 `ct.pkg` 补 `publisher` / `ns-root`

- 来源：提案 §10 S4（已移入本仓）。
- 要做什么：`ct.pkg` 增加 `publisher = ct`、`ns-root = src`，使发布方随包落 store，且单元根下移到 `src/`。
- 前置：C1、C2。
- 现状：工作区已有**未提交**的 `ct.pkg` 改动，恰好包含这两行（见 §三 待决项）；按指令保留、不提交、不丢弃。
- 验收（前置落地后）：
  1. `ct get <本仓库>` 后，store 记录中 `publisher` 为 `ct`；
  2. `ct install` / `ct build` 发出 `-I vendor/json/src`，消费方 `import json::json;` 解析成功（与 EXT-JSON-03 同一验收）；
  3. 仓库内既有门禁（`test/j1_roundtrip.ct`、`test/pkg/consumer.ct`）仍全绿。
- status: `open`
- blocked-by: C1、C2
- 证据：`git status --short` 显示 ` M ct.pkg`；文件内已有两行（未提交）。

### EXT-JSON-02 修 `src/json.h.ct:84` 的既有缺陷

- 来源：提案 §10 S4（已移入本仓）；复现与修法都在本仓。
- 要做什么：处理 `src/json.h.ct:84` 的 `Map<Str, int> *index;` 在编译时报 `expected a field name` 的问题。
- 前置：无（不依赖 C1/C2/C3）。
- 现状与定性：该报错只在 `ctc`（L0）直编路径出现，原始输出为 `src/json.h.ct:84:8: error: expected a field name`；同一条代码用 L2 `ct build` 可编（库单元仅缺 `_main`），作为被 import 的包单元也可编可跑。最小探针显示 `Map<char *, int>`、`Vec<int>`、`Map<Str, int>` 在 `ctc` 下报同一条错，而 `Str` 字段两种写法都通过——触发条件是**声明里出现泛型实参**，与键类型、`-I`、namespace、单元位置无关。`ctc` 同时提示 `-I is ignored by compile mode`。
- 验收（二选一，待 owner 裁定后写死）：
  - A. 若按「让 `ctc` 也能编」修：`ctc -I src src/json.h.ct` 返回 0，且不改变现有公开 API 与行为；
  - B. 若按「L0 不是受支持路径」收口：`ct.pkg` 与 README 的构建路径说明保持明确，并用一条可核对判据固定（例如构建入口只允许 `ct build`）。
- status: `open`
- blocked-by: 需 owner 先裁定「修」的含义（见 §四）。
- 证据：`ctc src/json.h.ct -I src` 的原始输出；`ct build src/json.h.ct -I src` 通过。

### EXT-JSON-03 统一 `import` 形态为 `<name>::<Unit>`

- 来源：提案 §10 S4（已移入本仓），SP-012 口径。
- 要做什么：消费方源码统一写 `import json::json;`（包名 + 单元名），**发布方不出现在源码的 import 路径里**；包内单元位置由 `ns-root` 决定。
- 前置：C2。
- 现状：`ct install` 只发 `-I vendor/json`，消费方必须写 `import json::src::json;`；写 `json::json` 会报 `ctc: cannot resolve import 'json/json'`。现有文档（README「As a package」、规范 §〇、验收记录 §5.3、`issues/JSON-4.md`）记录的是这一过渡形态。
- 验收（C2 落地后）：
  1. 消费方源码只出现 `import json::json;`，不出现 `src` 段、不出现发布方段；
  2. `ct build -I vendor/json/src`（或 `ct build` 默认读 lock）解析成功，`test/pkg/consumer.ct` 改路径后仍 `consumer fails=0`；
  3. 全仓文档不再把 `json::src::json` 写成推荐写法。
- status: `open`
- blocked-by: C2
- 证据：`ctc: cannot resolve import 'json/json'`（当前）；`ctc: cannot resolve import 'json/src/json'`（无 `namespace` 键时）。

### EXT-JSON-04 打首个可消费版本 tag

- 来源：提案 §10 S4（已移入本仓）。
- 要做什么：在 EXT-JSON-01～03 验收通过后，打首个可消费版本 tag。
- 前置：C1、C2、C3；EXT-JSON-01、EXT-JSON-03 完成。
- 通用 tag 规则：annotated tag；从默认分支可达；tag 名与 `ct.pkg` 的 `version` 一致（当前 `0.1.1` → `v0.1.1`，具体前缀以本仓发布约定为准）。
- 验收：
  1. `git cat-file -t <tag>` 输出 `tag`（annotated）；
  2. `git merge-base --is-ancestor <tag> origin/main` 返回 0；
  3. `ct.pkg` 的 `version` 与 tag 去掉前缀后逐字相等。
- status: `open`
- blocked-by: C1、C2、C3，以及 EXT-JSON-01、EXT-JSON-03。
- 证据：当前无 tag；`version = 0.1.1`。

### EXT-JSON-05 json 重构计划独立排期

- 来源：CT 侧 json 重构提案（已从 CT 删除）。
- 要做什么：可变 DOM、cJSON 边界等重构单独立项排期；**不属于** `ns-root` 对齐，也不进本轮。
- 前置：无（但与 EXT-JSON-01/03 分开排期）。
- 现状：本仓 0.1.x 的公开形态是引用计数树 + `JsonRef` 句柄；重构只登记，不设计、不动实现。
- 验收：形成独立的重构计划文档（范围、数据模型、兼容策略、迁移与回滚），由 owner 批准后另开任务；本条目本身不以代码或命令验收。
- status: `deferred`
- blocked-by: 无；等 owner 排期。
- 证据：本仓尚无重构计划文档。

## 三、工作区待决项

`ct.pkg` 存在**未提交**改动，内容为：

```ini
publisher = ct
ns-root = src
```

- 两条都属 EXT-JSON-01，但 C1/C2 未落地，按指令**不提交、不丢弃**，保持工作区原样。
- 该文件的头部注释仍写 `consumers import json::src::json` 与「`namespace` 键剥首段」，与 EXT-JSON-03 的目标形态不一致；待 C2 落地、`publisher`/`ns-root` 正式提交时一并订正，本轮不改。
- 当前 `ct.pkg` 同时存在 `namespace = json` 与 `ns-root = src`，两者是否并存见 §四。

## 四、需要 owner 拍板

1. **EXT-JSON-02 的「修」指什么**：改数据结构以避开泛型字段（让 L0 也能编），还是确认 L0 不受支持、把构建入口固定为 `ct build`？两种验收不同，未裁定前不动源码。
2. **`namespace` 与 `ns-root` 是否并存**：C2 落地后若 `ns-root` 已决定单元根，`namespace` 是否删除？这会影响 EXT-JSON-01 的最终清单形态。
3. **EXT-JSON-05 的排期**：是否另开 phase；若开，可变 DOM 与 cJSON 边界的范围由谁定。
4. **tag 前缀**：`v0.1.1` 还是 `0.1.1`（本仓发布约定未写死）。

## 五、登记时的本仓实际状态

- 版本：`ct.pkg` 的 `version = 0.1.1`（未改动）。
- tag：无。
- 分支：`main`；工作区仅有 `ct.pkg` 一处未提交改动。
- `.git/refs/remotes/origin/main.lock`：登记时**不存在**（0 字节残留未发现），无需删除。
- 本轮提交只含文档，不含 `ct.pkg`、不推送、不打 tag。
