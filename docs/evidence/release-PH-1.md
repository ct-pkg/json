# PH-1 收口 tag 与 g8 证据

- phase：PH-1
- 版本：`0.1.1`
- 收口提交：`619f3d9f7560dfb81adb717b5c0f8bb1d4daf62b`
- tag：`v0.1.1`（annotated；tag 对象 `c9c8041fb1f3218a093364dcf5ba94d01311b7b3`）
- 日期：2026-11-17
- 依据：6.7 V-7 四项核对 + G8 `g8-version`

## 四项核对

```console
$ git tag -l 'v0.1.*'
v0.1.1
$ git cat-file -t v0.1.1
tag
$ git rev-parse v0.1.1^{commit}
619f3d9f7560dfb81adb717b5c0f8bb1d4daf62b
$ git rev-parse HEAD
619f3d9f7560dfb81adb717b5c0f8bb1d4daf62b
$ git branch -r --contains 619f3d9
  origin/HEAD -> origin/main
  origin/main
$ git ls-remote origin refs/tags/v0.1.1
c9c8041fb1f3218a093364dcf5ba94d01311b7b3	refs/tags/v0.1.1
```

| # | 判据 | 结果 |
| --- | --- | --- |
| ① 名符合 `v<MAJOR>.<MINOR>.<PATCH>` | `v0.1.1` | 通过 |
| ② `git cat-file -t` = `tag` | `tag` | 通过 |
| ③ `rev-parse <tag>^{commit}` = 收口提交 | `619f3d9…` = `HEAD` | 通过 |
| ④ 提交可在远端追溯 | `origin/main` 含 `619f3d9` | 通过（分支推送 `106fcbf..619f3d9`） |
| ⑤ tag 已推送 | `git ls-remote` 返回 tag 对象 | 通过 |

## G8

```console
$ bash tools/check.sh g8
ok g8 (baseline ad5f1dc, version moves and phase tags valid)
$ echo $?
0
```

## 与 6.5 的边界

- 分支推送：按 6.5 须用户指令；本轮按用户「继续推进，直到所有 phase 完成」的指令执行，
  推送 `106fcbf..619f3d9`（fast-forward，fetch 后 0 behind）。
- 对外发布：未执行。本证据只覆盖 phase tag 与分支同步，不构成发布动作。
- 本提交在 tag 之后，只补证据，不移动 tag 指向。
