# ct-json 0.1.0 反证（二）

> 承接 [01](ct-json-0.1.0-rebuttal-01.md) 的 §2 P0-1…P0-4；章节编号不变。

## 2 P0 · 确有问题

### P0-1 类型定义编译不过（§2.1:28-37）

**条款**：`struct JsonRef { int tag; union { … } v; }`，其中 `Map *obj;` / `Vec *arr;`。

**实测 1：匿名 `union` 具名字段**

```
$ cd /tmp/ctprobe && ./bin/ct r1_anon.ct -o r1.c
r1_anon.ct:8:7: error: an anonymous record member cannot have a name; tag the record instead
rc=1
```

规范同款拒绝：`ct-lang/docs/language-spec.md:930-931`（`union { int i; } u;` 报同一句）。

**实测 2：裸泛型**

```
$ cd /tmp/ctprobe && ./bin/ct r2_bare.ct -o r2.c
r2_bare.ct:2:49: error: generic struct 'Map' needs type arguments in a type position
rc=1
```

**实测 3：把类型移到导出单元后，泛型字段仍不可写**

```
$ cd /tmp/ctprobe/c3 && cat H.h.ct
pub struct Holder { Vec<int> *v; };
$ ./bin/ct build main.ct -o app
./H.h.ct:1:1: error: expected a field name
rc=0
```

换成 `struct Vec<int> *v`、`Vec <int> * v`、值字段 `Vec<int> v`，三种写法同一错误；换成 `void *v` 才通过（`sizeof(Holder)=8`）。也就是说：**包无法原样导出带 `Map`/`Vec` 字段的 `JsonRef`**。

**修法**：`union JsonValue { … }` 命名 + 字段写 `Map<char *, JsonRef> *obj;`；导出面若必须跨单元，`JsonRef` 里只能放 `void *obj` / `void *arr`，包内再 cast，或把树类型定义下沉到消费单元。这两条都要写进规范，否则 §2.1、§10 的「已支持」是错的。

### P0-2 生命周期核心为假（§2.2:61、§7.1:196-206、§7.3:224-229）

**条款**：`own JsonDoc *doc = json_decode(text);`，块退出自动释放；`JsonDoc` 的 Drop 递归释放整棵树。

**实测 1：`own` 只接受 `malloc|calloc` 初始化**

```
$ cd /tmp/ctprobe && ./bin/ct p1b_own.ct -o p1b.c
p1b_own.ct:30:1: error: 'own' requires a malloc or calloc initialiser
ctc: 1 error(s) generated
rc=1
```

规范：`ct-lang/docs/language-spec.md:396-399`，`bindings-and-patterns.md:370-373`。`json_decode` 是工厂返回值，**`own` 这一行写法永远过不了编译**。

**实测 2：`own` 写进返回类型 → 非法 C**

```
$ ./bin/ct p12.ct -o p12.c; echo ct-rc=$?
ct-rc=0
$ cc -std=c99 -Wall -Wextra p12.c -o p12
p12.c:49:8: error: unknown type name 'own'
   49 | static own struct JsonDoc * json_decode(char *);
p12.c:176:8: error: unknown type name 'own'
```

即 §3.1:74-75 的签名本身不可编译（CT 解析通过、C 编译失败）。

**实测 3：同单元自动胶水是空体**

把 `JsonDoc` 与一个真实的 `Map<char*, JsonRef> *` 拼起来，`delete doc` 后生成：

```c
static void __attribute__((unused)) JsonDoc_Drop_drop(void *self) {
    struct JsonDoc *_self = (struct JsonDoc *)self;
    (void)_self;
}
```

（`/tmp/ctprobe/p6b.c:305-309`）。原因：无显式 `impl Drop` 时，胶水只递归 `uses_drop` 字段（`language-spec.md:2309`），而 `JsonRef` 不是 `use Drop`，`Map`/`Vec` 字段根本不参与。

**实测 4：跨单元 Drop 是空桩**

包单元 `dp/Doc.h.ct` 有显式 `impl Drop for JsonDoc { … fprintf(stderr, "[lib] …") }`，消费单元 `delete p`：

```
$ cd /tmp/ctprobe/dropkg && ./bin/ct build src/main.ct -o app && ./app
done
run-rc=0
```

`[lib]` 一行都没打。生成物里消费单元自带一个空桩（`.ctbuild/main.c:8-13`），真实现是 `Doc.c` 里的 `static`：

```c
/* main.c */
static void __attribute__((unused)) dp_JsonDoc_Drop_drop(void *self) {
    struct dp_JsonDoc *_self = (struct dp_JsonDoc *)self;
    (void)_self;
}
if (p) { dp_JsonDoc_Drop_drop(p); free(p); p = 0; }   /* 实际只等于 free */
```

**实测 5：容器元素释放对 `JsonRef` 是空操作**

```c
static void __attribute__((unused)) Map_char_p_JsonRef__elem_release(struct JsonRef *e)
{
    (void)e;
}
```

（`/tmp/ctprobe/p6b.c:270-273`；与 `Vec.h.ct:517-537` 的 `release` 实现一致：只对元素调 `__ct_elem_release`。）

**结论**：`own` + Drop 这条路在「包定义类型、消费方释放」的形态下**不可能成立**。J10 不是「未实现」，是**按提案写法必然失败**。

**修法**：删掉 `own` 与「Drop 自动释放」的全部叙述；公开 `void json_free(JsonDoc *doc)`，在包内实现显式递归释放（值、键、`Map`/`Vec` 本体），并在 README 写明调用方必须调用。若坚持 Drop，必须先修跨单元空桩与容器元素协议，超出本包范围。

### P0-3 下标链与自动转换都不存在（§5:145-166、§6:172-187、§10:288、J5/J6/J7/J11）

