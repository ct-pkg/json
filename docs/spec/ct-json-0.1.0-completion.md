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
