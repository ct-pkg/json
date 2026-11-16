# PH-3 收口 tag 与 g8 证据

- phase：PH-3
- 版本：`0.3.0`
- 收口提交：`7d48321171b1ac872bc59e55092eccb8d955a803`
- tag：`v0.3.0`（annotated；tag 对象 `7b444c55bee0dc572963b4ab39903629782d54f4`）
- 日期：2026-11-17
- 依据：6.7 V-7 四项核对 + G8 `g8-version`

## 四项核对

```console
$ git tag -l 'v0.3.*'
v0.3.0
$ git cat-file -t v0.3.0
tag
$ git rev-parse v0.3.0^{commit}
7d48321171b1ac872bc59e55092eccb8d955a803
$ git rev-parse HEAD
7d48321171b1ac872bc59e55092eccb8d955a803
$ git branch -r --contains 7d48321
  origin/HEAD -> origin/main
  origin/main
$ git ls-remote origin refs/tags/v0.3.0
7b444c55bee0dc572963b4ab39903629782d54f4	refs/tags/v0.3.0
```

| # | 判据 | 结果 |
| --- | --- | --- |
| ① 名符合 `v<MAJOR>.<MINOR>.<PATCH>` | `v0.3.0` | 通过 |
| ② `git cat-file -t` = `tag` | `tag` | 通过 |
| ③ `rev-parse <tag>^{commit}` = 收口提交 | `7d48321…` = `HEAD` | 通过 |
| ④ 提交可在远端追溯 | `origin/main` 含 `7d48321` | 通过（分支推送 `072c9af..7d48321`） |
| ⑤ tag 已推送 | `git ls-remote` 返回 tag 对象 | 通过 |

## G8

```console
$ bash tools/check.sh g8
ok g8 (baseline ad5f1dc, version moves and phase tags valid)
$ echo $?
0
```

## 版本四项（6.7 `g4-version`）

| 项 | 值 | 出处 |
| --- | --- | --- |
| 落点互比 | `0.3.0` | `ct.pkg#version` |
| MINOR 与 phase | `3` ↔ `PH-3` | 卡片 `version-minor: 3` |
| PATCH 与 fix 数 | `0`（phase 内修复并入 0.3.0） | `ct.pkg`、`CHANGELOG.md` |
| CHANGELOG 与 tag | `0.3.0` ↔ `v0.3.0` | `CHANGELOG.md` |

## 与 6.5 的边界

- 分支推送按用户「继续推进，直到所有 phase 完成」的指令执行（fetch 后 0 behind）。
- 对外发布未执行；本证据只覆盖 phase tag 与分支同步。
- 本提交在 tag 之后，只补证据，不移动 tag 指向。
