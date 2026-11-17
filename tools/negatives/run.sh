#!/usr/bin/env bash
#
# tools/negatives/run.sh — 门禁负例自测。
#
# 每个用例从 HEAD 导出一份干净副本，注入缺陷后跑指定门禁，要求它变红（退出码 != 0）。
# 基线是导出时的 HEAD；输出用于 docs/evidence/gate-negatives.md。
#
# 用法：bash tools/negatives/run.sh [g0|g1|g6|g7|g8 ...]
#
# License: MIT.

set -u

here="$(cd "$(dirname "$0")" && pwd)"
pkg="$(cd "$here/../.." && pwd)"
base="$(git -C "$pkg" rev-parse HEAD)"
tmp="$(mktemp -d /tmp/ctjson-neg.XXXXXX)"
trap 'rm -rf "$tmp"' EXIT

fail=0

export_tree() {
    d="$1"
    mkdir -p "$d"
    git -C "$pkg" archive "$base" | tar -x -C "$d"
}

expect_red() {
    name="$1"; gate="$2"; dir="$3"
    out="$dir/.gate.out"
    bash "$dir/tools/check.sh" "$gate" >"$out" 2>&1
    rc=$?
    if [ "$rc" -eq 0 ]; then
        printf 'NEGATIVE-FAIL %-28s gate %s stayed green\n' "$name" "$gate"
        fail=1
    elif [ "$rc" -eq 2 ]; then
        # An unimplemented gate also exits non-zero; that is not a red proof.
        printf 'NEGATIVE-FAIL %-28s gate %s skipped (rc=2), not a red\n' "$name" "$gate"
        fail=1
    else
        printf 'red ok %-31s gate %s rc=%s | %s\n' "$name" "$gate" "$rc" \
            "$(grep -m 1 -E '^(FAIL|error|.*error:)' "$out" | cut -c1-120)"
    fi
}

want="${*:-g0 g1 g2 g4 g6 g7 g8}"

case " $want " in
*' g0 '*)
    d="$tmp/g0"; export_tree "$d"
    sed -i '' 's/version=1\.15\.0/version=1.14.0/' "$d/AGENTS.md"
    expect_red "g0 tampered block version" g0 "$d"
    ;;
esac

case " $want " in
*' g1 '*)
    d="$tmp/g1"; export_tree "$d"
    mkdir -p "$d/docs/phases/PH-1"
    cat > "$d/docs/phases/PH-1/card.md" <<'CARD'
# PH-1 卡：负例
- 编号：PH-1
- version-minor：2
- 规范版本：1.15.0
- criteria-sha256：0000000000000000000000000000000000000000000000000000000000000000
- tasks-sha256：0000000000000000000000000000000000000000000000000000000000000000

## 0. 编号与元信息
## 1. 目标
## 2. 范围
## 3. 交付物清单
## 4. 任务清单
## 5. 退出判据（冻结）
## 6. 红证方式
## 7. 依赖
## 8. 已知风险
## 9. 收口动作
CARD
    expect_red "g1 version-minor mismatch" g1 "$d"
    ;;
esac

case " $want " in
*' g2 '*)
    d="$tmp/g2"; export_tree "$d"
    sed -i '' '/^| R-A-10 /d' "$d/docs/acceptance-map.md"
    expect_red "g2 missing requirement row" g2 "$d"

    d="$tmp/g2-sym"; export_tree "$d"
    sed -i '' '/^| `json_decode` |/d' "$d/docs/acceptance-map.md"
    expect_red "g2 public symbol unmapped" g2 "$d"
    ;;
esac

case " $want " in
*' g4 '*)
    d="$tmp/g4"; export_tree "$d"
    awk 'BEGIN { for (i = 0; i < 301; i++) print "x" }' > "$d/docs/too-long.md"
    expect_red "g4 oversized document" g4 "$d"
    ;;
esac

case " $want " in
*' g6 '*)
    d="$tmp/g6"; export_tree "$d"
    cat > "$d/issues/JSON-99.md" <<'ISSUE'
---
id: JSON-99
status: bogus
evidence: test
---

# JSON-99 negative
ISSUE
    expect_red "g6 illegal status" g6 "$d"
    ;;
esac

case " $want " in
*' g7 '*)
    d="$tmp/g7"; export_tree "$d"
    # The credential is assembled at run time: spelling it out here would make
    # g7's own repository scan hit this fixture (the gate scans tools/ too).
    printf 'token AKIA%s\n' 'ABCDEFGHIJKLMNOP' > "$d/leak.txt"
    expect_red "g7 planted secret" g7 "$d"
    ;;
esac

case " $want " in
*' g8 '*)
    d="$tmp/g8"
    git clone -q "$pkg" "$d"
    cur="$(sed -n 's/^version *= *//p' "$d/ct.pkg" | head -n 1)"
    rest="${cur#*.}"; major="${cur%%.*}"; minor="${rest%%.*}"; patch="${rest#*.}"
    patch_next="$major.$minor.$((patch + 1))"
    minor_next="$major.$((minor + 1)).0"
    sed -i '' "s/^version = $cur$/version = $patch_next/" "$d/ct.pkg"
    git -C "$d" -c user.name=neg -c user.email=neg@example.invalid \
        commit -qam 'chore: bump version without issue'
    expect_red "g8 version move without issue" g8 "$d"

    # A MINOR move is a phase closeout, not a fix: without the closed card it
    # must still fail even when the body names the phase.
    d="$tmp/g8-minor"
    git clone -q "$pkg" "$d"
    sed -i '' "s/^version = $cur$/version = $minor_next/" "$d/ct.pkg"
    git -C "$d" -c user.name=neg -c user.email=neg@example.invalid \
        commit -qam 'chore(release): PH-2 收口（v0.2.0）'
    expect_red "g8 minor without closed card" g8 "$d"
    ;;
esac

printf 'baseline: %s\n' "$base"
exit "$fail"
