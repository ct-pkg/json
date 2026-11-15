# ct-json 0.1.0 完工判定（CT v0.53.0）

> 判定对象：`src/json.h.ct` 与 `test/j1_roundtrip.ct` 的 0.1.0 重写。
> 实测基线：CT `v0.53.0`（本机 `~/.local/bin/ct`）。实现提交区间 `f5c48aa..77501d6`，共 8 个提交（4 片 × 红证 + 实现）。
> 规范：`docs/spec/ct-json-0.1.0.md`。

## 一、判定

**达成（有条件）**：规范 §八 的 8 条验收中 7 条通过；J1–J14 中 11 条通过；J4 / J8 / J11 按设计不支持；没有「本该过而不过」的项。唯一未机器验证的是内存泄漏（macOS 不支持 ASan `detect_leaks`）。

## 二、实测证据

```console
$ ~/.local/bin/ct --version
ct v0.53.0

$ CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build test/j1_roundtrip.ct -I src -o /tmp/ctjson_test
（0 warning）

$ /tmp/ctjson_test
124 ok / 0 not ok
all checks passed
exit 0

$ cc -std=c99 -g -fsanitize=address ... -o /tmp/ctjson_asan && /tmp/ctjson_asan
all checks passed
exit 0（无 use-after-free / 双重释放；detect_leaks 在该平台不可用）

$ CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build json.ct -o /tmp/jsongate
$ /tmp/jsongate | diff - json.expected.out
（无差异，exit 0）
```

## 三、判据归类

| 类别 | 判据 | 说明 |
| --- | --- | --- |
| 真过（11） | J1 J2 J3 J5 J6 J7 J9 J10 J12 J13 J14 | 形态与原因见规范 §四 |
| 按设计不支持（3） | J4 J8 J11 | 错误对象、构造辅助、三级链；升级版本见 §四 |
| 卡在语言（2） | 数字下标 `v[0]`、链式的临时值接收者 | CT 尚无用户类型数字下标协议（REQ-INDEX-1 已立项）；三级链/参数位置/方法结果链受接收者规则限制 |
| 卡在环境（2） | 泄漏检测、`ct-ast` 门禁 | macOS ASan `detect_leaks` 不支持；`ct-ast` 未安装，golden 用 `ct` 复跑 |

规范 §八逐条：1 过、2 过（非 `pub` 负例未单独复验）、3 过（浮点格式按 Q-6 未冻结）、4 过、5 过、6 过、7 过（`cap > len` 只释放 `[0,len)`，ASan 干净）、8 过（不支持项无入口或明确失败）。

## 四、0.1.1 backlog

| # | 项 | 触发条件 / 依据 |
| --- | --- | --- |
| 1 | J4 错误对象：`code + offset + message`，并裁定 `message` 所有权 | 规范 §四 J4 升级路径 |
| 2 | J8：补构造 API（仍单入口），或明确废弃原断言 | 规范 §四 J8 升级路径 |
| 3 | J11 三级链：等编译器放开临时值接收者；在此之前拆局部变量 | 规范 §5.1 |
| 4 | `v[0]` 数字下标：等 CT 用户类型下标运算符；届时 `get_idx` 去留另行决定 | REQ-INDEX-1；规范 §3.4 |
| 5 | 写入浮点编码格式冻结（`%.17g`/最短往返、整值 `1.0`、`NaN`/`Inf`） | 规范 §2.4 Q-6 |
| 6 | 泄漏与 sanitizer：CI 移到 Linux 跑 ASan `detect_leaks` | 本判定环境缺口 |
| 7 | 补负例红证：非 `pub` 下标、容器 Drop 顺序、`cap > len` 不越界释放 | G5 要求每条断言至少一个曾变红的负例 |
| 8 | `JsonObj.index` 用 `Map<Str,int>`：v0.53.0 的 `Map` 实为插入序线性查找且每键两份副本；键多时改哈希或去掉冗余副本 | 规范 §2.3 注释 |
| 9 | 规范文档 347 行，超过 G4 的 300 行上限，需按 8.4 拆分（门禁建立前先登记） | AGENTS.md G4 `g4-size` |
| 10 | 包根迁移：现用 `namespace = json` + `import json::src::json` 过渡；所需能力已具备，改为按 `docs/spec/ct-json-delivery-backlog.md` 第 1、3 项开工 | 0.1.1 验收记录 §五 |

## 五、0.1.1 验收记录（可用性补丁，CT v0.53.0）

