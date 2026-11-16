# PH-4 收口 tag 与 g8 证据

- phase：PH-4
- 版本：`0.4.0`
- 收口提交：`f2a624e7a56d06deca2b0cf0ff64e9b54e343889`
- tag：`v0.4.0`（annotated）
- 日期：2026-11-17
- 依据：6.7 V-7 四项核对 + G8 `g8-version`

## 四项核对

```console
$ git tag -l 'v0.4.*'
v0.4.0
$ git cat-file -t v0.4.0
tag
$ git rev-parse v0.4.0^{commit}
f2a624e7a56d06deca2b0cf0ff64e9b54e343889
$ git rev-parse HEAD
f2a624e7a56d06deca2b0cf0ff64e9b54e343889
$ git branch -r --contains f2a624e
  origin/HEAD -> origin/main
  origin/main
$ git ls-remote origin refs/tags/v0.4.0
```

| # | 判据 | 结果 |
| --- | --- | --- |
| ① 名符合 `v<MAJOR>.<MINOR>.<PATCH>` | `v0.4.0` | 通过 |
| ② `git cat-file -t` = `tag` | `tag` | 通过 |
| ③ `rev-parse <tag>^{commit}` = 收口提交 | `f2a624e…` = `HEAD` | 通过 |
| ④ 提交可在远端追溯 | `origin/main` 含 `f2a624e` | 通过 |
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
| 落点互比 | `0.4.0` | `ct.pkg#version` |
| MINOR 与 phase | `4` ↔ `PH-4` | 卡片 `version-minor: 4` |
| PATCH 与 fix 数 | `0`（JSON-10 属 phase 内修复并入 0.4.0） | `ct.pkg`、`CHANGELOG.md` |
| CHANGELOG 与 tag | `0.4.0` ↔ `v0.4.0` | `CHANGELOG.md` |

## 与 6.5 的边界

- 分支推送按用户「继续推进，直到所有 phase 完成」的指令执行（fetch 后 0 behind）。
- 对外发布未执行；本证据只覆盖 phase tag 与分支同步。
- 本提交在 tag 之后，只补证据，不移动 tag 指向。
