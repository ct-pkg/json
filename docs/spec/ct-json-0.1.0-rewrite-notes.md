# ct-json 0.1.0 规范重写说明（v0.44.1 → v0.52.0）

> 旧版：`ct-json-spec.md`（415 行，基于 CT v0.44.1）
> 新版：`docs/spec/ct-json-0.1.0.md`（全量重写，基于 CT v0.52.0）
> 判定依据：`docs/review/ct-json-0.1.0-reeval-v0.52.0.md`；本文只列改动与依据，不重复探针全文。

## 1 总体差异

| 维度 | 旧版 | 新版 | 依据 |
| --- | --- | --- | --- |
| 基线 | v0.44.1，多处「待 L1 / 待自动转换」 | v0.52.0，只写已实测形态 | `ct v0.52.0` 自检 |
| 数据模型 | `JsonRef` 16 字节纯 union | 8 字节句柄 + 节点 `JsonNode` + 具名 union | pA / pUnion |
| 所有权 | `JsonDoc` + Drop 递归释放 | 引用计数（retain/release/free），共享写入 | ADR-0003/0006 |
| 对象容器 | 复用 `Map<char*, JsonRef>` | `JsonObj` 保插入序（键数组 + 索引） | ADR-0001 口径 2 |
| 数组容器 | 复用 `Vec<JsonRef>` | `JsonArr` 显式容量 | pB（裸泛型不可用） |
| 访问 | `doc["server"]["host"]` + 自动转换 | 单层 `v["k"]` + 局部变量 + 显式 `json_as_*` | pSub2 / pChain / pL |
| 写入 | 无 | `set` / `set_*` / `remove` + `v["k"]=x` | a.ct / xunit |
| 数字 | 统一 `double` | 双轨：原文 + int64/double | ADR-0004 |
| 编码 | 三重载 `json_encode` | 单入口 `json_encode(JsonRef)` | pH |
| 错误 | `JsonError{line,col,message}` | 负错误码；结构化错误移出 0.1.0 | 无 error 契约 |
| 生命周期 | `own JsonDoc` + Drop | `json_retain`/`json_release`/`json_free` | ADR-0006 |
| 环 | 未讨论 | 写入允许、编码期拒绝 | ADR-0005 |
| 依赖表 | L1 已立项、自动转换待评估 | 只有「字符串键已支持、数字下标/链式不支持」 | 实测 |

## 2 逐条改动

