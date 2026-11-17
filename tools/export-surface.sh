#!/usr/bin/env bash
#
# tools/export-surface.sh — 冻结公开导出面（R-E-02）并核对 requires（R-E-04）。
#
#   bash tools/export-surface.sh           # 校验：src 的 pub 符号与清单逐行相等
#   bash tools/export-surface.sh --write   # 用当前 src 重写清单
#
# 清单 docs/api-surface.txt 每行一个符号，排序去重；类型在前/函数在后不作要求。
#
# License: MIT.

set -u
here="$(cd "$(dirname "$0")" && pwd)"
pkg="$(cd "$here/.." && pwd)"
src="$pkg/src/json.h.ct"
list="$pkg/docs/api-surface.txt"
mode="${1:-check}"

[ -f "$src" ] || { echo "FAIL export-surface: missing $src" >&2; exit 1; }
[ -f "$list" ] || { echo "FAIL export-surface: missing $list" >&2; exit 1; }

tmp="$(mktemp /tmp/ctjson-surface.XXXXXX)"
trap 'rm -f "$tmp"' EXIT

awk '
    /^[[:space:]]*pub (struct|union|enum|trait) / {
        name = $3
        sub(/[^A-Za-z0-9_].*/, "", name)
        print name
        next
    }
    /^[[:space:]]*pub [A-Za-z_].*\(/ {
        line = $0
        sub(/^[[:space:]]*pub[[:space:]]+/, "", line)
        sub(/\(.*/, "", line)
        n = split(line, a, /[[:space:]]+/)
        s = a[n]
        sub(/^\*/, "", s)
        print s
    }
' "$src" | sort -u > "$tmp"

dups="$(sort "$list" | uniq -d)"
[ -z "$dups" ] || { printf 'FAIL export-surface: duplicate entries: %s\n' "$dups" >&2; exit 1; }
n="$(wc -l < "$tmp" | tr -d ' ')"
[ "$n" -ge 1 ] || { echo "FAIL export-surface: no public symbols found" >&2; exit 1; }

if [ "$mode" = "--write" ]; then
    cp "$tmp" "$list"
    printf 'wrote %s (%s symbols)\n' "$list" "$n"
    exit 0
fi

if ! diff -u "$list" "$tmp" >/tmp/ctjson_surface.diff; then
    cat /tmp/ctjson_surface.diff >&2
    echo "FAIL export-surface: public surface drifted; update docs/api-surface.txt" >&2
    exit 1
fi

pkg_req="$(sed -n 's/^requires *= *//p' "$pkg/ct.pkg" | head -n 1)"
src_req="$(sed -n 's|^//@ct-requires: *||p' "$src" | head -n 1)"
[ -n "$pkg_req" ] || { echo "FAIL export-surface: ct.pkg has no requires" >&2; exit 1; }
[ "$pkg_req" = "$src_req" ] || {
    printf 'FAIL export-surface: requires drift (ct.pkg="%s", src="%s")\n' "$pkg_req" "$src_req" >&2
    exit 1
}

printf 'ok export-surface (%s symbols; requires "%s")\n' "$n" "$pkg_req"
