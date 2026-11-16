#!/usr/bin/env bash
#
# tools/check.sh — ct-json 门禁入口。
#
#   bash tools/check.sh g0   规范块、实例化、session-map、包清单、版本落点
#   bash tools/check.sh g1   需求编号、无 TBD、phase 卡十项与冻结摘要
#   bash tools/check.sh g2   设计验收映射（R-* → ACC-*）；未立项时退出 2
#   bash tools/check.sh g3   构建零警告 + J1 往返用例 + json.expected.out
#   bash tools/check.sh g4   文档 snippet / 锚点 / 300 行；未接入时退出 2
#   bash tools/check.sh g5   逐任务红证；无 phase 任务时退出 2
#   bash tools/check.sh g6   issue 台账状态与证据
#   bash tools/check.sh g7   密钥扫描 + sanitizer
#   bash tools/check.sh g8   纳管基线后的版本移动、phase 冻结、收口 tag
#   bash tools/check.sh g9   生成块 pin 与主规范一致
#   bash tools/check.sh all  逐道跑，汇总；任一道退出 1 即整体失败
#
# 未实现的检查一律退出 2，打印缺什么；不许假绿。
#
# License: MIT.

set -u

here="$(cd "$(dirname "$0")" && pwd)"
pkg="$(cd "$here/.." && pwd)"
SPEC_BIN="${SPEC_BIN:-/Users/samxx/trae-ws/.ai-engineering/bin/sync-agents.sh}"
SPEC_MASTER="${SPEC_MASTER:-/Users/samxx/trae-ws/.ai-engineering/methodology/ai-coding-workflow.md}"
CT_BIN="${CT_BIN:-$HOME/.local/bin/ct}"
CT_STD_DIR="${CT_STD_DIR:-/Users/samxx/trae-ws/ct-lang/lib/std}"

gate="${1:-}"

fail() { printf 'FAIL %s: %s\n' "${gate:-check}" "$1" >&2; exit 1; }
skip() { printf 'SKIP %s: %s\n' "${gate:-check}" "$1" >&2; exit 2; }
note() { printf 'note %s: %s\n' "${gate:-check}" "$1"; }

ct_build() {
    CT_STD_DIR="$CT_STD_DIR" "$CT_BIN" build "$@"
}

# section <heading> <file>
section() {
    awk -v h="$1" '
        index($0, h) == 1 { inb = 1; next }
        inb && /^## / { exit }
        inb { print }
    ' "$2"
}

# digest_section <heading> <file>
digest_section() {
    awk -v h="$1" '
        index($0, h) == 1 { inb = 1; next }
        inb && /^## / { exit }
        inb { buf[n++] = $0 }
        END {
            while (n > 0 && buf[n - 1] ~ /^[[:space:]]*$/) n--
            for (i = 0; i < n; i++) print buf[i]
        }
    ' "$2" | shasum -a 256 | awk '{print $1}'
}

