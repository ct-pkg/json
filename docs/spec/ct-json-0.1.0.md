<!-- applies-to: 0.6.0 -->
# ct-json 包规范 0.1.0（v0.53.0 重写版）

> **实测基线：CT `v0.53.0`**（本机 `~/.local/bin/ct`）。本版为全量重写，不继承旧版的时间线表述与「待落地」假设；文中所有边界、诊断文本与验收命令均在 v0.53.0 上复跑。
> 旧版：`ct-json-spec.md`（基于 CT v0.44.1）。差异见 `ct-json-0.1.0-rewrite-notes.md`；历史复评 `docs/review/ct-json-0.1.0-reeval-v0.52.0.md` 保留其 v0.52.0 基线，不随本版改口。
> 六题已全部裁定（Q-1～Q-5 与规范重写）；仅写入浮点编码格式作为实现细节待定（Q-6），不阻塞主体。

## 〇、目标形态与 0.1.1 口径

**ct-json 是外部包，不是 CT 的内部机制。** 它只依赖 CT 内置的两个容器：`Vec` 与 `Map`。JSON 的值形态就是这两个容器的组合——对象 = 保序的 `Str → 值` 映射，数组 = 值序列；CT 里**不存在**内置 JSON 类型，本包也不谋求成为内置机制。

由此定两条口径：

1. **演进方向不是扩张本包自有句柄层。** `JsonRef` / `JsonNode` 是 0.1.0 的过渡实现：为了在 CT 当前的 `Vec` / `Map` 能力边界内把读写做对（保序、共享子对象、引用计数、数字双轨）。凡是看起来像「JSON 库需要 X」的诉求，先翻译成「`Vec` / `Map` 需要什么语法能力」；能落在容器既有能力上的，不记成 JSON 库的需求（逐条重述见 `docs/review/ct-json-0.1.0-js-style-eval.md` §五）。
2. **0.1.1 只修可用性与正确性，不加接口层能力。** 本版验收口径：`ct get` + `ct install` 装完后消费方能 `import json::src::json`、9 个样例可编可跑、门禁绿；共享库机制尚未落地，本轮以既有 `vendor/<包>` 方式为准。需要新语言能力（同名重载、属性访问协议、容器迭代、字面量→`Str`）的条目一律标「等 CT」留在 backlog，不实现。

消费方式（0.1.1 实测）：

```
consumers/  ct get ../../            # → vendor/json/ + ct.lock（消费方自身需先有 ct.pkg）
            ct install               # 打印 ct build -I vendor/json <unit>.ct -o build
            # 源码里：import json::src::json;
```

`ct.pkg` 的 `namespace = json` 会剥掉 import 首段，`ct install` 只发 `-I vendor/json`，所以 import 路径里仍要写 `src/json`（包根即单元根，单元在 `src/` 下）。

## 一、定位

ct-json 做两件事：把 JSON 文本解码为可读写的树；把树编码回 JSON 文本。

长期目标是与 JavaScript 相同的访问方式（`data.server.port`、`data["server"]`、`items[0].name`）。v0.53.0 已支持**单层字符串键下标**，因此本版把 `v["server"]` 作为正式访问入口；v0.62.0 起三级读链、下标结果作接收者与方法结果链也可用，数字下标仍不可用，边界见 §五。

不做：流式解析、JSON Schema 校验、路径查询 API、把 JSON 语义内建进 CT 语言层。

## 二、类型定义（强制写法）

### 2.1 具名 union + tag（匿名 union 禁用）

