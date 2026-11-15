# ct-json 包规范 0.1.0（v0.52.0 重写版）

> 基线：CT `v0.52.0`。本版为全量重写，不继承旧版的时间线表述与「待落地」假设。
> 旧版：`ct-json-spec.md`（基于 CT v0.44.1）。差异见 `ct-json-0.1.0-rewrite-notes.md`。
> 六题已全部裁定（Q-1～Q-5 与规范重写）；仅写入浮点编码格式作为实现细节待定（Q-6），不阻塞主体。

## 一、定位

ct-json 做两件事：把 JSON 文本解码为可读写的树；把树编码回 JSON 文本。

长期目标是与 JavaScript 相同的访问方式（`data.server.port`、`data["server"]`、`items[0].name`）。v0.52.0 已支持**单层字符串键下标**，因此本版把 `v["server"]` 作为正式访问入口；数字下标与方法结果链式仍不可用，边界见 §五。

不做：流式解析、JSON Schema 校验、路径查询 API、把 JSON 语义内建进 CT 语言层。

## 二、类型定义（强制写法）

### 2.1 具名 union + tag（匿名 union 禁用）

v0.52.0 对匿名 union 具名字段是硬错：

```
error: an anonymous record member cannot have a name; tag the record instead
```

因此必须写成具名 union 类型，再以字段引用（改写前后对照见 §六）：

```ct
pub union JsonValue {
    int b;  long long i;  double d;
    Str s;      // 字符串值：带长度，可含 U+0000
    Str lit;    // 解析来的数字原文
    JsonObj *obj;  JsonArr *arr;
}
pub struct JsonNode {
    int tag;       // JsonTag
    int refs;      // 引用计数
    int num_kind;  // 0=原文, 1=int64, 2=double
    JsonValue v;
}
```

### 2.2 泛型必须写类型实参

裸 `Map *` / `Vec *` 在 CT 侧放行、C 侧报 `unknown type name`。所有容器类型必须写全实参，如 `Map<Str, int> *index`、`JsonObj *obj`、`JsonArr *arr`。

### 2.3 对象与数组容器

JSON 对象必须保插入序（ADR-0001 口径 2），不能依赖 `Map` 的遍历顺序。对象键已定为 `Str`（Q-1 裁定 A）：键一律用 `Str`，容器在建键时深拷贝并持有；`char *` 键不收。

```ct
pub struct JsonObj {
    int len;  int cap;
    Str *keys;             // 容器持有；建键时深拷贝
    JsonRef *vals;
    Map<Str, int> *index;  // 键 → 槽位，O(1)
}
pub struct JsonArr {
    int len;  int cap;
    JsonRef *items;
}
pub struct JsonRef {
    JsonNode *p;           // NULL 表示「没有这个值」
}
```

### 2.4 数值双轨（ADR-0004）

- 解析来的数字：`tag=JSON_TAG_NUM`、`num_kind=0`，原文放 `v.lit`，编码原样回吐（`1.0` 仍是 `1.0`，长整数不丢位）。
- 程序写入：整数 `num_kind=1`、`v.i`（`long long`，64 位精确）；浮点 `num_kind=2`、`v.d`（`double`）。
- 写入浮点的编码格式（`%.17g` / 最短往返、整值 `1.0` 的写法、`NaN`/`Inf`）**待定**，本版不冻结。

## 三、公开 API

所有公开类型与方法放在 `json.h.ct`；`get` / `set` **必须是 `pub`**，否则跨单元下标报 `type 'X' has no subscript: 'get' is private to its unit`。

### 3.1 解码

```ct
pub int json_decode(char *text, int len, JsonRef *out);
```

返回 `JSON_OK` 时 `out->p` 指向根节点；失败返回负错误码，`out` 不变。`len` 显式传入，不依赖 `strlen`。

### 3.2 读：字符串键下标（正式入口）

```ct
impl JsonRef {
    pub JsonRef get(char *key);   // 下标协议入口
    pub int has(Str key);
}
```

- `v["server"]` 展开为 `v.get("server")`（v0.52.0 Phase 52 协议）。
- `get` 返回句柄；键不存在时 `p == NULL`，用 `has` 区分「缺失」与「值为 null」。
- 单层可用；**不能写成 `v["a"]["b"]`**（方法结果作接收者，见 §五）。
- 键强制 `Str`（Q-1 裁定 A）：`get` 内部把传入的 `char *` 立即转成 `Str` 查找，临时 `Str` 由 `get` 释放；不把 `char *` 存进容器。
- **协议例外（需负责人确认）**：Q-1 要求「传 `char *` 是编译错误」，但 v0.52.0 的下标协议把字面量按 `char *` 传给 `get`。若 `get` 声明为 `Str`，`v["k"]` 在 C 层报 `passing 'char[2]' to parameter of incompatible type 'struct Str'`（实测）。因此 `get(char *)` 是唯一的 `char *` 入口，只作协议适配；其余键 API 一律收 `Str`。若不接受这个例外，`v["k"]` 与「`char *` 全禁」不能同时成立。

