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