# check_card <path>
check_card() {
    card="$1"
    [ -f "$card" ] || fail "missing card: $card"

    for h in \
        '## 0. 编号与元信息' \
        '## 1. 目标' \
        '## 2. 范围' \
        '## 3. 交付物清单' \
        '## 4. 任务清单' \
        '## 5. 退出判据（冻结）' \
        '## 6. 红证方式' \
        '## 7. 依赖' \
        '## 8. 已知风险' \
        '## 9. 收口动作'; do
        grep -qxF "$h" "$card" || fail "$card: missing card item: $h"
    done

    ph="$(sed -n 's/^- 编号：\(PH-[0-9][0-9]*\)$/\1/p' "$card" | head -n 1)"
    [ -n "$ph" ] || fail "$card: missing or malformed '- 编号：PH-<n>'"
    n="${ph#PH-}"
    grep -qxF -- "- version-minor：$n" "$card" \
        || fail "$card: version-minor must equal $n (PH-<n>)"
    grep -qE '^- 规范版本：[0-9]+\.[0-9]+\.[0-9]+' "$card" \
        || fail "$card: missing '- 规范版本：<x.y.z>'"
    grep -qE '^- criteria-sha256：[0-9a-f]{64}$' "$card" \
        || fail "$card: missing '- criteria-sha256：<64 hex>'"
    grep -qE '^- tasks-sha256：[0-9a-f]{64}$' "$card" \
        || fail "$card: missing '- tasks-sha256：<64 hex>'"

    crit="$(section '## 5. 退出判据（冻结）' "$card")"
    printf '%s\n' "$crit" | grep -qF '任务清单每项可独立验收（6.6 T-6）' \
        || fail "$card: exit criteria must include '任务清单每项可独立验收（6.6 T-6）'"
    printf '%s\n' "$crit" | awk -F'|' -v pre="E-P$n-" '
        /^\| E-P[0-9]+-[0-9]+ / {
            n++
            id = $2; gsub(/^[ \t]+|[ \t]+$/, "", id)
            if (index(id, pre) != 1) {
                printf "criterion %s does not use the card prefix %s\n", id, pre > "/dev/stderr"
                bad = 1
            }
            if ($0 !~ /`/) { print "criterion without a command anchor: " $0 > "/dev/stderr"; bad = 1 }
        }
        END {
            if (n < 3) { printf "need at least 3 %s exit criteria, got %d\n", pre, n > "/dev/stderr"; bad = 1 }
            if (bad) exit 1
        }
    ' || fail "$card: exit criteria rows invalid"

    tasks="$(section '## 4. 任务清单' "$card")"
    printf '%s\n' "$tasks" | awk -F'|' -v pn="$n" '
        /^\| T[0-9]+ / {
            n++
            cnt = 0
            for (i = 2; i < NF; i++) if ($i ~ /[^ \t]/) cnt++
            if (cnt != 7) {
                printf "task row has %d non-empty columns, need 7: %s\n", cnt, $2 > "/dev/stderr"
                bad = 1
            }
            effort = $7; gsub(/^[ \t]+|[ \t]+$/, "", effort)
            if (effort != "S" && effort != "M") {
                printf "task %s effort must be S or M, got %s\n", $2, effort > "/dev/stderr"
                bad = 1
            }
            cover = $8; gsub(/^[ \t]+|[ \t]+$/, "", cover)
            if (cover !~ ("E-P" pn "-[0-9]+")) {
                printf "task %s must name the exit criterion it covers (E-P%s-<n>)\n", $2, pn > "/dev/stderr"
                bad = 1
            }
        }
        END {
            if (n < 1) { print "task table has no rows" > "/dev/stderr"; bad = 1 }
            if (bad) exit 1
        }
    ' || fail "$card: task table invalid"

    want_c="$(sed -n 's/^- criteria-sha256：\([0-9a-f]\{64\}\)$/\1/p' "$card" | head -n 1)"
    got_c="$(digest_section '## 5. 退出判据（冻结）' "$card")"
    [ "$want_c" = "$got_c" ] \
        || fail "$card: criteria-sha256 mismatch (card=$want_c actual=$got_c); exit criteria are frozen"

    want_t="$(sed -n 's/^- tasks-sha256：\([0-9a-f]\{64\}\)$/\1/p' "$card" | head -n 1)"
    got_t="$(digest_section '## 4. 任务清单' "$card")"
    [ "$want_t" = "$got_t" ] \
        || fail "$card: tasks-sha256 mismatch (card=$want_t actual=$got_t); task list is frozen"
}

# texts_outside_block <file> — 打印 AGENTS.md 生成块之外的行
texts_outside_block() {
    awk '
        /^<!-- spec:begin / { inb = 1; next }
        /^<!-- spec:end -->/ { inb = 0; next }
        !inb { print }
    ' "$1"
}

case "$gate" in
g0)
    agents="${AGENTS_MD:-$pkg/AGENTS.md}"
    sm="${SESSION_MAP:-$pkg/docs/session-map.md}"
    ctpkg="${CT_PKG:-$pkg/ct.pkg}"

    [ -x "$CT_BIN" ] || fail "ct not found: $CT_BIN"
    out="$(CT_STD_DIR="$CT_STD_DIR" "$CT_BIN" pkg check "$pkg" 2>&1)" \
        || { printf '%s\n' "$out" >&2; fail "ct pkg check"; }

    [ -f "$SPEC_BIN" ] || fail "spec tool not found: $SPEC_BIN"
    bash "$SPEC_BIN" --check "$agents" >/dev/null || fail "sync-agents --check"

    [ -f "$sm" ] || fail "missing docs/session-map.md"
    for h in '### 0.1 本项目实例化' '### 0.2 话术路由' '### 0.3 偏离项'; do
        grep -qxF "$h" "$agents" || fail "missing landing section: $h"
    done

    rows="$(awk '
        /^### 0\.1 / { inb = 1; next }
        /^### 0\.2 / { inb = 0 }
        inb && /^\|/ { n++ }
        END { print n + 0 }
    ' "$agents")"
    [ "$rows" -ge 10 ] || fail "instantiation table has $((rows - 2)) rows, need 8"

    grep -qE '^\| 版本落点 \| .+' "$agents" \
        || fail "instantiation table: 版本落点 must be non-empty"

    pkg_ver="$(sed -n 's/^version *= *\([0-9][0-9.]*\).*$/\1/p' "$ctpkg" | head -n 1)"
    [ -n "$pkg_ver" ] || fail "ct.pkg has no version"

    printf 'ok g0 (block, 8 rows, routing, deviations, session map, pkg check, version %s)\n' "$pkg_ver"
    ;;

g1)
    req="${REQUIREMENTS:-$pkg/docs/requirements.md}"
    [ -f "$req" ] || fail "missing docs/requirements.md"
    n_req="$(grep -cE '^\| *R-[A-E]-[0-9]+' "$req" || true)"
    [ "${n_req:-0}" -ge 1 ] || fail "requirements have no R-<group>-<n> ids"

    hits="$( { grep -rn 'TBD' "$pkg/docs" "$pkg/issues" 2>/dev/null \
                   | grep -v 'docs/spec/ai-coding-workflow.md' || true
                texts_outside_block "$pkg/AGENTS.md" | grep -n 'TBD' || true; } | head -n 5)"
    [ -z "$hits" ] || { printf '%s\n' "$hits" >&2; fail "found TBD outside the generated block"; }

    cards=0
    for card in "$pkg"/docs/phases/PH-*/card.md; do
        [ -f "$card" ] || continue
        cards=$((cards + 1))
        check_card "$card"
    done
    if [ "$cards" -eq 0 ]; then
        note "no phase cards yet (docs/phases/PH-*/card.md)"
    fi

    printf 'ok g1 (%d requirement ids, no TBD, %d phase card(s))\n' "$n_req" "$cards"
    ;;

g2)
    skip "尚未立项，无设计验收映射；需 docs/acceptance-map.md（R-* → ACC-*），在设计的 phase 接"
    ;;

g3)
    [ -x "$CT_BIN" ] || fail "ct not found: $CT_BIN"
    log="/tmp/ctjson_g3_build.log"
    ct_build "$pkg/test/j1_roundtrip.ct" -I "$pkg/src" -o /tmp/ctjson_g3_j1 >"$log" 2>&1 \
        || { cat "$log" >&2; fail "build test/j1_roundtrip.ct"; }
    grep -q 'warning:' "$log" && { cat "$log" >&2; fail "build has warnings"; }

    out="$(/tmp/ctjson_g3_j1 2>&1)" || { printf '%s\n' "$out" >&2; fail "j1_roundtrip exit != 0"; }
    printf '%s\n' "$out" | grep -qE '^not ok' \
        && { printf '%s\n' "$out" | grep -E '^not ok' >&2; fail "j1_roundtrip has failures"; }
    printf '%s\n' "$out" | grep -q 'all checks passed' \
        || { printf '%s\n' "$out" | tail -n 20 >&2; fail "j1_roundtrip did not print all checks passed"; }

    ct_build "$pkg/json.ct" -o /tmp/ctjson_g3_golden >"$log" 2>&1 \
        || { cat "$log" >&2; fail "build json.ct"; }
    grep -q 'warning:' "$log" && { cat "$log" >&2; fail "json.ct build has warnings"; }
    /tmp/ctjson_g3_golden > /tmp/ctjson_g3_golden.out 2>&1 \
        || fail "json.ct demo exit != 0"
    diff -u "$pkg/json.expected.out" /tmp/ctjson_g3_golden.out >/tmp/ctjson_g3_diff.txt \
        || { cat /tmp/ctjson_g3_diff.txt >&2; fail "json.expected.out mismatch"; }

    printf 'ok g3 (j1_roundtrip, json.expected.out, zero warnings)\n'
    ;;

g4)
    skip "文档 snippet / 锚点 / 300 行检查尚未接入；已知 docs/spec/ct-json-0.1.0.md 366 行待拆分（backlog #9）"
    ;;

g5)
    skip "尚无 phase 任务与逐任务红证；红证登记从 PH-1 开工起生效（6.6 T-7）"
    ;;

g6)
    issues=0
    for f in "$pkg"/issues/*.md; do
        [ -f "$f" ] || continue
        case "$(basename "$f")" in README.md) continue ;; esac
        issues=$((issues + 1))

        status="$(sed -n 's/^status: *\([A-Za-z]*\).*/\1/p' "$f" | head -n 1)"
        if [ -z "$status" ]; then
            status="$(sed -n 's/^- status: *\**\([A-Za-z]*\)\**.*/\1/p' "$f" | head -n 1)"
        fi
        [ -n "$status" ] || fail "$f: missing status (front-matter or '- status:')"
        case "$status" in
            open|fixed|verified|reopened|rejected|deferred|wontfix|superseded) ;;
            *) fail "$f: illegal status '$status' (5.4)" ;;
        esac

        ev="$(sed -n 's/^evidence: *\(.\+\)$/\1/p' "$f" | head -n 1)"
        if [ -z "$ev" ]; then
            grep -qE '^(## (最小复现|实际行为|验证|修复)|```console)' "$f" \
                || fail "$f: status $status without evidence (5.4 / G6)"
        fi

        if [ "$status" = "fixed" ]; then
            grep -qE '[0-9a-f]{7,40}' "$f" \
                || fail "$f: fixed without a commit sha in the disposition"
        fi
    done
    [ "$issues" -ge 1 ] || skip "no issue entries yet"

    printf 'ok g6 (%d issue(s), statuses and evidence valid)\n' "$issues"
    ;;

g7)
    secret_hits="$(cd "$pkg" && grep -rInE \
        '(AKIA[0-9A-Z]{16}|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----|sk-[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{30,}|xox[baprs]-[A-Za-z0-9-]{10,})' \
        --exclude-dir=.git --exclude-dir=.ctbuild . 2>/dev/null || true)"
    [ -z "$secret_hits" ] || { printf '%s\n' "$secret_hits" >&2; fail "secret scan hit"; }

    if [ -f "$pkg/ct.lock" ]; then
        note "ct.lock present; manifest consistency is covered by ct pkg check"
    fi

    [ -x "$CT_BIN" ] || fail "ct not found: $CT_BIN"
    log="/tmp/ctjson_g7_asan_build.log"
    ct_build "$pkg/test/j1_roundtrip.ct" -I "$pkg/src" -o /tmp/ctjson_g7_asan \
        --cflags '-fsanitize=address -g' --ldflags '-fsanitize=address' >"$log" 2>&1 \
        || { cat "$log" >&2; fail "ASan build failed"; }
    out="$(ASAN_OPTIONS=detect_leaks=0 /tmp/ctjson_g7_asan 2>&1)" \
        || { printf '%s\n' "$out" | tail -n 30 >&2; fail "ASan run exit != 0"; }
    printf '%s\n' "$out" | grep -q 'ERROR: AddressSanitizer' \
        && { printf '%s\n' "$out" | tail -n 30 >&2; fail "AddressSanitizer reported an error"; }
    printf '%s\n' "$out" | grep -q '^not ok' \
        && { printf '%s\n' "$out" | grep '^not ok' >&2; fail "ASan run has test failures"; }

    printf 'ok g7 (secret scan clean, ASan run clean; detect_leaks unavailable on this platform)\n'
    ;;

g8)
    statusf="${STATUS_FILE:-$pkg/docs/status.md}"
    [ -f "$statusf" ] || fail "missing docs/status.md (纳管基线)"
    base="$(sed -n 's/^- 纳管基线：`\{0,1\}\([0-9a-f]\{7,40\}\).*/\1/p' "$statusf" | head -n 1)"
    [ -n "$base" ] || fail "docs/status.md: missing '- 纳管基线：<sha>'"
    git -C "$pkg" cat-file -e "$base^{commit}" 2>/dev/null || fail "baseline commit not found: $base"
    git -C "$pkg" merge-base --is-ancestor "$base" HEAD \
        || fail "baseline $base is not an ancestor of HEAD"

    bad=0
    for c in $(git -C "$pkg" rev-list "$base..HEAD"); do
        if git -C "$pkg" diff-tree --no-commit-id --name-only -r "$c" | grep -qx 'ct.pkg'; then
            old="$(git -C "$pkg" show "$c^:ct.pkg" 2>/dev/null | sed -n 's/^version *= *\([0-9][0-9.]*\).*$/\1/p' | head -n 1)"
            new="$(git -C "$pkg" show "$c:ct.pkg" 2>/dev/null | sed -n 's/^version *= *\([0-9][0-9.]*\).*$/\1/p' | head -n 1)"
            [ -n "$old" ] && [ -n "$new" ] || { printf 'commit %s changed ct.pkg but version unreadable\n' "$c" >&2; bad=1; continue; }
            [ "$old" = "$new" ] && { printf 'commit %s touches ct.pkg without a version move (V-5)\n' "$c" >&2; bad=1; continue; }
            if git -C "$pkg" log -1 --format=%s "$c" | grep -q '^docs\?'; then
                printf 'commit %s is a docs commit but moves the version (V-4)\n' "$c" >&2; bad=1
            fi
            if ! git -C "$pkg" show --format=%B -s "$c" | grep -qE 'issues/JSON-[0-9]+\.md'; then
                printf 'commit %s moves version without an issue reference (V-3)\n' "$c" >&2; bad=1
            fi
        fi
    done
    [ "$bad" -eq 0 ] || fail "version move check failed"

    for card in "$pkg"/docs/phases/PH-*/card.md; do
        [ -f "$card" ] || continue
        grep -qxF -- '- 状态：closed' "$card" || continue
        n="$(sed -n 's/^- 编号：PH-\([0-9][0-9]*\)$/\1/p' "$card" | head -n 1)"
        [ -n "$n" ] || fail "$card: closed card without a valid 编号"
        want="v0.$n."
        tag="$(git -C "$pkg" tag --list "v0.$n.*" | head -n 1)"
        [ -n "$tag" ] || fail "$card: closed PH-$n has no v0.$n.* tag (V-7)"
        [ "$(git -C "$pkg" cat-file -t "$tag" 2>/dev/null)" = "tag" ] \
            || fail "$card: $tag is not an annotated tag (V-7)"
    done

    printf 'ok g8 (baseline %s, version moves and phase tags valid)\n' "$base"
    ;;

