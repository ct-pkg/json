#!/usr/bin/env bash
#
# tools/check-doc-size.sh — DOC-S1/S2/S8 的可复用检查。
#
# 单份文档 ≤300 行；AGENTS.md 先剔除生成块（DOC-S8）；主规范全文副本
# docs/spec/ai-coding-workflow.md 是派生物，与 AGENTS 块同理豁免。
#
# License: MIT.

set -u
here="$(cd "$(dirname "$0")" && pwd)"
pkg="$(cd "$here/.." && pwd)"
fail=0
files=0

check_file() {
    f="$1"
    [ -f "$f" ] || return 0
    case "$f" in
        */docs/spec/ai-coding-workflow.md) return 0 ;;
    esac
    files=$((files + 1))
    n="$(wc -l < "$f" | tr -d ' ')"
    if [ "$(basename "$f")" = "AGENTS.md" ] && [ "$(dirname "$f")" = "$pkg" ]; then
        n="$(awk '
            /^<!-- spec:begin / { inb = 1; next }
            /^<!-- spec:end -->/ { inb = 0; next }
            !inb { n++ }
            END { print n + 0 }
        ' "$f")"
    fi
    if [ "$n" -gt 300 ]; then
        printf 'FAIL doc-size: %s has %s lines (max 300)\n' "$f" "$n" >&2
        fail=1
    fi
}

for f in "$pkg"/*.md; do
    check_file "$f"
done

while IFS= read -r -d '' f; do
    check_file "$f"
done < <(find "$pkg/docs" -name '*.md' -print0)

[ "$fail" -eq 0 ] || exit 1
printf 'ok doc-size (%s files <= 300 lines; AGENTS block and spec copy exempt)\n' "$files"