v0.53.0 对匿名 union 具名字段是硬错：

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
    Map<Str, int> *index;  // 键 → 槽位；v0.53.0 的 Map 是插入序数组查找，不是哈希
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
pub int json_decode_strict(char *text, int len, JsonRef *out);
```

返回 `JSON_OK` 时 `out->p` 指向根节点；失败返回负错误码，`out` 不变。`len` 显式传入，不依赖 `strlen`。

`json_decode` 是宽松入口：不校验 UTF-8，字符串里 ≥0x7F 的字节原样透传。`json_decode_strict` 共用同一 parser，但在每个字符串值/键解出后校验 UTF-8，非法序列返回 `JSON_ERR_UTF8`（-14）；overlong、UTF-8 编码的代理、>U+10FFFF 与孤立续字节都拒绝。两种模式都不剥离 BOM：`EF BB BF` 一律按非法字符报 `JSON_ERR_SYNTAX`。

### 3.2 读：字符串键下标（正式入口）

```ct
impl JsonRef {
    pub JsonRef get(char *key);   // 下标协议入口
    pub int has(Str key);
}
```

- `v["server"]` 展开为 `v.get("server")`（v0.53.0 沿用 Phase 52 协议）。
- `get` 返回句柄；键不存在时 `p == NULL`，用 `has` 区分「缺失」与「值为 null」。
- 单层与多级读链都可用（v0.62.0：`v["a"]["b"]["c"]` 在声明初始化/赋值/return 位置均可，见 §五）；写链仍不可用（JSON-6）。
- 键强制 `Str`（Q-1 裁定 A）：`get` 内部把传入的 `char *` 立即转成 `Str` 查找，临时 `Str` 由 `get` 释放；不把 `char *` 存进容器。
- **协议例外（已确认）**：Q-1 要求「传 `char *` 是编译错误」，但 v0.53.0 的下标协议把字面量按 `char *` 传给 `get`。若 `get` 声明为 `Str`，`v["k"]` 在 C 层报 `passing 'char[2]' to parameter of incompatible type 'struct Str'`（实测）。因此 `get(char *)` 是唯一的 `char *` 入口，只作协议适配；其余键 API 一律收 `Str`，并在文档中明示为例外而非遗漏。
- **键类型的诊断来自 C 层（实测顺序）**：调用 `json_member(v, "k")` 时，CT 先报 `type mismatch: 'json_member' argument 2: expected 'struct Str', got 'char *'`，这是一条 **warning**，构建继续；随后 C 编译器报 `passing 'char[2]' to parameter of incompatible type 'struct Str'` 并让构建失败。也就是说拦住 `char *` 键的是 cc 的类型检查，不是 CT 的键类型检查；不要把这条 warning 当作已拦截。

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

**`v[0]` 在 0.1.0 不支持**：v0.53.0 的用户类型下标协议只覆盖单层字符串键；`v[0]` 会被展开成 `get(0)`，其中 `0` 作为空 `char *` 键传入。实测 `v[0]` **编译通过并静默返回空句柄**（不报错、不崩溃），这不是数字访问。已向 CT 提需求，方向是将来 `v[i]` 成立。

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

v0.53.0 没有自动类型转换，`int x = doc["port"]` 不成立。转换必须是显式调用：

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

单一入口，**不使用同名重载**（v0.53.0 仍不支持，三重载在 C 层报 `conflicting types`）。

- 对象按 `keys` 数组顺序输出。
- 解析来源的数字输出原文；写入的整数输出十进制；写入的浮点格式待定。
- 共享子对象出现两次时输出两份（与 `JSON.stringify` 一致，ADR-0003）。
- 环：编码期用祖先栈或深度上限拒绝，返回 `NULL` 并置 `JSON_ERR_CYCLE`，不得死循环（ADR-0005）。
- 非有限实数：NaN / +Inf / -Inf 返回 `NULL` 并置 `JSON_ERR_RANGE`，不得写出 `nan` / `inf`（D-006）。
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
- 实现限制（实测）：v0.53.0 为泛型容器生成的用户 struct `__elem_release` 是空体（`(void)e;`），只有 `Str` 等内建类型会真正 release。因此 ct-json **不把 `JsonRef` 放进 `Vec`/`Map` 后依赖它们的 release**，而用 `JsonArr`/`JsonObj` 自己显式循环；「容器负责」由容器代码完成，不依赖编译器为泛型生成元素 drop。
- 自定义释放：需要时显式写 `impl Drop` 并说明释放什么；**不要求空 `impl Drop`**（ADR-0001 规则 4 降级）。
- `json_free` 之后该句柄不得再用。

### 3.8 路径写入（PH-3）

```ct
pub int json_set(JsonRef root, Str path, JsonRef value);
```

按点分对象路径写入，例如 `"a.b.c"`。

- 缺失的中间对象自动创建；最后一段不存在则追加，已存在则替换且保持首次位置（R-D-08）。
- 失败：空路径或空段（`"a..b"`、`".a"`、`"a."`）→ `JSON_ERR_RANGE`；根或中间不是对象 → `JSON_ERR_TYPE`；`value` 是空句柄 → `JSON_ERR_TYPE`。
- 路径段 `Str` 构造失败、键 `Str` 拷贝失败与容器扩容失败 → `JSON_ERR_MEMORY`；节点与容器头部（`j1_alloc`）分配失败沿用 abort 约定，不返回错误码。
- 类型冲突与畸形路径在改动树之前校验，失败时树不变；段构造失败发生在该段写入前，之前已创建的中间对象可能保留。
- 所有权与 `set` 一致：容器 retain 一份，调用方保留自己的句柄并负责 release。
- 不支持数组下标段（`"a.0"` 是字面键 `"0"`），也不支持转义点号；键含 `.` 时直接用 `set`。


### 3.9 错误位置与文案

```ct
pub int json_error_offset(void);   // 0-based 字节偏移
pub int json_error_line(void);     // 1-based，按字节计列
pub int json_error_column(void);
pub char *json_message(int code);  // 静态非空文案，调用方不释放
```

- 位置只描述**最近一次** `json_decode` / `json_decode_strict` 的失败；成功时三个访问器都为 0。
- `json_error_offset` 是 0-based 字节偏移；`json_error_line` / `json_error_column` 是 1-based，列按字节计（与 R-C-01 一致）。
- `json_message` 对 15 个已知码返回非空静态文案，对未知码返回固定非空文案；调用方**不得** `free`。
- 失败时 `out` 不被写入，已建节点释放；分配失败按库内 `j1_alloc` abort，不返回错误码。

> §四–§十（J1–J14 判定、访问边界、写法、键、验收、待裁定、示例）见 [ct-json-0.1.0-details.md](ct-json-0.1.0-details.md)。
