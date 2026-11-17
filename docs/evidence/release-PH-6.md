# PH-6 收口 tag 与全门禁证据

- phase：PH-6
- 版本：`0.6.0`
- 收口提交：`0576bd464180173929f738988c24e149295ecc39`
- tag：`v0.6.0`（annotated）
- 日期：2026-11-17
- 依据：6.7 V-7 四项核对 + G4 `g4-version` + G8 + `check.sh all`

## 四项核对

```console
$ git tag -l 'v0.6.*'
v0.6.0
$ git cat-file -t v0.6.0
tag
$ git rev-parse v0.6.0^{commit}
0576bd464180173929f738988c24e149295ecc39
$ git rev-parse HEAD
0576bd464180173929f738988c24e149295ecc39
$ git branch -r --contains 0576bd4
  origin/HEAD -> origin/main
  origin/main
$ git ls-remote origin refs/tags/v0.6.0
```

| # | 判据 | 结果 |
| --- | --- | --- |
| ① 名符合 `v<MAJOR>.<MINOR>.<PATCH>` | `v0.6.0` | 通过 |
| ② `git cat-file -t` = `tag` | `tag` | 通过 |
| ③ `rev-parse <tag>^{commit}` = 收口提交 | `0576bd4…` = `HEAD` | 通过 |
| ④ 提交可在远端追溯 | `origin/main` 含 `0576bd4` | 通过 |
| ⑤ tag 已推送 | `git ls-remote` 返回 tag 对象 | 通过 |

## 全门禁

```console
$ bash tools/check.sh all
=== g0
ok g0 (block, 8 rows, routing, deviations, session map, pkg check, version 0.6.0)
=== g1
ok g1 (39 requirement ids, no TBD, 6 phase card(s))
=== g2
ok g2 (39 R rows, 39 ACC ids, 34 public symbols)
=== g3
ok g3 (j1_roundtrip, json.expected.out, zero warnings)
=== g4
ok g4 (6 snippets, 2 fail samples, anchors, readme, version 0.6.0)
=== g5
ok g5 (22 tasks, 9 red proofs, gate negatives covered)
=== g6
ok g6 (14 issue(s), statuses and evidence valid)
=== g7
ok g7 (secret scan clean, ASan run clean; detect_leaks unavailable on this platform)
=== g8
ok g8 (baseline ad5f1dc, version moves and phase tags valid)
=== g9
ok g9 (spec 1.15.0 @ 1619a8c37c46)
=== surface
ok export-surface (41 symbols; requires "ct >= 0.53.0")
=== summary: 0 unimplemented gate(s)
$ echo $?
0
```

## 版本四项（6.7 `g4-version`）

| 项 | 值 | 出处 |
| --- | --- | --- |
| 落点互比 | `0.6.0` | `ct.pkg#version`；README/规范/snippets 的 `applies-to` |
| MINOR 与 phase | `6` ↔ `PH-6` | 卡片 `version-minor: 6` |
| PATCH 与 fix 数 | `0`（本 phase 无 fix） | `ct.pkg`、`CHANGELOG.md` |
| CHANGELOG 与 tag | `0.6.0` ↔ `v0.6.0` | `CHANGELOG.md` |

## 与 6.5 的边界

- 分支推送按用户「继续推进，直到所有 phase 完成」的指令执行（fetch 后 0 behind）。
- 对外发布（registry/公告）未执行；本证据只覆盖 phase tag 与分支同步。
- 本提交在 tag 之后，只补证据，不移动 tag 指向。
