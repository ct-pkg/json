# JSON-4 包无法被 `ct get` / `ct install` 消费

- status: **reopened**（原 0.1.1 修复 `1df313b` 只覆盖 vendor 模型；store 模型下于 2026-11-17 重新复现）
- 归属: **本包清单/构建路径问题**，不是语言层
- 优先级: P0（阻塞「装完可用」这一唯一验收口径）
- 影响面: 任何第三方工程按标准包流程装本包后，`import` 无法解析
- 关联: `ct.pkg`、`docs/spec/ct-json-0.1.0-completion.md` §五、夹具 `test/pkg/consumer.ct`

## 触发条件

按标准流程安装：消费方 `ct get <本仓库>` → `ct install` → 编译含 `import json::...` 的单元。

## 实际行为（修复前）

```console
$ ct get ../../            # 消费方目录
vendored 1 package(s)
$ ct install
ct build -I vendor/json <unit>.ct -o build
$ ct build -I vendor/json main.ct
ctc: cannot resolve import 'json/src/json'
$ echo $?
1
```

把 import 改成 `json::json` 同样失败：

```console
ctc: cannot resolve import 'json/json'
```

另：报告里 `ctc -I src src/json.h.ct` 报 `src/json.h.ct:84:8: error: expected a field name`（第 84 行 `Map<Str, int> *index;`）。经三种方式复现（`ctc` 直编 / `ct build` / 作为被 import 的包单元），结论是 **`ctc`（L0）不支持带泛型实参的声明**（`Map<...>` / `Vec<...>`），与 `Str` 无关：探针 `struct A { Map<char *, int> *m; }` 报同一错（1:15），`struct B { Str *s; }` 与 `struct H { Str s; }` 均通过；`ct build` 可编（库单元仅缺 `_main`）。

## 期望行为

`ct get` + `ct install` 后，消费方 `import json::src::json;` 能解析，9 种基本形态可编可跑。

## 修复

1. `ct.pkg` 增加 `namespace = json`：`ct install` 只发 `-I vendor/json`，包根即单元根，单元在 `src/` 下，故消费路径为 `json::src::json`（首段被 `namespace` 剥掉）。
2. `ct.pkg` 注释写明只支持 L2 `ct` 构建，`ctc` 不是受支持路径。
3. 新增 `test/pkg/consumer.ct` 作为红→绿夹具。

## 验证

```console
$ ct get ../../ && ct install        # exit 0
$ ct build -I vendor/json main.ct    # exit 0
$ ./main
consumer fails=0                     # exit 0
```

## 遗留

包根迁移（把单元从 `src/` 移到包根）留待共享库机制/包根约定落地后再做，见 `docs/spec/ct-json-0.1.0-completion.md` §四 backlog #10。本轮不预埋。

## 重新打开：store 模型下（2026-11-17，v0.63.2）

v0.62.0 起 `ct get` 不再写 `vendor/`：包进 `~/.ct/pkg/<publisher>/<name>/<version>`，
消费方根目录得到 `ct.lock`（v2）。按新模型实测：

```console
$ ct get https://github.com/ct-pkg/json@0.6.0
installed 1 package(s)
$ cat ct.lock
# ct-lock 2
ct/json 0.6.0 git https://github.com/ct-pkg/json 0576bd4... src sha256:f2968fe...
$ cat > main.ct <<'CT'
import json;
int main(void) { return 0; }
CT
$ ct build main.ct -o build
.../ct/json/0.6.0/src/json.h.ct:86:8: error: expected a field name
$ echo $?
1
```

- 正确 import 形态是 `import json;`（不是旧的 `json::src::json`；后者在 store 下报
  `cannot resolve import 'json/src/json'`）。
- 断点在编译：store 解析到 `src/json.h.ct` 后由 ctc（L0）解析，泛型声明
  `Map<Str, int> *index;` 报 `expected a field name`。详见 `JSON-15`。
- GitHub 默认版本还有另一个上游缺陷：不写 `@<version>` 时落到最旧的 `v0.1.1`；见 `JSON-16`。
- 旧 vendor 流程（`ct build -I vendor/json main.ct`）在 v0.63.2 上同样复现该 ctc 错误，
  因此原「已修复」的验证不再可复现。

结论：**JSON-4 未闭合**，等 JSON-15（上游 ctc 泛型或本包公共头去泛型重构）解决后重验。