### 3.3 写：字符串键下标

```ct
impl JsonRef {
    pub void set(char *key, JsonRef value);   // 下标协议入口
    pub void set_int(Str key, long long value);
    pub void set_double(Str key, double value);
    pub void set_bool(Str key, int value);
    pub void set_str(Str key, char *text, int len);
    pub void set_null(Str key);
    pub void remove(Str key);
    pub void push(JsonRef value);     // 数组追加
}
```

- `v["a"] = x` 展开为 `v.set("a", x)`；`set` 按引用共享写入（ADR-0003），不拷贝、不转移。
- `set` 在插入时把 `char *` 转成 `Str` 并**深拷贝**；键的分配与释放归容器。
- 覆盖已有键：释放旧值的这一份引用，保留键序。
- 删除键：解除容器对值的一份引用，释放键副本，键序中移除该槽。
- 除 `get` / `set` 两个协议入口外，键参数一律是 `Str`；显式传 `char *` 给这些入口是编译错误，不做静默转换。

### 3.4 数字下标：0.1.0 只提供 `get_idx`（Q-2 裁定 A）

**`v[0]` 在 0.1.0 不支持**：v0.52.0 的用户类型下标协议只覆盖单层字符串键，数字参数不匹配；`v[0]` 会被展开成 `get(0)`，不是数字访问。已向 CT 提需求，方向是将来 `v[i]` 成立。

0.1.0 的数组读入口：

```ct
impl JsonRef {
    pub JsonRef get_idx(int i);
}
pub int json_arr_len(JsonRef v);   // 不是数组时返回 -1
```

- 返回第 `i` 个元素的句柄；元素为 `null` 时返回有效句柄，`json_tag` 为 `JSON_TAG_NULL`。
- `i < 0`、`i >= len`、非数组：返回 `p == NULL` 的空句柄，不崩、不分配；越界与缺失同值，长度先查 `json_arr_len`。
- 过渡方案：CT 支持用户类型数字下标后切换到 `v[i]`，届时 `get_idx` 是否保留另行决定。
- 数组写入口 0.1.0 只给两个（Q-2 已定）：
  - `set_idx(int i, JsonRef v)`：只覆盖已存在的下标；`i < 0` 或 `i >= len` 返回 `JSON_ERR_RANGE`，**不自动扩容**；成功时释放旧值这份引用。
  - `push(JsonRef v)`：追加到末尾。
- 插入与删除**0.1.0 不支持**：需要移动后续元素并使外部已持有的引用/下标失效，本版不做；原因写在此处，不写成「暂不支持」。

```ct
JsonRef items = root["items"];
JsonRef first = items.get_idx(0);              // 有效或空句柄
JsonRef oob   = items.get_idx(json_arr_len(items));  // p == NULL
```

### 3.5 取值转换（显式，无自动转换）

v0.52.0 没有自动类型转换，`int x = doc["port"]` 不成立。转换必须是显式调用：

```ct
pub int json_as_int(JsonRef v, long long *out);
pub int json_as_double(JsonRef v, double *out);
pub int json_as_bool(JsonRef v, int *out);
pub char *json_as_str(JsonRef v, int *len);
pub int json_tag(JsonRef v);
```

- 类型不匹配返回 `JSON_ERR_TYPE`，`out` 不变。
- `json_as_str` 返回借用指针，长度写入 `len`；不需要 NUL 结尾。
- 数字原文转 int64 溢出时返回 `JSON_ERR_RANGE`（ADR-0004 的表示已定，转换边界仍需按此实现）。

### 3.6 编码

```ct
pub char *json_encode(JsonRef root);   // 成功返回 malloc 字符串，调用方 free
```

单一入口，**不使用同名重载**（v0.52.0 仍不支持，三重载在 C 层报 `conflicting types`）。

- 对象按 `keys` 数组顺序输出。
- 解析来源的数字输出原文；写入的整数输出十进制；写入的浮点格式待定。
- 共享子对象出现两次时输出两份（与 `JSON.stringify` 一致，ADR-0003）。
- 环：编码期用祖先栈或深度上限拒绝，返回 `NULL` 并置 `JSON_ERR_CYCLE`，不得死循环（ADR-0005）。
- 失败返回 `NULL`；调用方不 free `NULL`。

### 3.7 生命周期

```ct
pub void json_retain(JsonRef v);
pub void json_release(JsonRef v);
pub void json_free(JsonRef v);   // 等价于 json_release 一次
```