g9)
    agents="${AGENTS_MD:-$pkg/AGENTS.md}"
    [ -f "$agents" ] || fail "missing $agents"
    [ -f "$SPEC_MASTER" ] || fail "master spec not found: $SPEC_MASTER"

    head="$(grep -m 1 '^<!-- spec:begin ' "$agents")"
    [ -n "$head" ] || fail "no spec:begin block"
    pv="$(printf '%s\n' "$head" | sed -n 's/.*version=\([0-9][0-9.]*\).*/\1/p')"
    ps="$(printf '%s\n' "$head" | sed -n 's/.*sha256=\([0-9a-f]\{64\}\).*/\1/p')"
    [ -n "$pv" ] || fail "block has no version"
    [ -n "$ps" ] || fail "block has no sha256"

    mv="$(sed -n 's/^| spec-version | `\([0-9][0-9.]*\)`.*/\1/p' "$SPEC_MASTER" | head -n 1)"
    [ -n "$mv" ] || fail "master spec has no spec-version row"
    ms="$(shasum -a 256 "$SPEC_MASTER" | awk '{print $1}')"

    [ "$pv" = "$mv" ] || fail "spec version drift: block=$pv master=$mv"
    [ "$ps" = "$ms" ] || fail "spec sha256 drift: block=$ps master=$ms"

    printf 'ok g9 (spec %s @ %s)\n' "$pv" "${ps:0:12}"
    ;;

all)
    rc=0
    unimplemented=0
    for g in g0 g1 g2 g3 g4 g5 g6 g7 g8 g9; do
        printf '=== %s\n' "$g"
        bash "$0" "$g"
        r=$?
        case "$r" in
            0) ;;
            2) unimplemented=$((unimplemented + 1)) ;;
            *) rc=1 ;;
        esac
    done
    printf '=== summary: %d unimplemented gate(s)\n' "$unimplemented"
    [ "$rc" -eq 0 ] || exit 1
    [ "$unimplemented" -eq 0 ] || exit 2
    ;;

*)
    printf 'usage: bash tools/check.sh <g0|g1|g2|g3|g4|g5|g6|g7|g8|g9|all>\n' >&2
    exit 2
    ;;
esac