**条款**：`doc["server"]["host"]`、`char *host = doc["server"]["host"]`；§10 称 L1「已立项，Phase 40」。

**实测 1：下标原样落到 C**

```
$ cd /tmp/ctprobe && ./bin/ct p8.ct -o p8.c; echo ct-rc=$?
ct-rc=0
$ cc -std=c99 -Wall -Wextra p8.c -o p8
p8.c:161:29: error: array subscript is not an integer
  161 |     struct JsonRef * h = doc["host"];
```

**实测 2：自动转换不存在，且只给 warning**

```
$ cd /tmp/ctprobe/pkg && ./bin/ct build src/main2.ct -o app3
src/main2.ct:11:12: warning: incompatible pointer types initializing 'char *' with an expression of type 'struct jsonext_JsonRef *'
$ ./app3
<输出为一个控制字节，地址被当成字符串>
```

**文档事实**：

- `ct-lang/docs/roadmap.md:56`：Phase 40 = `errdefer + err: 错误出口 + 尾随声明`（v0.40.0 已收口）。
- `ct-lang/docs/proposals/custom-index-protocol.md:3-11`：下标协议「**提案 / 未立项 / 未过分析，不作数**」「不认领 phase 编号」；`docs/planning/requirements-pool.md:9-20`：`REQ-L1` `status = open`。
- `custom-index-protocol.md:39`：「**不做指针接收者**：`struct X *p; p[k]` 保持 C 的指针算术」；`:100` 表格再次写明 `p[k]` → 原样 C 指针算术。
- 提案里 `doc` 是 `JsonDoc *`、`Map::get` 返回 `JsonRef *`，链上每一跳都是指针接收者。**即使 L1 按现提案落地，`doc["a"]["b"]` 也不成立。**

- 另有一条推演（未实测，因 L1 未实现）：L1 只校验方法名 + 参数个数（`custom-index-protocol.md:48`），一个 `JsonRef::get` 无法同时接受 `char *` 键和 `int` 下标；`doc["items"][0]` 与 `doc["server"]` 需要两个不同类型的 `get`，而 CT 没有函数重载（见 P0-4）。

**修法**：本期把 J5/J6/J7/J11、§5、§6.1、示例 1/5 全部改成「本期不主张」，统一用 `.get()` / `.len()`；等 REQ-L1 立项并补指针接收者后再单开一版。

### P0-4 公开 API 形态不可实现（§3.2:84-86、§3.3、§4:124-129、J1/J2）

**实测 1：三个 `json_encode` 同名**

```
$ cd /tmp/ctprobe && ./bin/ct p2b.ct -o p2b.c; echo ct-rc=$?
ct-rc=0
$ cc -std=c99 -Wall -Wextra -c p2b.c
p2b.c:570:8: error: conflicting types for 'json_encode'
p2b.c:448:8: note: previous declaration is here
p2b.c:573:8: error: conflicting types for 'json_encode'
p2b.c:448:8: note: previous declaration is here
```

CT 没有函数重载语法，也不做同名签名冲突检查，名字冲突要等 `cc` 才暴露。

**实测 2：`Vec::get` 返回值拷贝**

```
$ cd /tmp/ctprobe && ./bin/ct p16.ct -o p16.c; echo ct-rc=$?
ct-rc=0
$ cc -std=c99 -Wall -Wextra p16.c -o p16
p16.c:347:26: error: initializing 'struct JsonRef *' with an expression of incompatible type 'struct JsonRef'
```

`Vec.h.ct:94-99`：`pub T get(int i)`。所以 §13 示例 2:359 的 `JsonRef *item = arr->get(i);` 也是错的；`item != NULL` 对值拷贝没有意义。J12 的「每个元素 tag 正确」必须写成 `arr->get(i).tag`（值拷贝）。

**实测 3：`#define` 不进生成头**

```
$ cd /tmp/ctprobe/c1 && ./bin/ct build main.ct -o app
main.ct:6:20: error: use of undeclared identifier 'JSON_TAG_NUM'
```

`JSON_TAG_*` 作为公开常量（§2.1:39-44）不可用。替代写法 `pub enum JsonTag { … }` 实测可跨单元使用（同一目录 `app2` 打印 `2`）。

**实测 4：`doc->root.v.obj->get(...)` 字段链接收者不成立**

```
$ cd /tmp/ctprobe && ./bin/ct p14.ct -o p14.c
p14.ct:32:1: error: cannot resolve the method trait (unknown receiver type)
```

同一形态在 J2 的 `doc->root.v.arr->len()` 也复现（`p21.ct:22:1`）。必须先落到局部变量：

```
Map<char *, JsonRef> *m = doc->root.v.obj;
printf("%g\n", m->get("a")->v.n);   /* 实测输出 1 */
```

**实测 5：`map trait` 可行，但配方必须写 mangled C 名**

```
$ cd /tmp/ctprobe/pkg && ./bin/ct build src/main.ct -o app4 && ./app4
to_str=0x0 to_int=8080
```

成立条件是：`map trait` 放 `.m.ct`（`bindings-and-patterns.md:725-726` 明确只允许 `.m.ct`），消费方 `import` 映射单元，且 recipe 写 `jsonext_json_ref_to_str(v)` 这种 **C 层 mangled 名**；写成 `json_ref_to_str(v)` 会 `call to undeclared function`。提案 §4 只给了 trait 定义，没有给这一层约束。

**修法**：编码入口改成具名三件套（`json_encode_map` / `json_encode_vec` / `json_encode_scalar`）；J1/J2 的断言先落局部变量；tag 常量改 `pub enum`；§4 补 `.m.ct` + import + mangled recipe 的完整约束。

