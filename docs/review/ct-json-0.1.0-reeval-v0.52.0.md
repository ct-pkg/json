# ct-json 0.1.0 复评（CT v0.52.0）

> 日期：2026-11-15
> 旧基线：`ct v0.44.1`（合论、主张席、反证席三份文档均基于此）
> 新基线：`ct v0.52.0`（GitHub tag `v0.52.0`；本机 `~/.local/bin/ct`）
> 复评对象：`docs/review/ct-json-0.1.0-verdict.md` 的 H-01～H-26、J1～J14
> 方法：在 `/tmp/eval52` 用 v0.52.0 重跑可复现的最小探针，不沿用 v0.44.1 的推断

## 0 版本与安装

| 项 | 旧 | 新 |
| --- | --- | --- |
| 编译器 | `ct v0.44.1` | `ct v0.52.0` |
| 安装位置 | `~/.local/bin/ct` | 同左（`ctc` 仍为 `ct` 的符号链接） |
| 旧版备份 | 无 | `~/.local/bin/ct-v0.49.0.bak`（安装前为 v0.49.0） |
| ct-lang 源码 | HEAD `5a75b90a` | tag `v0.52.0`；本地 HEAD `1d49bb1a` 仅文档提交 |

安装方式：从 `https://github.com/samxxu/ct-lang/archive/v0.52.0.tar.gz` 下载源码，跑仓库自带 `install.sh` 的 L0→L1→L2→ct-ast 四段 bootstrap。

自检原始输出：

```
$ ct --version
ct v0.52.0
$ ct build examples/01_greeter/greeter.ct -o /tmp/greeter && /tmp/greeter
Hello, I'm Tom, age 36
Hello Jerry, I'm Tom
$ ct check json.ct && ct json.ct -o /tmp/json.c && cc ... && diff json.expected.out ...
check-rc=0
run-rc=0
GOLDEN-MATCH
```

旧 golden（125 `ok` + 20 errors）在 v0.52.0 下逐字节不变，说明现有实现没有因编译器升级漂移。

## 1 判定摘要

**0.1.0 规范原文仍是 NO-GO**：核心类型定义与三处 API 写法在 v0.52.0 上依然编译不过（匿名 union、裸泛型、`own` 返回类型、三重载），且 encode/decode/错误模型/所有权契约仍空白。

**但 NO-GO 的理由集合缩小了**：11 条阻断里，3 条已解除（H-03、H-04 的调用点写法、H-05），3 条被新能力部分化解（H-07、H-08、H-10），2 条可改语法绕开（H-01、H-02），3 条仍不可行（H-06、H-09、H-11）。

**方向可留，形态仍要重写**：ADR-0001～0007 定下的树 + 读 + 写 + 引用计数 + 字符串下标，在 v0.52.0 上已能写出关键形态的可编译最小原型；剩下的硬缺口是数字下标 `v[0]`、方法结果链式接收者、`char*` 键不复制、容器元素不自动 release。

## 2 能力变化总表

### 2.1 已解除（旧阻断，v0.52.0 实测通过）

| 旧编号 | 旧结论 | v0.52.0 实测 | 新判定 |
| --- | --- | --- | --- |
| H-03 | 带泛型字段的 `struct` 不能进 `.h.ct` | `p3/g.h.ct`：`pub struct N { Vec<int> *kids; }`；`ct build -I p3 p3/main.ct -o p3/app` → `ct-rc=0`，`p3/app` 运行 `rc=0` | **解除** |
| H-04 | `own` 不能接工厂返回值；`own` 写进返回类型生成非法 C | 调用点写法通过：`struct X *mk(void)` + `own struct X *q = mk(); delete q;` → `ct=0`、运行 `rc=0`。返回类型写法仍有诊断：`error: 'own' in a return type is not supported; mark the call site instead: 'own struct <T> *p = factory();'` | **解除（须改写法）** |
| H-05 | Drop 不递归：同单元空体、跨单元空桩、容器元素空体 | 同单元：`same drop 5`；跨单元：`res drop 7`；指针字段：`A drop 2`。容器元素仍不自动 drop：`Vec<D>` 的 `release()` 只打印 `vec done` | **解除（Drop 已闭环）；容器元素仍需显式释放** |

Phase 48（Drop 闭环）、49（`own` 初始化式）、46（Map 元素完整性）是这次解除的直接来源。

### 2.2 可改语法绕开（语言仍拒，但不是硬缺口）