| # | 旧版位置/内容 | 新版处理 | 依据（探针） |
| --- | --- | --- | --- |
| 1 | §2.1 匿名 `union` 具名字段 | 改为具名 `union JsonValue` + 字段引用；列入强制写法 | `pA`：`error: an anonymous record member cannot have a name; tag the record instead`；`pUnion`：`ct=0, cc=0` |
| 2 | §2.1 `Map *obj` / `Vec *arr` | 强制写类型实参；对象/数组改为自有容器 | `pB`：`unknown type name 'Map'` / `'Vec'` |
| 3 | §2.1 `JsonRef` 16 字节纯 POD | 改为 8 字节句柄，节点独立；保留「无 vtable」 | ADR-0001 指针稳定；`specproto` 编译通过 |
| 4 | §2.2 `JsonDoc` + `use Drop` | 删除；改为 `JsonNode.refs` + retain/release | ADR-0006；`vecdrop` 证明容器不自动 drop 元素 |
| 5 | §3.1 `own JsonDoc *json_decode` | `int json_decode(text, len, JsonRef *out)` | `pD`：`'own' in a return type is not supported` |
| 6 | §3.2 三重载 `json_encode` | 单入口 `json_encode(JsonRef)` | `pH`：`conflicting types for 'f'`（同名不同参） |
| 7 | §3.3 `json_str` 等构造辅助 | 删除；J8 标不支持 | 构造 + 编码的所有权未裁定；0.1.0 不收 |
| 8 | §3.4 `json_get(doc, "a.b")` 路径助手 | 删除；下标是唯一入口 | ADR-0007；单层下标已可用 |
| 9 | §4 `map trait JsonExtract` 寄生 | 删除；改为显式 `json_as_*` 函数 | v0.52.0 无自动转换；`pL` 只有 warning |
| 10 | §5 自动转换语法糖 | 删除；J6 改为显式转换 | `pL`：`incompatible pointer types` warning |
| 11 | §6.1 `doc["server"]["host"]` | 单层 `v["k"]`；深层用局部变量拆语句 | `pSub2`：`a method call on a temporary...`；`a.ct` 单层 `sub=9` |
| 12 | §6.2 `json_get` 兜底 | 删除 | 同上 |
| 13 | §7.1 Drop 递归释放 | 改为引用计数释放；DAG 共享 | ADR-0003/0006 |
| 14 | §7.2 `JsonRef*` borrow 到 doc 释放 | 句柄 + 计数；`json_free` 后失效 | ADR-0003 |
| 15 | §7.3 `json_str` 副本释放 | 删除；无构造辅助 | 与 #7 同 |
| 16 | §8 流式分工 | 保留 | 无语言变化 |
| 17 | §9.1 `JsonError{line,col,message}` | 删除；J4 标不支持，只留负错误码 | 无错误契约；`message` 所有权未定 |
| 18 | §9.2 取值不匹配返回默认值 | 改为返回错误码 + `out` 不变 | `pVec`/`pKey` 证明可区分缺失；避免静默零值 |
| 19 | §10 依赖表「L1 已立项 / 自动转换待评估」 | 改为 v0.52.0 事实表：字符串键支持、数字/链式不支持 | `xunit`（跨单元 `pub get` 可用）；`a.ct`；`pSub2` |
| 20 | §11 J1–J14 | 全表重判；J4/J8/J11 标「0.1.0 不支持」 | 见新版 §四 |
| 21 | §12 边界声明「json_get 兜底」 | 删除该条；新增「数字下标/链式不支持」 | 同上 |
| 22 | §13 五个示例 | 删除自动转换/链式示例；保留 decode→读→改→encode 的可编译形态 | `a.ct`、`xunit`、`c` |
| 23 | §14 一句话「靠 L1 / 靠自动转换」 | 改为「字符串键单层下标是正式入口」 | 同上 |
| 24 | 键类型未定 | 键强制 `Str`，插入深拷贝、容器持有；`get`/`set` 保留 `char *` 仅作协议适配 | Q-1 裁定 A；`strkey`：`get(Str)` 使 `v["k"]` 报 `passing 'char[2]' to parameter of incompatible type 'struct Str'`；`pStrKey`：`Str` 键 release 后仍命中 |
| 25 | 数字下标待定 | 0.1.0 只提供 `get_idx(i)`；`v[0]` 标不支持；越界/非数组返回空句柄；写明过渡 | Q-2 裁定 A；`pO`：`get(char*)` 与 `get(int)` 同名冲突，故必须分名；`pSub2`：数字/链式不匹配 |
| 26 | ADR-0001 规则 4「不依赖 Drop」被当成强制规则 | ADR-0001 加「规则 4 降级」注：不强制空 `impl Drop`；需自定义释放时显式写并说明释放什么；规范 §3.7 同步 | Q-3 裁定 B；`same drop 5`、`res drop 7`、`A drop 2`（v0.48.0 起字段胶水已闭环） |
| 27 | 容器元素释放未定 | 容器负责：`JsonObj`/`JsonArr` 的 Drop 循环 `json_release`；先元素后数组；只释放 `len` 个；泛型容器限制写明 | Q-4 裁定 A；`vecstr` 的 `Vec_Str__elem_release` 调 `Str_release`；`vecd` / `vecd2` 的用户 struct 为 `(void)e;`（空体）；`ownarr` 显式循环 `freed=2` |
| 28 | `requirements.md` X-01 仍「待 Q-01」 | 改为已定结论并指向 ADR-0001；非目标表的「可变 DOM」条目同步 | Q-5 裁定 A |

## 3 新增内容

- 引用共享与环（ADR-0003/0005）：写入不拷贝、编码期拒绝环、成环漏内存。
- 双轨数字（ADR-0004）：原文回吐 + int64/double。
- 有序对象容器：键数组 + 索引，编码保序。
- 写 API：`set` / `set_int` / `set_double` / `set_bool` / `set_str` / `set_null` / `remove`。
- 对象键强制 `Str`（Q-1 裁定 A）：插入深拷贝、容器持有、删除时释放；`get`/`set` 的 `char *` 仅作下标协议适配（见 §2 第 24 行）。
- 明确的访问边界表（§五）：单层、无链式、无自动转换、无数字下标、指针接收者不展开。
- 待裁定清单 Q-1～Q-6，其中 Q-1 已裁定，其余不代选。

## 4 三条不支持的判定

| 编号 | 标注 | 原因 |
| --- | --- | --- |
| J4 | 0.1.0 不支持 | 只返回负错误码；不提供行/列/消息，`message` 所有权未裁定 |
| J8 | 0.1.0 不支持 | 不提供 `json_str` 构造辅助；三重载 `json_encode` 在 v0.52.0 仍冲突 |
| J11 | 0.1.0 不支持 | 三层下标链依赖「方法结果作接收者」，v0.52.0 明确禁止 |

## 5 未决事项（未在规范里代选）

Q-1 键类型已裁定为 `Str`（协议入口的 `char *` 例外待确认）；Q-2 已裁定 0.1.0 只提供 `get_idx(i)`（数组按下标的写入口仍未裁定）；Q-3 已裁定规则 4 降级；Q-4 已裁定容器负责释放元素；Q-5 已裁定同步 `requirements.md`；仅 Q-6 写入浮点编码格式作为实现细节待定。规范正文不写实现、不写判据外的承诺。
