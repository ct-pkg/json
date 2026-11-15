# JSON-4 包无法被 `ct get` / `ct install` 消费

- status: **fixed**（0.1.1，提交 `1df313b`；红证 `338664c`）
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