| 旧编号 | 旧结论 | v0.52.0 实测 | 绕法 |
| --- | --- | --- | --- |
| H-01 | 匿名 `union` 具名字段被硬拒 | `pA.ct:1:38: error: an anonymous record member cannot have a name; tag the record instead` | 用具名 `union V { ... }` + `struct X { int tag; union V v; }`；实测 `pUnion` `ct=0`、`cc=0`、运行 `rc=0` |
| H-02 | 裸 `Map *` / `Vec *` 缺类型实参，CT 放行、`cc` 才报错 | `ct-rc=0`；`pB.c:6:5: error: unknown type name 'Map'`、`:7:5: ... 'Vec'` | 写全 `Map<char*, JsonRef>` / `Vec<JsonRef*>`；类型实参必须显式 |

这两条说明：**规范里的类型定义不能照抄，但设计本身不撞语言墙**。

### 2.3 仍未解除（v0.52.0 依旧不可行）

| 旧编号 | 现状 | 证据 |
| --- | --- | --- |
| H-06 三重载 | CT 仍只给 warning，C 层冲突 | `pH.ct:3: warning: type mismatch: 'f' argument 1 ...`；`pH.c:5:5: error: conflicting types for 'f'` |
| H-09 `#define` 不导出 | 仍然不可见 | `pK/main.ct:4:31: error: use of undeclared identifier 'K_NUM'`；`pub enum` 可用：`tag=0` |
| H-11 自动转换不存在 | 仍是 warning + 错值 | `pL.c:13:12: warning: incompatible pointer types initializing 'char *' with an expression of type 'struct R *'` |
| 方法重名 | 同一类型不能同时有 `get(char*)` 与 `get(int)` | `pO.c:15:36: error: conflicting types for 'X_get'`（与 PH-52 D52-2 一致） |

### 2.4 部分化解

| 旧编号 | 现在 | 仍缺 |
| --- | --- | --- |
| H-07 `Vec::get` 值拷贝 | `Vec<Y>::get` 返回值拷贝，`at` 返回借用指针；实测 `at=5 got=5` | 需要指针时改用 `at`；`get` 语义不变（PH-50 D50-1） |
| H-08 字段链接收者 | `b.a.get("x")`、`b.p->get("x")`、`x["a"]->n` 均可用；结构体指针字段 Drop 也通 | 经 `union` 成员的链仍失败：`pJ2.ct:11:1: error: cannot resolve the method trait (unknown receiver type)`；方法结果作接收者仍失败：`pChain.ct:3:1: error: a method call on a temporary is only allowed at the start of a statement or of an assignment` |
| H-10 下标链 | 单层字符串键读写已可用（PH-52）：`x["a"]` → `get`、`x["a"]=9` → `set`；跨单元 `pub get` 可用，非 `pub` 报 `type 'X' has no subscript: 'get' is private to its unit` | `v[0]` 不主张（会展开成 `get(0)`，实测调用到 `get(char*)`）；指针接收者 `p["k"]` 落 C 语义；`v["a"]["b"]` 链式不做 |

### 2.5 新能力（v0.49.0 之后新增，可直接用上）

| 能力 | 版本 | 实测 |
| --- | --- | --- |
| 自定义类型字符串下标读写 | v0.52.0 | `read=7 zero=-1`、`method=9 sub=9`；`x["a"]=9` 写回 9 |
| 跨单元 `pub` 下标方法 | v0.52.0 | `xunit`：`pub int get` → 输出 `3`；去掉 `pub` → L52-10 |
| `Vec::has` / `Vec::at` 借用 | v0.50.0 | `has0=1 at0=5 get0=5`、`has9=0 at9null=1`、`empty=0` |
| `Map::has`；`Map::get` 返回 `V*` | v0.50.0 | `mhas=1 mget=7 miss=0` |
| 跨单元 Drop、指针字段 Drop | v0.48.0 | `res drop 7`、`A drop 2` |
| `own` 接工厂返回值 | v0.49.0 | `pD3` `ct=0`、运行 `rc=0` |
| `Str` 键深拷贝、含 `\0` 键 | v0.47.0 | `Map<Str,int>`：键 release 后仍 `has=1 val=7` |

`Str` 键与 `char*` 键的差别仍然存在：`Map<char*,int>` 的键不复制，缓冲区改成 `"zbc"` 后 `has("abc")=0`、`has("zbc")=1`。

## 3 J1–J14 复判

