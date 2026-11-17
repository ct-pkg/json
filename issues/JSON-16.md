---
id: JSON-16
status: open
priority: P1
owner: 上游 ct（`ct get` 版本解析）
created: 2026-11-17
last-touched: 2026-11-17
block: 上游版本解析；本包文档改用显式 `@0.6.0` 规避
evidence: v0.63.2；全新 HOME 下 `ct get https://github.com/ct-pkg/json` 落到 `ct/json 0.1.1`（提交 619f3d9），远端已有 v0.1.1…v0.6.0
---

# JSON-16 `ct get <GitHub URL>` 默认取最低 tag（应为最新）

- 归属：**上游 ct（`ct get` 的默认版本解析）**。
- 优先级：P1（按 README 的默认命令装到最旧版本，文档与行为不一致）。
- 影响面：任何不写 `@<version>` 的 GitHub 消费方。
- 关联：JSON-15、README「安装」。

## 触发条件

消费方执行 `ct get https://github.com/ct-pkg/json`（不带 `@<range>`）。

## 最小复现

```console
$ rm -rf /tmp/cthome2 /tmp/consumer2 && mkdir -p /tmp/cthome2 /tmp/consumer2
$ cd /tmp/consumer2
$ printf 'name = consumer\nversion = 0.1.0\nlicence = MIT\n' > ct.pkg
$ HOME=/tmp/cthome2 ct get https://github.com/ct-pkg/json
installed 1 package(s)
$ cat ct.lock
# ct-lock 2
ct/json 0.1.1 git https://github.com/ct-pkg/json 619f3d9... src sha256:65afc65...
```

远端实际 tag：`v0.1.1`、`v0.2.0`、`v0.3.0`、`v0.4.0`、`v0.5.0`、`v0.6.0`；
缓存 `.ct-pkg.tags` 也列出了全部，但默认解析选了最旧的 `v0.1.1`。

范围探测（同一 fresh HOME）：

```console
$ ct get https://github.com/ct-pkg/json@*        # 与默认等价
ct/json 0.1.1 ...          # 最低 tag
$ ct get https://github.com/ct-pkg/json@0.6      # 或 @0.6.0
ct/json 0.6.0 ...
$ ct get https://github.com/ct-pkg/json@latest
ctc: no tag of 'json' satisfies 'latest'          # rc=1
```

预期：默认与 `*` 应取**最高**满足版本（最新），与 `ct get json` 的「拉取最新版」一致；
当前取最低。

显式指定可拿到最新：

```console
$ HOME=/tmp/cthome2 ct get https://github.com/ct-pkg/json@0.6.0
$ cat ct.lock
# ct-lock 2
ct/json 0.6.0 git https://github.com/ct-pkg/json 0576bd4... src sha256:f2968fe...
```

## 期望行为

默认解析到最高满足版本（当前 `0.6.0`），或拒绝并要求显式 `@<range>`；不应静默落到最低版本。

## 本包绕行

README/规范里的 GitHub 命令一律写 `@0.6.0`；本地开发用 `ct get /path/to/ct-json`。

## 阻塞点

上游 `ct get` 的版本选择逻辑。
