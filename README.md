<!-- applies-to: 0.6.0 -->
# ct-json — CT 的引用计数 JSON 树

`ct-json` 是 CT 的外部包：把一段内存里的 JSON 字节严格解码为可读写的树，再把树编码回 JSON 字节。零分配只读视图是 0.1.0 的历史实现，已废止；当前唯一公开模型是树。

- 版本：`0.6.0`（以 `ct.pkg#version` 为准）
- 规范：[docs/spec/ct-json-0.1.0.md](docs/spec/ct-json-0.1.0.md)（公开 API 与模型）
- 验收：[docs/acceptance-map.md](docs/acceptance-map.md)（R-* → ACC-*）
- 变更：[CHANGELOG.md](CHANGELOG.md)

## 定位与边界

做：严格 RFC 8259 词法、树模型读取、字符串键下标、路径写入、编码、稳定错误码与位置。

不做：流式/SAX、注释与尾逗号、JSON Schema、JSON Pointer/Patch、美化/排序、任意用户类型编码、UTF-8 规范化、BOM 剥离、数组路径下标、C ABI 承诺。

## 安装

`ct get` 把包放进 `~/.ct/pkg/<publisher>/<name>/<version>`，并在消费方根目录写 `ct.lock`（v2）。**v0.62.0 起没有 `vendor/`**；旧文档里的 `-I vendor/json` 与 `import json::src::json` 已过期。

```sh
# GitHub：显式写版本；不写 @<version> 会落到最旧的 v0.1.1（JSON-16）
ct get https://github.com/ct-pkg/json@0.6.0

# 本地开发：按本仓 ct.pkg 的 version
ct get /path/to/ct-json

ct install     # 打印 ct build <unit>.ct -o build；并打印 # lock-format: v2
```

```ct
import json;
```

- `ct.lock` 一行记录：`ct/json <version> git|dir <source> <sha|-> src sha256:<digest>`。
- **当前断点（JSON-15）**：v0.63.2 下 `ct build` 解析到 `src/json.h.ct:86` 时，ctc（L0）报
  `expected a field name`（`Map<Str, int>` 等泛型声明），消费链在编译阶段断开。
- 要求 `ct >= 0.53.0`（`ct.pkg#requires` 与 `//@ct-requires` 一致）；store 模型本身要 `ct >= 0.62.0`。

## 快速开始

解码、读、写、编码的最小形态：

```ct
JsonRef doc = { .p = 0 };
if (json_decode(text, len, &doc) != JSON_OK) return 1;

Str key = str_from("server");
JsonRef server = json_member(doc, key);
key.release();

long long port = 0;
JsonRef p = server.get("port");          // 或 server["port"]
if (json_as_int(p, &port) == JSON_OK) { /* ... */ }

JsonRef fresh = { .p = 0 };
Str path = str_from("a.b.c");
json_decode("7", 1, &fresh);
if (json_set(doc, path, fresh) != JSON_OK) { /* ... */ }
path.release();

char *out = json_encode(doc);
free(out);
json_free(doc);
```

完整可运行文件在 [docs/snippets/](docs/snippets/README.md)：`read_str.ct`、`write_str.ct`、`chain.ct`、`chain3.ct`、`numeric_index.ct`、`cross_unit.ct`。

## API 索引

每个 `pub` 符号一行；完整语义见规范 §三。

| 符号 | 作用 |
| --- | --- |
| `JsonTag` / `JsonCode` | 类型与错误码枚举 |
| `JsonRef` | 8 字节引用计数句柄 |
| `JsonNode` / `JsonValue` | 节点与具名 union |
| `JsonObj` / `JsonArr` | 对象与数组节点 |
| `json_decode(text, len, out)` | 宽松解码；不校验 UTF-8 |
| `json_decode_strict(text, len, out)` | 严格 UTF-8；非法序列报 `JSON_ERR_UTF8` |
| `json_encode(root)` | 编码；调用方 `free`；失败返回 NULL |
| `json_set(root, path, value)` | 点分对象路径写入；缺失中间对象自动创建 |
| `json_retain` / `json_release` / `json_free` | 引用计数 |
| `json_tag` / `json_is_null` | 类型判别 |
| `json_as_bool` / `json_as_int` / `json_as_double` / `json_as_str` | 显式取值 |
| `json_obj_len` / `json_arr_len` / `json_member` / `json_obj_key_at` | 容器读取 |
| `v.get(k)` / `v.set(k, x)` / `v.has(k)` | 字符串键下标协议 |
| `v.get_idx(i)` / `v.set_idx(i, x)` / `v.push(x)` | 数组访问与追加 |
| `v.set_str` / `v.set_int` / `v.set_double` / `v.set_bool` / `v.set_null` / `v.remove` | 写入辅助 |
| `json_last_error` / `json_error_offset` / `json_error_line` / `json_error_column` | 最近一次解码错误与位置 |
| `json_message(code)` | 错误码文案（静态，不释放） |

## 限制

- **深度固定 64 层**，没有调高入口；65 层返回 `JSON_ERR_DEPTH`。
- **数字双轨**：解析来的数字保留原文；程序写入分 int64 / double；非有限实数拒绝。
- **错误位置按字节**：`json_error_line/column` 是 1-based，列按字节计。
- **失败不返回部分树**；`json_free` 后才释放整棵树。
- **BOM 一律拒绝**，不自动剥离；不校验 UTF-8（除非用 strict 入口）。
- **路径写入只支持对象键**：不支持数组段、转义点号；键含 `.` 请用 `set`。
- **没有流式解析、美化、键排序、JSON Pointer/Patch**。

## 版本与兼容

产品版本见 `ct.pkg#version`，按 phase 收口递增 MINOR，按 fix 递增 PATCH；phase 收口打 annotated tag。0.x 期间 API 可能变化，不承诺 C ABI。

## 许可

MIT。见 [LICENSE](LICENSE)。静态链入闭源程序只需保留版权与许可声明。

## License

MIT. See [LICENSE](LICENSE). Linking into a closed-source program only requires
keeping the copyright and permission notice.

## English summary

`ct-json` is an external CT package that decodes in-memory JSON into a reference-counted tree and encodes it back. Tree-only public model; 64-level hard depth cap; strict/lenient UTF-8 entries; error codes plus byte offset/line/column; `json_set` path writes. MIT licensed. See the Chinese sections above and the spec under `docs/spec/`.
