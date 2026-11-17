# ct-json 0.1.0 规范提案 · 反证席评估

> **前提已变，结论待重估（2026-11-15）。** 本评审以「零分配视图」为默认前提；用户已裁定数据模型走树（[ADR-0001](../adr/0001-tree-data-model.md)），公开范围也包含写入与修改（[ADR-0002](../adr/0002-mutable-scope.md)）。文中以视图或只读为前提的结论保留原文，不再作为设计依据。

> 评估对象：`/Users/samxx/.trae-cn/assistant/2026-11-15/ct-json-spec/input/ct-json-spec.md`（下称「提案」，行号均指该文件）。
> 基线：ct-json `94952e9`（`json.ct` 2,286 行；`json.expected.out` 实跑 125 `ok` + 20 errors，逐字节匹配 golden）；ct-lang HEAD `5a75b90a`（评审期间被其他会话推进，文档引用以小節号为准）；编译器 `ct v0.44.1`；探针目录 `/tmp/ctprobe`（仓外，未入库）。
> 边界：只读实现与需求；不改实现、不改 `docs/requirements.md`、不 push。判定只接受三类证据：**实跑命令与原始输出**、**提案条款**、**仓库/规范 `path:line`**。给不出证据的写「未验证」，不把推测写成结论。

## 0 结论

**NO-GO：这份提案不能作为 0.1.0 的设计基线。**

方向可以保留（tagged value + 原生 `Map`/`Vec` + `int tag` 判别 + 不自造 DOM 类）；但当前文本不是「细节没写细」，而是：

1. **核心类型定义在 v0.44.1 上编译不过**：匿名 `union` 具名字段被 CT 硬拒，裸 `Map *` / `Vec *` 被 CT 硬拒；把类型移到导出单元后，`.h.ct` 又不接受泛型字段。
2. **生命周期假设为假**：`own` 不能接工厂返回值；`own` 写在返回类型上会生成非法 C；同单元 Drop 胶水对 `JsonRef`/`Map` 是空体；跨单元 Drop 在消费单元是**空桩**，`delete` 实际等于 `free`。
3. **下标链与自动转换两个语言依赖都不存在**：L1 是未立项提案、不在 Phase 40，且 L1 明确排除指针接收者；自动转换没有任何立项痕迹，实测只产生 warning 并把结构体地址当字符串。
4. **公开 API 形态不可实现**：三个同名 `json_encode` 在 C 层冲突；`Vec::get` 返回**值**不是指针；`#define` 不进生成头；`doc->root.v.obj->get(...)` 这类字段链接收者在 CT 层直接报错。
5. **数值 / 文本 / 错误三条契约相对现状全面回退**：全 `double` 丢 2^53 以上整数；`char *` 无法表达 `\u0000`、Map 键按 `strcmp` 截断碰撞；错误模型丢掉稳定错误码与字节偏移。

分级统计：

| 级别 | 条数 | 含义 |
| --- | --- | --- |
| P0 确有问题 | 10 | 不改就写不出可编译、可验收的实现 |
| P1 说得不够清晰 | 11 | 契约有歧义，实现者必须自己猜 |
| P2 只需补例子 | 5 | 示例/命令层面的缺口，不动设计 |
| J1–J14 | 可执行 4 / 不可执行 6 / 依赖未落地 4 | 见 §5 |

---

## 1 复核环境（可复现前提）

`ct` 单文件模式会在当前目录或二进制旁查找 `lib/std/*`。找不到时，泛型声明会被当成比较表达式，报一个**误导性**错误：

```
$ cd /tmp/ctjson-probe && /Users/samxx/.local/bin/ct t3.ct -o t3.c
t3.ct:5:8: error: use of an undeclared variable
```

本轮统一按下面方式修正环境；**下文所有泛型相关输出都来自修正后的环境**：

```
$ mkdir -p /tmp/ctprobe/bin /tmp/ctprobe/lib
$ cp /Users/samxx/.local/bin/ct /tmp/ctprobe/bin/ct
$ ln -s /Users/samxx/trae-ws/ct-lang/lib/std /tmp/ctprobe/lib/std
$ cd /tmp/ctprobe && ./bin/ct t3.ct -o t3.c && cc -std=c99 t3.c -o t3 && ./t3
3
```

基线 golden 复核：

```
$ cd /tmp/ctprobe && cp /Users/samxx/trae-ws/ct-json/json.ct . && ./bin/ct json.ct -o json.c
$ cc -std=c99 -Wall -Wextra json.c -o jsongold && ./jsongold > gold.out
$ grep -c '^ok ' gold.out
125
$ diff -q gold.out /Users/samxx/trae-ws/ct-json/json.expected.out && echo GOLDEN-MATCH
GOLDEN-MATCH
```

---

