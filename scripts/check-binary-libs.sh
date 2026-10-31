#!/usr/bin/env bash
# Check that the packed binary needs no shared library beyond the documented set.
#   check-binary-libs.sh <binary>   check
#   check-binary-libs.sh --list     print the documented runtime libs (one line)
set -euo pipefail

# libcrypt: the pp loader executable links libperl, which links libcrypt.so.1. The loader runs
# before PAR extracts anything, so a bundled copy (pp -l) cannot help: the target must have it.
# Debian and Ubuntu always do; install libxcrypt-compat on RHEL/Fedora/Amazon Linux and Arch.
# The README names the same set.
RUNTIME_LIBS=(libcrypt)
BASE_LIBS=(libc libm libpthread libdl librt libgcc_s 'ld-linux-.*' linux-vdso libperl)

if [ "${1:-}" = "--list" ]; then echo "${RUNTIME_LIBS[*]}"; exit 0; fi

command -v ldd >/dev/null 2>&1 || { echo "FAIL: ldd is not installed" >&2; exit 1; }
command -v unzip >/dev/null 2>&1 || { echo "FAIL: unzip is not installed" >&2; exit 1; }
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
# The loader executable plus at least one XS shared object (List::Util, Cwd, ...) must be there.
[ "${#objects[@]}" -ge 2 ] || { echo "FAIL: no shared objects inside $BIN" >&2; exit 1; }

: > "$work/needs"
for obj in "${objects[@]}"; do
  ldd "$obj" >"$work/ldd.out" 2>"$work/ldd.err" \
    || { grep -q 'not a dynamic executable' "$work/ldd.err" "$work/ldd.out" && continue; \
         echo "FAIL: ldd failed on ${obj#"$work/par/"}: $(cat "$work/ldd.err")" >&2; exit 1; }
  awk -v obj="${obj#"$work/par/"}" '$1 ~ /\.so/ {
        lib = $1; sub(/.*\//, "", lib); sub(/\.so.*/, "", lib); print lib "\t" obj }' "$work/ldd.out" \
    | sort -u >> "$work/needs"
done

[ -s "$work/needs" ] || { echo "FAIL: ldd found no shared libs; a Perl binary always needs libc" >&2; exit 1; }

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
