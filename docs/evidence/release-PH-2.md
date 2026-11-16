# PH-2 收口 tag 与 g8 证据

- phase：PH-2
- 版本：`0.2.0`
- 收口提交：`875b0d82baab66d6fd843c951f1e8e7b3e7f4b6f`
- tag：`v0.2.0`（annotated；tag 对象 `98d7857e6dae1e317ecaf0423c3fcb8cb50d4353`）
- 日期：2026-11-17
- 依据：6.7 V-7 四项核对 + G8 `g8-version`

## 四项核对

```console
$ git tag -l 'v0.2.*'
v0.2.0
$ git cat-file -t v0.2.0
tag
$ git rev-parse v0.2.0^{commit}
875b0d82baab66d6fd843c951f1e8e7b3e7f4b6f
$ git rev-parse HEAD
875b0d82baab66d6fd843c951f1e8e7b3e7f4b6f
$ git branch -r --contains 875b0d8
  origin/HEAD -> origin/main
  origin/main
$ git ls-remote origin refs/tags/v0.2.0
98d7857e6dae1e317ecaf0423c3fcb8cb50d4353	refs/tags/v0.2.0
```

| # | 判据 | 结果 |
| --- | --- | --- |
| ① 名符合 `v<MAJOR>.<MINOR>.<PATCH>` | `v0.2.0` | 通过 |
| ② `git cat-file -t` = `tag` | `tag` | 通过 |
| ③ `rev-parse <tag>^{commit}` = 收口提交 | `875b0d8…` = `HEAD` | 通过 |
| ④ 提交可在远端追溯 | `origin/main` 含 `875b0d8` | 通过（分支推送 `619f3d9..875b0d8`） |
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
| 落点互比 | `0.2.0` | `ct.pkg#version` |
| MINOR 与 phase | `2` ↔ `PH-2` | 卡片 `version-minor: 2` |
| PATCH 与 fix 数 | `0`（本 phase 无未收 fix；JSON-12 属 0.1.3） | `ct.pkg`、`CHANGELOG.md` |
| CHANGELOG 与 tag | `0.2.0` ↔ `v0.2.0` | `CHANGELOG.md` |

## 与 6.5 的边界

- 分支推送：按 6.5 须用户指令；本轮按用户「继续推进，直到所有 phase 完成」的指令执行，
  推送 `619f3d9..875b0d8`（fetch 后 0 behind）。
- 对外发布：未执行。本证据只覆盖 phase tag 与分支同步。
- 本提交在 tag 之后，只补证据，不移动 tag 指向。