- 写入共享引用：`set` 保留值的这一份引用；删除/覆盖释放旧引用。
- 复制 `JsonRef` 句柄**不改变**计数；要把句柄留在原持有者释放之后使用，必须显式 `json_retain`。
- `json_free` 是放弃自己这一份引用，不是无条件销毁；计数归零才释放（ADR-0006）。
- 成环会使计数不归零，视为调用方 bug；没有环收集器（ADR-0005）。
- 容器负责释放元素（Q-4 裁定 A）：`JsonObj` / `JsonArr` 的 `impl Drop` 对 `[0, len)` 内每个元素调用一次 `json_release`，然后释放键数组/元素数组，最后释放容器；使用者不手动 release 元素。
- 释放顺序：先元素（只释放已构造的 `len` 个），再底层数组，最后容器/键；`[len, cap)` 未构造，不释放。
- 元素不可 drop（标量或空句柄）时，`json_release` 为 no-op，容器照常继续。
- 实现限制（实测）：v0.52.0 为泛型容器生成的用户 struct `__elem_release` 是空体（`(void)e;`），只有 `Str` 等内建类型会真正 release。因此 ct-json **不把 `JsonRef` 放进 `Vec`/`Map` 后依赖它们的 release**，而用 `JsonArr`/`JsonObj` 自己显式循环；「容器负责」由容器代码完成，不依赖编译器为泛型生成元素 drop。
- 自定义释放：需要时显式写 `impl Drop` 并说明释放什么；**不要求空 `impl Drop`**（ADR-0001 规则 4 降级）。
- `json_free` 之后该句柄不得再用。

## 四、J1–J14 在 0.1.0 的判定

| 编号 | 0.1.0 | 写法或原因 |
| --- | --- | --- |
| J1 | 支持 | `JsonRef root = ...; JsonRef a = root["a"];` 用局部变量承接，不用 union 成员链 |
| J2 | 支持 | `json_arr_len(root)`；元素用 `get_idx(i)` |
| J3 | 支持 | `json_tag(root)` 分派；`pub enum` 可用 |
| J4 | **不支持** | 0.1.0 只返回负错误码，不提供 `JsonError{line,col,message}`；`message` 所有权无裁定 |
| J5 | 支持（改写） | `JsonRef s = doc["server"]; JsonRef h = s["host"];`；单表达式链式不支持 |
| J6 | 支持（改写） | `long long port; json_as_int(doc["port"], &port);`；无自动转换 |
| J7 | 支持 | `has` 区分缺失；`get` 不崩 |
| J8 | **不支持** | 0.1.0 不提供 `json_str` 等构造辅助，也不支持三重载 `json_encode`；原断言形态不成立 |
| J9 | 支持 | 只读编码；返回值由调用方 `free`，库内不释放 |
| J10 | 支持（改写） | `json_release` 计数归零；不再用 `delete doc` 断言 |
| J11 | **不支持** | 三层下标链依赖方法结果作接收者；v0.52.0 报 `a method call on a temporary is only allowed at the start of a statement or of an assignment` |
| J12 | 支持 | `json_as_*` + `json_tag` 逐元素判定 |
| J13 | 支持 | `json_as_str` 对非字符串返回 `JSON_ERR_TYPE` |
| J14 | 支持 | `json_as_int` 对 bool 返回 0/1；越界返回 `JSON_ERR_RANGE` |

不支持的三条是 J4、J8、J11，原因如上；不使用「暂不支持」这种含糊表述。

## 五、v0.52.0 的访问边界

| 能力 | 现状 | 规范写法 |
| --- | --- | --- |
| `v["k"]` 读 | 可用（`pub get`） | `v["k"]` |
| `v["k"] = x` 写 | 可用（`pub set`） | `v["k"] = x` |
| 跨单元下标 | `get`/`set` 必须 `pub` | `pub JsonRef get(char *k);` |
| 数字下标 `v[0]` | 不匹配，落 `get(0)` | **0.1.0 不支持**；用 `get_idx(i)`，越界返回空句柄 |
| 指针接收者 `p["k"]` | 不展开，落 C 语义 | 用 `JsonRef` 值句柄，不用 `JsonNode*` 做公开入口 |
| 链式 `v["a"]["b"]` | 不支持（临时值调用） | 拆成两条语句，用局部变量承接 |
| 方法结果链 `v.get("a").get("b")` | 不支持（同上） | 同上 |
| 经 union 成员的方法调用 | 不支持（`unknown receiver type`） | 先取到局部变量再调用 |
| 自动转换 | 不存在 | 显式 `json_as_int` / `json_as_str` |
| 同名重载 | 不支持（C 层冲突） | 一个名字一个函数；编码只留单入口 |

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
| Q-1 | 对象键强制 `Str` 还是允许 `char *` | **已裁定 A**：`Str` 键、插入深拷贝、容器持有；协议入口 `get`/`set` 的 `char *` 例外见 §3.2，待负责人确认 |
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