**本版收的只有一条**：让 ct-json 能被 `ct get` + `ct install` 正常消费。实现与公开 API 未改，未加任何新特性；依赖 CT 语言能力的条目全部留在 §四。

### 5.1 错误定性：`ctc -I src src/json.h.ct` 的 `expected a field name`

结论：**不是包自身写法/类型问题，也不是缺 include、缺 namespace 或单元位置问题；是 `ctc`（L0）不支持带泛型实参的声明**（`Map<...>` / `Vec<...>`），**与 `Str` 无关**。同一份代码用 L2 `ct build` 可编，作为被 import 的包单元也正常。

| 复现方式 | 命令 | 原始输出 / 结果 |
| --- | --- | --- |
| ctc 直编（报告里的方式） | `ctc src/json.h.ct -I src` | `ctc: warning: -I is ignored by compile mode; imports require 'ct build'`<br>`src/json.h.ct:84:8: error: expected a field name`（rc=1）；第 84 行是 `Map<Str, int> *index;` |
| 包内既有构建方式（L2） | `ct build src/json.h.ct -I src -o /tmp/json_unit` | 生成 C 并调用 `cc` 成功，仅链接失败：`Undefined symbols for architecture arm64: "_main"`（库单元无 `main`，属预期，rc=1） |
| 作为被 import 的包单元（L2） | `ct install` 后 `ct build -I vendor/json main.ct`，`main.ct` 内 `import json::src::json;` | 编译运行成功：`consumer fails=0`（rc=0） |

最小探针（`ctc` 直编，各一条）：

| 探针 | 结果 |
| --- | --- |
| `struct A { Map<char *, int> *m; };` | `probe_a.ct:1:15: error: expected a field name`（rc=1） |
| `struct E { Vec<int> *v; };` | `probe_e.ct:1:15: error: expected a field name`（rc=1） |
| `struct B { Str *s; };` | rc=0 |
| `struct H { Str s; };` | rc=0 |

`Map<char *, int>` 与 `Map<Str, int>` 报同一条错、位置也相同（`<` 处），而 `Str` 字段两种写法都过——所以触发条件是**声明里出现泛型实参**，不是键类型、不是字段名、不是 `-I`。构建路径口径已写进 `ct.pkg` 注释：**只支持 L2 `ct`，`ctc` 不是受支持路径**。

### 5.2 消费失败的真正原因与修复

| 现状 | 命令 | 原始输出 |
| --- | --- | --- |
| 0.1.0 无 `namespace` 键，import 写成 `json::src::json` | `ct build -I vendor/json main.ct` | `ctc: cannot resolve import 'json/src/json'`（exit 1） |
| 同上，import 写成 `json::json` | 同上 | `ctc: cannot resolve import 'json/json'`（exit 1） |
| 修复：`ct.pkg` 加 `namespace = json` | 同上 | exit 0；程序输出 `consumer fails=0` |

原因：包根即单元根，单元在 `src/` 下，而 import 首段会被 `namespace` 剥掉，所以消费路径必须是 `json::src::json`。

### 5.3 验收证据

```console
$ ct get /path/to/ct-json        # 在消费方目录；消费方自身需先有 ct.pkg
vendored 1 package(s)
$ ct install                     # 消费方无 ct.pkg 时报 ctc: cannot open './ct.pkg'
ct build -I vendor/json <unit>.ct -o build      # exit 0
$ ct build -I vendor/json main.ct
（0 error，exit 0）
$ ./main
consumer fails=0                                  # exit 0
$ CT_STD_DIR=... ct build test/j1_roundtrip.ct -I src -o /tmp/ctjson_test && /tmp/ctjson_test
124 ok / 0 not ok
all checks passed                                 # exit 0
$ # 既存 snippet 与 golden 门禁
docs/snippets/{read_str,write_str,chain,numeric_index,cross_unit}.ct  build/run 全部 rc=0
ct build json.ct -o /tmp/jsongate && /tmp/jsongate | diff - json.expected.out   # exit 0
```

红→绿夹具：`test/pkg/consumer.ct`，覆盖 9 种「装完必须可用」的形态（单层读、覆盖写、新增键、两级链读、`get_idx`、`has(Str)`、对象/数组迭代、编码成字符串、共享引用）。修复前该夹具因 import 解析失败而红（`ctc: cannot resolve import 'json/src/json'`，exit 1），修复后绿（`consumer fails=0`，exit 0）。

版本位：`ct.pkg` 的 `version = 0.1.1`（patch 位），`requires = ct >= 0.53.0` 不变。
