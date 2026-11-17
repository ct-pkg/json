# ct-json 包规范 0.1.0（边界、验收与示例）

> 本文件承接 [ct-json-0.1.0.md](ct-json-0.1.0.md) 的 §四–§十；章节编号保持原样，避免既有引用失效。

## 四、J1–J14 在 0.1.0 的判定

| 编号 | 0.1.0 | 写法或原因 |
| --- | --- | --- |
| J1 | 支持 | `JsonRef root = ...; JsonRef a = root["a"];` 用局部变量承接，不用 union 成员链 |
| J2 | 支持 | `json_arr_len(root)`；元素用 `get_idx(i)` |
| J3 | 支持 | `json_tag(root)` 分派；`pub enum` 可用 |
| J4 | **不支持** | 0.1.0 只返回负错误码，不提供 `JsonError{line,col,message}`；`message` 所有权无裁定。升级路径：0.1.1 迁到错误对象（code + offset + message） |
| J5 | 支持 | `JsonRef h = doc["server"]["host"];` 在声明初始化/赋值位置可用；链式结果直接作函数参数时仍不可用（JSON-5，§5.1） |
| J6 | 支持（改写） | `long long port; json_as_int(doc["port"], &port);`；无自动转换 |
| J7 | 支持 | `has` 区分缺失；`get` 不崩 |
| J8 | **不支持** | 0.1.0 不提供 `json_str` 等构造辅助，`json_encode` 只留单入口；原断言形态不成立。升级路径：0.1.1 补构造 API（仍单入口），否则在 0.1.1 明确废弃原断言 |
| J9 | 支持 | 只读编码；返回值由调用方 `free`，库内不释放 |
| J10 | 支持（改写） | `json_release` 计数归零；不再用 `delete doc` 断言 |
| J11 | 支持（v0.62.0） | 三级下标链在声明初始化、赋值与 return 位置都可用，不再报临时值接收者错误；见 §5.1 |
| J12 | 支持 | `json_as_*` + `json_tag` 逐元素判定 |
| J13 | 支持 | `json_as_str` 对非字符串返回 `JSON_ERR_TYPE` |
| J14 | 支持 | `json_as_int` 对 bool 返回 0/1；越界返回 `JSON_ERR_RANGE` |

不支持的两条是 J4、J8，原因如上；J11 在 v0.62.0 已支持。不使用「暂不支持」这种含糊表述。

## 五、v0.62.0 的访问边界

| 能力 | 现状 | 规范写法 |
| --- | --- | --- |
| `v["k"]` 读 | 可用（`pub get`） | `v["k"]` |
| `v["k"] = x` 写 | 可用（`pub set`） | `v["k"] = x` |
| 跨单元下标 | `get`/`set` 必须 `pub` | `pub JsonRef get(char *k);` |
| 数字下标 `v[0]` | 编译通过，落 `get(0)`：`0` 是空 `char *` 键，**静默返回空句柄** | **0.1.0 不支持**；用 `get_idx(i)`，越界返回空句柄 |
| 指针接收者 `p["k"]` | 不展开，落 C 语义 | 用 `JsonRef` 值句柄，不用 `JsonNode*` 做公开入口 |
| 两级链 `v["a"]["b"]` | 可用（声明初始化/赋值位置） | 见 §5.1 正例 |
| 三级链 `v["a"]["b"]["c"]` | 可用（声明初始化/赋值/return） | 见 §5.1 正例 |
| 方法结果链 `v.get("a").get("b")` | 可用（v0.62.0） | 见 §5.1 正例 |
| 对临时值调方法 `doc["a"].has(k)` | 可用（v0.62.0） | 见 §5.1 正例 |
| 链式结果作函数实参 / 条件 / 字段 | 不可用：`a method call on a temporary ...` 或 C 层 `cannot take the address of an rvalue` | 先落到局部变量（JSON-5） |
| 三级写链 `v["a"]["b"]["c"] = x` | 不可用：`a custom subscript write needs a statement and an lvalue receiver` | 逐级落局部变量再写（JSON-6） |
| 经 union 成员的方法调用 | 不支持（`unknown receiver type`） | 先取到局部变量再调用 |
| 自动转换 | 不存在 | 显式 `json_as_int` / `json_as_str` |
| 同名重载 | 不支持（C 层冲突） | 一个名字一个函数；编码只留单入口 |

### 5.1 链式访问的实测边界（v0.62.0）

**正例**——三级读链、下标结果作接收者、方法结果链都可用：

```ct
JsonRef server = doc["server"];
JsonRef host   = doc["server"]["host"];   // 两级链
JsonRef c      = doc["a"]["b"]["c"];      // 三级链：声明初始化位置
JsonRef port_ref;
port_ref = doc["a"]["b"]["c"];            // 三级链：赋值位置
JsonRef pick(JsonRef d) { return d["a"]["b"]["c"]; }   // 三级链：return 位置
int present = doc["server"].has(k);       // 下标结果作接收者
JsonRef b = doc.get("a").get("b");        // 方法结果链
```

**仍不可用**——临时值只能出现在语句/赋值的起始处，不能被继续取字段或作实参：

```ct
take(doc["a"]["b"]);          // 链式结果作函数实参
doc["a"]["b"]["c"].p != 0     // 链式结果取字段（C 层：cannot take the address of an rvalue）
doc["a"]["b"]["c"] = value;   // 三级写链：a custom subscript write needs a statement and an lvalue receiver
```

