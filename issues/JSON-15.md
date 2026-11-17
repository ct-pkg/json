---
id: JSON-15
status: open
priority: P0
owner: 上游 ct（ctc/L0）+ 本包登记
created: 2026-11-17
last-touched: 2026-11-17
block: 上游 ctc（L0）不支持泛型声明；等 ct 修或本包做头文件去泛型重构
evidence: v0.63.2；`ct get` 后消费方 `ct build main.ct`（`import json;`）→ `src/json.h.ct:86:8: error: expected a field name`，rc=1
---

# JSON-15 `ct get` 装完后 `ct build` 仍无法 import：ctc L0 拒绝泛型声明

- 归属：**上游 ct（ctc/L0）**，不是 ct-json 的包清单或路径问题。
- 优先级：P0（`ct get` 消费链在编译阶段断开；JSON-4 在 store 模型下未真正修复）。
- 影响面：任何按 `ct get` + `ct build` 消费本包的第三方工程。
- 关联：`JSON-4`（原「包无法被 `ct get` / `ct install` 消费」）、R-E-01、ACC-33。

## 触发条件

消费方已有 `ct.pkg`，按 store 模型安装并编译一个 `import json;` 的单元。

## 最小复现

```console
$ mkdir /tmp/consumer && cd /tmp/consumer
$ printf 'name = consumer\nversion = 0.1.0\nlicence = MIT\n' > ct.pkg
$ ct get /path/to/ct-json
installed 1 package(s)
$ cat ct.lock
# ct-lock 2
ct/json 0.6.0 dir /path/to/ct-json - src sha256:...
$ cat > main.ct <<'CT'
import json;
int main(void) { return 0; }
CT
$ ct build main.ct -o build
/path/to/store/ct/json/0.6.0/src/json.h.ct:86:8: error: expected a field name
$ echo $?
1
```

GitHub 来源同样复现（`ct get https://github.com/ct-pkg/json@0.6.0` 后 `ct build`）。

## 根因

`src/json.h.ct:86` 的公开结构体字段 `Map<Str, int> *index;`（以及 `Vec` 等泛型声明）
被 ctc（L0）解析为 `expected a field name`。这与 JSON-4 最初记录的上游诊断同源：
`ctc` 不支持带泛型实参的声明；`ct build` 在「包自身工作树内」可用（`-I src` + 包内上下文），
但作为**外部包**被 store 解析时走 ctc，编译失败。

## 期望行为

`ct get` 后消费方 `ct build` 能编译 `import json;`；或 ct 明确报「该包需要 L2 编译器」
并给出可用命令，而不是在包单元内部报字段解析错误。

## 本包绕行

没有不改变公开模型的绕行：

- 仓库内构建（`ct build test/... -I src`）能过，是因为在包自身上下文，不适用于第三方消费方。
- 把 `JsonObj.index` 改成 `void *` 并在实现里转型，可能让公共头避开泛型解析；但需要重构类型与
  所有权，属于新工作项，不在本轮「只改消费方式」范围内。

## 阻塞点

上游 ctc 的泛型声明支持；或本包做「公共头去泛型」重构。二者之前，R-E-01 不能记为已满足。

## 追加：当前工具链连仓库内构建也失败（2026-11-17）

- 实测 `ct --version` = `ct v0.63.2`；`~/.local/bin/ct` 的 mtime 为 2026-11-17 08:04。
- 干净 `git archive v0.4.0` / `v0.5.0` / `HEAD`（3e8fbc0）分别跑
  `ct build test/j1_roundtrip.ct -I src`，全部在 `src/json.h.ct:85/86` 报
  `expected a field name`，rc=1。
- 这些 tag 收口时同一命令是绿的，说明当前二进制/前端行为发生了回归，不是本次
  文档改动或包清单改动引入。
- 影响：`g3`、`g4`（snippets）、`g7`（ASan 构建）与所有消费方 `ct build` 同时红。
- 需要：恢复到用户所说的 `ct v0.62.0`（或能解析泛型声明的 `ct`），或上游修 ctc；
  在此之前不宣称门禁全绿。
