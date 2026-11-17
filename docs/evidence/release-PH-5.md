# PH-5 收口 tag 与 g8 证据

- phase：PH-5
- 版本：`0.5.0`
- 收口提交：`6bbd2a2b42e3ffef004abb33aa5d68c6f6f2de22`
- tag：`v0.5.0`（annotated）
- 日期：2026-11-17
- 依据：6.7 V-7 四项核对 + G8 `g8-version`

## 四项核对

```console
$ git tag -l 'v0.5.*'
v0.5.0
$ git cat-file -t v0.5.0
tag
$ git rev-parse v0.5.0^{commit}
6bbd2a2b42e3ffef004abb33aa5d68c6f6f2de22
$ git rev-parse HEAD
6bbd2a2b42e3ffef004abb33aa5d68c6f6f2de22
$ git branch -r --contains 6bbd2a2
  origin/HEAD -> origin/main
  origin/main
$ git ls-remote origin refs/tags/v0.5.0
```

| # | 判据 | 结果 |
| --- | --- | --- |
| ① 名符合 `v<MAJOR>.<MINOR>.<PATCH>` | `v0.5.0` | 通过 |
| ② `git cat-file -t` = `tag` | `tag` | 通过 |
| ③ `rev-parse <tag>^{commit}` = 收口提交 | `6bbd2a2…` = `HEAD` | 通过 |
| ④ 提交可在远端追溯 | `origin/main` 含 `6bbd2a2` | 通过 |
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
| 落点互比 | `0.5.0` | `ct.pkg#version` |
| MINOR 与 phase | `5` ↔ `PH-5` | 卡片 `version-minor: 5` |
| PATCH 与 fix 数 | `0`（JSON-9/11/13/14 属 phase 内修复并入 0.5.0） | `ct.pkg`、`CHANGELOG.md` |
| CHANGELOG 与 tag | `0.5.0` ↔ `v0.5.0` | `CHANGELOG.md` |

## 与 6.5 的边界

- 分支推送按用户「继续推进，直到所有 phase 完成」的指令执行（fetch 后 0 behind）。
- 对外发布未执行；本证据只覆盖 phase tag 与分支同步。
- 本提交在 tag 之后，只补证据，不移动 tag 指向。