v0.62.0 放开的是「临时值作接收者」在语句/赋值起始处的限制；函数实参位置、rvalue 取字段与自定义下标写入仍未放开。拆成局部变量可绕过全部三种，登记为 `JSON-5`（实参/条件）与 `JSON-6`（三级写链）。

## 六、其他必须改写的写法

| 旧写法 | 问题 | 规范写法 |
| --- | --- | --- |
| `own JsonDoc *json_decode(...)` | `own` 不能写在返回类型 | `int json_decode(..., JsonRef *out)`；调用方不需要 `own` |
| `json_encode(Map*)` / `(Vec*)` / `(JsonRef*)` | 三重载 | `json_encode(JsonRef)` 单入口 |
| `#define JSON_TAG_NUM 2` | `#define` 不跨单元导出 | `pub enum JsonTag { ... }` |
| `char *s = ref;` | 无自动转换，且产生不兼容指针 warning | `json_as_str(ref, &len)` |
| `struct X { union { ... } v; }` | 匿名 union 硬错 | 具名 `union JsonValue` + 字段 |

## 七、对象键与字符串值

**结论：键统一为 `Str`，插入时深拷贝、容器持有；外部 `Str` 释放后对象仍可命中。**

```ct
Str k = str_from("name");
root.set_str(k, "rill", 4);   // 插入时深拷贝
k.release();                  // 外部释放后对象仍持有副本

// root.has(str_from("name")) == true
```

- 字符串值一律带长度（`Str`），因为 JSON 允许 `\u0000`；`char *` + `strlen` 会截断。
- 键可含 `\u0000`；`Str` 键的深拷贝与长度语义已实测（`Map<Str,int>` 键 release 后仍命中）。
- 键的分配与释放归容器：插入时复制，删除键/释放对象时释放；调用方的 `Str` 由调用方自己 release。
- `get` / `set` 的协议入口仍以 `char *` 接收字面量（见 §3.2 协议例外），内部立即转 `Str`；除此之外不收 `char *` 键。

## 八、验收（0.1.0 范围）

以下每条都在 CT `v0.53.0` 上复跑；构建与运行命令：

```sh
CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build test/j1_roundtrip.ct -I src -o /tmp/ctjson_test
/tmp/ctjson_test
CT_STD_DIR=/Users/samxx/trae-ws/ct-lang/lib/std ct build json.ct -o /tmp/jsongate
/tmp/jsongate | diff - json.expected.out
```

1. 解码后 `json_tag` 正确；对象按键序输出；`has` 区分缺失与 `null`。
2. `v["k"]` 读、`v["k"] = x` 写；跨单元在 `get`/`set` 为 `pub` 时可用；非 `pub` 必须编译失败。
3. 数字原文往返（`1.0`、长整数）；写入 int64 精确；浮点格式待定。
4. 写入共享：同一子对象挂两处，两边可见；编码输出两份。
5. `get_idx`：越界、负下标、非数组均返回空句柄；`null` 元素返回有效句柄。
6. 环：编码返回 `NULL` + `JSON_ERR_CYCLE`，不死循环。
7. 生命周期：`retain`/`release` 配对，计数归零释放；容器 drop 释放 `[0,len)` 元素后再释放数组，容量大于长度时不多释放。
8. 不支持项：`v[0]`、J4、J8、J11 明确失败或不存在入口。

## 九、待裁定清单

| 编号 | 问题 | 本版处理 |
| --- | --- | --- |
| Q-1 | 对象键强制 `Str` 还是允许 `char *` | **已裁定 A 并已确认例外**：`Str` 键、插入深拷贝、容器持有；协议入口 `get`/`set` 的 `char *` 例外见 §3.2 |
| Q-2 | 数字下标等 `v[0]`，还是先 `get_idx` | **已裁定 A**：0.1.0 只提供 `get_idx(i)`；写入口只给 `set_idx(i,v)`（越界报错、不扩容）与 `push(v)`；插入/删除不支持 |
| Q-3 | ADR-0001 规则 4 的「Drop 空桩」理由是否改写 | **已裁定 B**：规则 4 降级，不强制空 `impl Drop`；需自定义释放时显式写并说明释放什么；理由见 ADR-0001 注 |
| Q-4 | 容器元素由调用方显式 release，还是等容器自动 drop | **已裁定 A**：容器负责释放元素（Drop 循环 `json_release`）；泛型容器限制见 §3.7 |
| Q-5 | `requirements.md` 的 Q-01 是否随 ADR-0001 更新 | **已裁定 A**：已同步为已定结论并指向 ADR-0001 |
| Q-6 | 写入 `double` 的编码格式、整值浮点写法、`NaN`/`Inf` | 标为待定，不冻结 |

## 十、示例

```ct
import json;
#include <stdlib.h>
#include <string.h>

char *text = "{\"server\":{\"port\":8080,\"host\":\"db.local\"}}";
JsonRef root;
if (json_decode(text, strlen(text), &root) != JSON_OK) { return 1; }

JsonRef server = root["server"];   // 单层；不能写 root["server"]["host"]
int host_len = 0;
char *host = json_as_str(server["host"], &host_len);   // 显式转换，无自动转

Str k = str_from("debug");
root.set_bool(k, 1);               // 键是 Str；下标写入见 root["k"] = ref
k.release();

char *out = json_encode(root);
free(out);
json_free(root);                   // release 一次
```