| 编号 | 旧判定 | 新判定 | 依据 |
| --- | --- | --- | --- |
| J1 | 不可执行（原文） | **改写后可执行** | `own` 移到调用点；避开 union 成员链接收者 |
| J2 | 不可执行（原文） | **改写后可执行** | `doc->root.v.arr->len()` 仍需先落局部；结构体字段链本身已通 |
| J3 | 可执行 | **可执行** | `pub enum` 导出可用（`tag=0`） |
| J4 | 不可执行 | **不可执行** | 仍无 code/offset；`message` 所有权未定 |
| J5 | 依赖未落地 | **部分可执行** | 单层 `doc["server"]` 可；`["a"]["b"]` 链式不可 |
| J6 | 依赖未落地 | **部分可执行** | 字符串下标可；自动转换仍不存在（H-11） |
| J7 | 依赖未落地 | **改写后可执行** | 用 `has`/`at` 区分缺失与零值，不再靠 `get` 零值 |
| J8 | 不可执行 | **不可执行（原文）** | 三重载仍冲突；改具名 encode 后可写 |
| J9 | 不可执行 | **改写后可执行** | `json_retain`/`json_release` + ASan 可观察；但提案没有判据设计 |
| J10 | 不可执行且必假 | **改写后可执行** | Drop 已闭环 + 引用计数 API；需改成 retain/release 配对断言 |
| J11 | 依赖未落地 | **不可执行** | 链上两跳仍受「方法结果作接收者」限制 |
| J12 | 可执行（需改写） | **可执行** | `arr->get(i).tag` 值拷贝成立；也可用 `at(i)->tag` |
| J13 | 可执行 | **可执行** | 仍需 `json_ref_to_str` 真实存在 |
| J14 | 可执行 | **可执行** | `to_int` 越界规则仍要补（ADR-0004 只定了表示，没定转换） |

计数：**可直接执行 4（J3/J12/J13/J14）；改写后可执行 5（J1/J2/J7/J9/J10）；部分可执行 2（J5/J6）；仍不可执行 3（J4/J8/J11）**。

## 4 对既有 ADR 的冲击

| ADR | 冲击 | 建议 |
| --- | --- | --- |
| 0001 设计口径 4 | 「跨单元 `Drop` 当前是空桩」的前提在 v0.48.0 已失效（实测 `res drop 7`） | 结论（显式 `json_free`）仍由 0003/0006 支撑，但理由句需要换掉；这是**加注级**修改，不是推翻 |
| 0007 V-1/V-3/V-5 | 单层字符串键的 `pub get`/`set` 已能直接挂 `v["k"]`；V-1/V-3/V-5 的「最终形态」现在有可运行样例 | 保留 ADR 结论，补一条 v0.52.0 实测注；`v[0]` 仍不成立 |
| 0007 长期目标 `data.server.port` | 方法结果不能作接收者（SH-73），表达式级链式仍不可用 | 目标不变，但「等下标语法糖」之外还要等 SH-73；应写进依赖清单 |
| 0004 数字双轨 | 语言能力足够（int64/double/`Str` 原文）；写入 `double` 的编码格式仍空 | 0004 的「未定」仍是负责人待拍板项 |
| 0002 待定 4 | 类型不匹配写入（报错/覆盖）仍无裁定 | 保持待定 |

## 5 更新后的评估结论

1. **规范原文：NO-GO 不变。** 逐字照抄的代码在 v0.52.0 上仍过不了：匿名 union、裸泛型、`own` 返回类型、三重载；此外 union 成员链接收者、方法结果链式、数字下标仍不可用。
2. **设计方向：GO（有条件）。** 树 + 读写 + 引用共享 + 字符串下标可以落地；条件是把类型定义改成具名 union + 显式类型实参，`own` 只写在调用点，encode 用具名函数，键统一用 `Str`。
3. **最小可行子集扩大。** 旧合论 §6 的 8 项里，原先被判「不可执行」的字段链、`own` 入口、Drop 相关项现在可以纳入；仍不能纳入的是数字下标 `v[0]`、链式方法调用、`#define` 常量、同名重载。
4. **契约缺口仍是主要问题。** 语言升级解决的是「能不能写」，没有解决 encode/decode 契约、错误模型、所有权规则；这些仍按旧合论 H-15～H-26 处理。

## 6 需要负责人拍板

