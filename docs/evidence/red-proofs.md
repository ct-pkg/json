# 逐任务红证登记

- 目的：G5 要求每个任务有可追溯的红证（或 `no-test:` 签字），baseline 必须是实现前提交。
- 复跑方式：`git archive <baseline> | tar -x -C /tmp/<task>`，再按项目方式构建；不得用工作树产物。
- 列：任务 | baseline | 命令 | 结果 | 签字。

| 任务 | baseline | 命令 | 结果 | 签字 |
| --- | --- | --- | --- | --- |
| PH1-T1 | 8fb490c | `no-test: 上游 CT v0.53.0 已红，本 phase 无实现提交（卡片 §6）` | n/a | verify-ph1 |
| PH1-T2 | - | `no-test: 纯文档/样例` | n/a | verify-ph1 |
| PH1-T3 | - | `no-test: 纯文档` | n/a | verify-ph1 |
| PH1-T4 | - | `no-test: 台账文档` | n/a | verify-ph1 |
| PH2-T1 | - | `no-test: 验收映射文档` | n/a | verify-ph2 |
| PH2-T2 | 3806554 | `bash tools/negatives/run.sh g2` | `red ok g2 missing requirement row`，rc=1 | verify-ph2 |
| PH2-T3 | - | `no-test: 决策记录文档` | n/a | verify-ph2 |
| PH2-T4 | - | `no-test: 缺口台账` | n/a | verify-ph2 |
| PH3-T1 | b6ba7ab | `ct build test/j3_json_set.ct -I src -o /tmp/j3 && /tmp/j3` | `8 of 55 checks failed`（红证 `e7503c8`） | verify-ph3 |
| PH3-T2 | - | `no-test: 规范/映射文档` | n/a | verify-ph3 |
| PH4-T1 | e67adc5 | `ct build test/j1_roundtrip.ct -I src -o /tmp/j1p4 && /tmp/j1p4` | `not ok 121/122/123`，3 of 145 | verify-ph4 |
| PH4-T2 | a57502b | `ct build test/j4_decode.ct -I src -o /tmp/j4` | `call to undeclared function 'json_decode_strict'`，8 errors | verify-ph4 |
| PH4-T3 | - | `no-test: 规范/映射文档` | n/a | verify-ph4 |
| PH4-T4 | - | `no-test: 证据文档` | n/a | verify-ph4 |
| PH5-T1 | f2a624e | `ct build test/j5_errors.ct -I src -o /tmp/j5 && /tmp/j5` | `not ok 2/3`，2 of 11 | verify-ph5 |
| PH5-T2 | fdd1b2c | `ct build test/j5_errors.ct -I src -o /tmp/j5` | `json_error_offset`/`json_message` 未声明，9 errors | verify-ph5 |
| PH5-T3 | - | `no-test: 规范/映射/证据文档` | n/a | verify-ph5 |
| PH6-T1 | - | `no-test: 文档拆分` | n/a | verify-ph6 |
| PH6-T2 | - | `no-test: README 重写` | n/a | verify-ph6 |
| PH6-T3 | e43eaac | `bash tools/negatives/run.sh g4` | `red ok g4 oversized document`，rc=1 | verify-ph6 |
| PH6-T4 | e43eaac | `bash tools/negatives/run.sh g5` | `red ok g5 missing task row`，rc=1 | verify-ph6 |
| PH6-T5 | e43eaac | `bash tools/negatives/run.sh surface` | `red ok surface tampered list`，rc=1 | verify-ph6 |
