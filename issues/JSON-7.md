---
id: JSON-7
status: open
priority: P1
owner: 本包（门禁负例夹具）
created: 2026-11-17
last-touched: 2026-11-17
block:
evidence: 基线 `dce8ee9`；`bash tools/check.sh g7` rc=1，命中 `tools/negatives/run.sh:97` 的假密钥字面量
---

# JSON-7 g7 密钥扫描把负例夹具自身当命中

- 归属：**本包门禁夹具**，不是语言层，也不是产品实现。
- 优先级：P1（基线门禁红；`docs/status.md` 却记 g7「可运行」，属假绿）。
- 影响面：任何一次 `bash tools/check.sh all` 都会在 g7 失败，与改动内容无关。
- 关联：`tools/check.sh` g7、`tools/negatives/run.sh`、[docs/evidence/gate-negatives.md](../docs/evidence/gate-negatives.md)。

## 触发条件

在干净基线上直接跑 g7。g7 的密钥正则扫描整个仓库（`--exclude-dir=.git`、`.ctbuild`），
而负例脚本把 AWS 形态的假密钥**逐字写在自己文件里**，于是扫描器命中夹具本身。

## 最小复现

```console
$ git archive dce8ee9 | tar -x -C /tmp/json7-baseline
$ cd /tmp/json7-baseline && bash tools/check.sh g7
./tools/negatives/run.sh:97:    printf 'token AKIAABCDEFGHIJKLMNOP\n' > "$d/leak.txt"
FAIL g7: secret scan hit
$ echo $?
1
```

## 期望行为

干净基线上 g7 绿；只有真正被植入密钥的副本才红（负例仍须变红）。

## 处置（fixed 时写）

2026-11-17：负例脚本改为运行时拼装凭据（`printf 'token AKIA%s\n' 'ABCDEFGHIJKLMNOP'`），
仓库里不再出现完整密钥字面量；g7 本体不放宽、不排除 `tools/`。

```console
$ bash tools/check.sh g7
ok g7 (secret scan clean, ASan run clean; detect_leaks unavailable on this platform)
$ echo $?
0

$ bash tools/negatives/run.sh g7
red ok g7 planted secret               gate g7 rc=1 | FAIL g7: secret scan hit
baseline: dce8ee9b3fbad44152a268aa67973e8ccfb7559f
$ echo $?
0
```

版本：属 V-4 的「测试夹具自身修正」，不 +PATCH；无产品行为变化。
