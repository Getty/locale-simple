#!/usr/bin/env bash
# Check that the packed binary needs no shared library beyond the documented set.
#   check-binary-libs.sh <binary>   check
#   check-binary-libs.sh --list     print the documented runtime libs (one line)
set -euo pipefail

RUNTIME_LIBS=()   # beyond glibc the binary needs nothing; the README names the same (none)
BASE_LIBS=(libc libm libpthread libdl librt libgcc_s libcrypt 'ld-linux-.*' linux-vdso libperl)

if [ "${1:-}" = "--list" ]; then echo "${RUNTIME_LIBS[*]:-}"; exit 0; fi

BIN=$(realpath "${1:?usage: check-binary-libs.sh <binary> | --list}")
[ -f "$BIN" ] || { echo "FAIL: no such file: $BIN" >&2; exit 1; }
allowed=$(IFS='|'; echo "${RUNTIME_LIBS[*]:-}|${BASE_LIBS[*]}")
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT

rc=0
unzip -qq -o "$BIN" -d "$work/par" || rc=$?       # exit 1 = warning (bytes before the zip)
[ "$rc" -le 1 ] || { echo "FAIL: cannot unpack the PAR archive (unzip exit $rc)" >&2; exit 1; }

objects=("$BIN")
while IFS= read -r -d '' f; do objects+=("$f"); done \
  < <(find "$work/par" -type f \( -name '*.so' -o -name '*.so.*' \) -print0 | sort -z)
[ "${#objects[@]}" -ge 1 ] || { echo "FAIL: nothing to check in $BIN" >&2; exit 1; }

: > "$work/needs"
for obj in "${objects[@]}"; do
  { ldd "$obj" 2>/dev/null || true; } \
    | awk -v obj="${obj#"$work/par/"}" '$1 ~ /\.so/ {
        lib = $1; sub(/.*\//, "", lib); sub(/\.so.*/, "", lib); print lib "\t" obj }' \
    | sort -u >> "$work/needs"
done

echo "Shared libs the binary needs on the target (${#objects[@]} objects checked):"
cut -f1 "$work/needs" | sort -u | sed 's/^/  /'

undocumented=$(cut -f1 "$work/needs" | sort -u | grep -vxE "$allowed" || true)
if [ -n "$undocumented" ]; then
  for lib in $undocumented; do
    printf '::error::undocumented runtime lib %s, needed by: %s\n' "$lib" \
      "$(awk -F'\t' -v l="$lib" '$1 == l {print $2}' "$work/needs" | sort -u | paste -sd' ')" >&2
  done
  echo "FAIL: libs outside the documented runtime set (${RUNTIME_LIBS[*]:-none})" >&2
  exit 1
fi
echo "runtime-libs check: only the documented libs are needed"
