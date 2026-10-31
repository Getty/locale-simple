#!/usr/bin/env bash
# Smoke-test a packed locale-simple binary on a clean machine: no Perl modules from the
# build, no build toolchain. Run it from the checkout root (for the fixtures).
#   smoke-binary.sh <binary>
set -euo pipefail

[ -n "${1:-}" ] || { echo "usage: smoke-binary.sh <binary>" >&2; exit 1; }
BIN=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
chmod +x "$BIN"
fail() { echo "FAIL: $*" >&2; exit 1; }

want=$(sed -n "s/^our \$VERSION = '\(.*\)';/\1/p" lib/Locale/Simple.pm)
[ -n "$want" ] || fail "cannot read \$VERSION from lib/Locale/Simple.pm"
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
mkdir -p "$work/home"

# The binary under a wiped environment, as a user without Perl would start it.
bin() { env -i PATH=/usr/bin:/bin HOME="$work/home" "$BIN" "$@" </dev/null; }

out=$(bin --version) || fail "--version failed"
[ "$out" = "locale-simple $want" ] || fail "--version prints '$out', want 'locale-simple $want'"
echo "smoke --version: OK ($out)"

bin po2json --domain test t/data/locale/de_DE/LC_MESSAGES/test.po >"$work/got" \
  || fail "po2json --domain test failed"
cmp -s "$work/got" t/data/po2json/test.domain.json \
  || fail "po2json --domain test: output differs from t/data/po2json/test.domain.json"
echo "smoke po2json --domain test: OK (byte-identical)"

rc=0; bin po2json nope.po >/dev/null 2>&1 || rc=$?
[ "$rc" -ne 0 ] || fail "po2json nope.po exits 0, want non-zero"
echo "smoke po2json nope.po: OK (exit $rc)"
echo "smoke: OK"
