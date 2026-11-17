# 门禁负例红证

> 目的：证明已实现的每道门禁在坏输入上会变红，而不是只报绿。
> 基线：`59e3803e1e10640812e04a266fe3807a7a01a297`（加入 `tools/check.sh` 与负例脚本的提交）
> 环境：macOS，`ct v0.62.0`，负例在 `/tmp` 的 `git archive` 副本里跑；工作树当前产物不参与。

## 复跑命令

```console
$ bash tools/negatives/run.sh
```

## 原始输出（2026-11-16）

```console
red ok g0 tampered block version       gate g0 rc=1 | FAIL 块头与主规范不一致：/tmp/ctjson-neg.eX2lpv/g0/AGENTS.md
red ok g1 version-minor mismatch       gate g1 rc=1 | FAIL g1: /tmp/ctjson-neg.eX2lpv/g1/docs/phases/PH-1/card.md: version-minor must equal 1 (PH-<n>)
red ok g6 illegal status               gate g6 rc=1 | FAIL g6: /tmp/ctjson-neg.eX2lpv/g6/issues/JSON-99.md: illegal status 'bogus' (5.4)
red ok g7 planted secret               gate g7 rc=1 | FAIL g7: secret scan hit
red ok g8 version move without issue   gate g8 rc=1 | FAIL g8: version move check failed
baseline: 59e3803e1e10640812e04a266fe3807a7a01a297
rc=0
```

## 逐条对照

| 用例 | 注入 | 期望 | 实测 |
| --- | --- | --- | --- |
| g0 | 把生成块头 `version=1.15.0` 改成 `1.14.0` | `sync-agents --check` 红 | rc=1，块头不一致 |
| g1 | 放一张 `PH-1` 卡，`version-minor` 写成 2 | 卡头版本与编号不符即红 | rc=1，提示必须等于 1 |
| g6 | 放 `issues/JSON-99.md`，`status: bogus` | 非法状态词即红 | rc=1，提示 5.4 合法集合 |
| g7 | 写入 `AKIA…` 假密钥 | 密钥扫描命中即红 | rc=1，`secret scan hit` |
| g8 | 克隆后把 `ct.pkg` 版本抬到 `0.1.2` 并提交，正文不引用 issue | 版本移动缺 issue 即红 | rc=1，`version move check failed` |

## 未配负例的门禁

| 门禁 | 原因 |
| --- | --- |
| g2 / g4 / g5 | 退出 2，前置产物（验收映射、snippet/文档拆分、phase 任务红证）尚未建立；接入时同一提交内补负例（8.3「门禁变更带负例」） |
| g3 | 用例侧失败由 `test/j1_roundtrip.ct` 的 `not ok` 直接触发；本轮未另做注入用例，待 PH-1 的 T-7 红证补齐 |
| g9 | 与 g0 共用块头校验，g0 已覆盖篡改场景；g9 额外校验主规范 sha，负例随 g0 一并生效 |

## 追加：g8 区分 phase 收口与 fix（2026-11-17，JSON-8）

修复前 g8 只有一条版本规则：`ct.pkg` 一变就要求正文引用 issue，导致合法 phase 收口被判红。

```console
$ # 合法 phase 收口（克隆里 0.1.1→0.2.0、PH-2 卡 closed、tag v0.2.0、正文含 PH-2）
commit f8705f6 moves version without an issue reference (V-3)
FAIL g8: version move check failed
$ echo $?
1
```

修复后：

```console
$ # 合法 phase 收口
ok g8 (baseline ad5f1dc, version moves and phase tags valid)
$ echo $?
0
$ bash tools/negatives/run.sh g8
red ok g8 version move without issue   gate g8 rc=1 | FAIL g8: version move check failed
red ok g8 minor without closed card    gate g8 rc=1 | FAIL g8: version move check failed
baseline: 1f0c86b51fa201d0a2429d4934b5618233509468
$ echo $?
0
```

| 用例 | 注入 | 期望 | 实测 |
| --- | --- | --- | --- |
| g8 合法 phase 收口 | 0.1.1→0.2.0，PH-2 closed，tag v0.2.0，正文 PH-2 | 绿 | rc=0 |
| g8 PATCH 移动缺 issue | 0.1.1→0.1.2，正文不引用 issue | 红（V-3） | rc=1 |
| g8 MINOR 移动缺 closed 卡 | 0.1.1→0.2.0，正文含 PH-2，无卡片 | 红（V-1） | rc=1 |

## 追加：g4 与 surface（PH-6）

```console
$ bash tools/negatives/run.sh g4
red ok g4 oversized document           gate g4 rc=1 | FAIL doc-size: ... has 301 lines (max 300)
baseline: e43eaac430e34b6dcc08f85ba9f2628d6a7f9b15
$ echo $?
0
```

## 追加：g2 与 g4（PH-6 收口前）

```console
$ bash tools/negatives/run.sh g2
red ok g2 missing requirement row      gate g2 rc=1 | FAIL g2: acceptance map has 37 R rows, requirements have 38 (one ACC per R-* required)
red ok g2 public symbol unmapped       gate g2 rc=1 | FAIL g2: public symbol json_decode has no ACC mapping in docs/acceptance-map.md
$ echo $?
0
```