| # | 问题 | 选项 | 后果 |
| --- | --- | --- | --- |
| Q-A | 0.1.0 规范按 v0.52.0 语法重写，还是放弃规范、以 ADR 为唯一来源？ | 重写 / 以 ADR 为准 | 重写：保留旧文本但工作量大；以 ADR 为准：规范作废，实现按 ADR 重新设计 |
| Q-B | 键类型强制用 `Str`，还是允许 `char*`？ | 只允许 `Str` / 两者都允许 | `Str`：含 `\0` 键安全、键深拷贝；`char*`：省内存但键不复制、按 `strcmp` 截断 |
| Q-C | 数字下标 `v[0]` 等 SH-73/数字下标落地，还是先提供 `get_idx`？ | 等 / 先 `get_idx` | 等：`items[0].name` 不能写；先 `get_idx`：可用但偏离 JS 目标 |
| Q-D | ADR-0001 规则 4 的「Drop 空桩」理由是否改为「显式释放 + 引用计数」？ | 改理由 / 保持 | 改：文档与 v0.52.0 一致；保持：读者会以为 Drop 仍不可用 |
| Q-E | 容器元素释放：要求调用方显式 release，还是等容器自动 drop？ | 显式 / 等 | 显式：现在就能写；等：当前 `Vec<D>::release()` 不调用元素 drop |
| Q-F | `requirements.md` 的 Q-01 仍是「待确认」，是否随 ADR-0001 更新？ | 更新 / 保持 | 更新：文档一致；保持：需求与决策继续打架 |

## 7 复现附录

环境：`export PATH="$HOME/.local/bin:$PATH"`，`ct v0.52.0`；探针在 `/tmp/eval52`（仓外）。含 `Vec` / `Map` / `Str` 的探针额外带 `CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std`，C 侧带同一目录的 `-I`。

| 探针 | 命令 | 原始输出 |
| --- | --- | --- |
| 匿名 union | `ct pA.ct -o pA.c` | `pA.ct:1:38: error: an anonymous record member cannot have a name; tag the record instead`，`rc=1` |
| 具名 union | `ct pUnion.ct -o pUnion.c && cc ...` | `ct=0`、`cc=0`、`rc=0` |
| 裸泛型 | `ct pB.ct -o pB.c && cc ...` | `ct=0`；`pB.c:6:5: error: unknown type name 'Map'`、`:7:5: ... 'Vec'` |
| 泛型字段出头 | `ct build -I p3 p3/main.ct -o p3/app` | `ct-rc=0`；`p3/app` 运行 `rc=0` |
| `own` 返回类型 | `ct pD.ct -o pD.c` | `pD.ct:3:1: error: 'own' in a return type is not supported; mark the call site instead: 'own struct <T> *p = factory();'` |
| `own` 调用点 | `ct pD3.ct -o pD3.c && cc ... && ./pD3` | `ct=0`、运行 `rc=0` |
| 跨单元 Drop | `cd pDrop && ct build -I . prog.ct -o app && ./app` | `res drop 7`、`done` |
| 同单元 Drop | `ct same.ct ... && ./same` | `same drop 5`、`done` |
| 指针字段 Drop | `ct pField.ct ... && ./pField` | `A drop 2`、`done` |
| 容器元素 Drop | `ct vecdrop.ct ... && ./vecdrop` | `vec done`（无元素 drop） |
| 三重载 | `ct pH.ct -o pH.c && cc pH.c` | `warning: type mismatch ...`；`pH.c:5:5: error: conflicting types for 'f'` |
| `get` 重载 | `ct pO.ct -o pO.c && cc pO.c` | `pO.c:15:36: error: conflicting types for 'X_get'` |
| 字段链（结构体） | `ct pJ.ct ...` | `ct=0`、`cc=0` |
| 字段链（union） | `ct pJ2.ct` | `pJ2.ct:11:1: error: cannot resolve the method trait (unknown receiver type)` |
| 方法结果链 | `ct pChain.ct` | `a method call on a temporary is only allowed at the start of a statement or of an assignment` |
| `#define` 导出 | `ct build -I pK pK/main.ct -o pK/app` | `use of undeclared identifier 'K_NUM'` |
| `pub enum` 导出 | 同上，改 main | `tag=0` |
| 隐式转换 | `ct pL.ct -o pL.c && cc pL.c` | `warning: incompatible pointer types initializing 'char *' ... 'struct R *'` |
| 字符串下标 | `ct a.ct -o a.c && cc ... && ./a` | `read=7 zero=-1`、`method=9 sub=9` |
| 跨单元下标 | `ct build -I xunit main.ct -o app && ./app` | `3` |
| 非 `pub` 下标 | 同上，去掉 `pub` | `type 'X' has no subscript: 'get' is private to its unit` |
| 容器契约 | `ct c.ct ...`（`CT_STD_DIR=lib/std`） | `has0=1 at0=5 get0=5`、`has9=0 at9null=1`、`mhas=1 mget=7 miss=0` |
| `Str` 键 | `ct pStrKey.ct ...` | `has=1 val=7` |
| `char*` 键 | `ct pKey.ct ...` | `orig=0 mutated=1` |
| `Vec` 取值 | `ct pVec.ct ...` | `at=5 got=5` |
