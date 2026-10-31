#!/usr/bin/env bash
# Verify a packed locale-simple binary against `perl -Ilib bin/locale-simple`.
#   verify-binary.sh <binary>
set -euo pipefail

BIN=$(realpath "${1:?usage: verify-binary.sh <binary>}")
[ -x "$BIN" ] || { echo "FAIL: not an executable: $BIN" >&2; exit 1; }
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d); cache=$(mktemp -d)
trap 'rm -rf "$work" "$cache"' EXIT
mkdir -p "$work/home" "$work/cwd"

fail() { echo "FAIL: $*" >&2; exit 1; }
tmo=${LOCALE_SIMPLE_VERIFY_TIMEOUT:-120}

# The binary under a wiped environment and a fresh extraction cache.
bin() { env -i PATH=/usr/bin:/bin HOME="$work/home" PAR_GLOBAL_TEMP="$cache" timeout "$tmo" "$BIN" "$@"; }
# The reference: the same CLI from the checkout.
ref() { perl -I"$root/lib" "$root/bin/locale-simple" "$@"; }

# same_as_perl CASE ARGS...: STDOUT and exit code match the checkout's perl run.
# STDERR is not compared (scrape prints parse progress there).
same_as_perl() {
  local name=$1; shift
  local rc_want=0 rc_got=0
  ref "$@" >"$work/want" 2>/dev/null || rc_want=$?
  bin "$@" >"$work/got" 2>/dev/null || rc_got=$?
  [ "$rc_want" = "$rc_got" ] || fail "$name: exit code differs (binary $rc_got, perl $rc_want)"
  cmp -s "$work/want" "$work/got" || fail "$name: STDOUT differs from perl -Ilib (binary: $(wc -c <"$work/got") bytes, perl: $(wc -c <"$work/want") bytes)"
}

want_version=$(sed -n "s/^our \$VERSION = '\(.*\)';/\1/p" "$root/lib/Locale/Simple.pm")
[ -n "$want_version" ] || fail "cannot read \$VERSION from lib/Locale/Simple.pm"

# Fixtures are copied, so reference and binary see the same relative paths.
cp -r "$root/t/data" "$work/cwd/data"
cd "$work/cwd"

# Startup on a fresh cache (the extraction run), then a second start on the same cache.
out=$(bin --version) || fail "--version failed on a fresh cache"
[ "$out" = "locale-simple $want_version" ] || fail "--version prints '$out', want 'locale-simple $want_version'"
echo "startup (--version, fresh cache): OK"
out=$(bin --version) || fail "--version failed on the second start"
[ "$out" = "locale-simple $want_version" ] || fail "second start prints '$out'"
echo "second start (same cache): OK"

same_as_perl "--help" --help
same_as_perl "help" help
same_as_perl "no command (exit 2)"
same_as_perl "unknown command (exit 2)" nope
echo "help and usage: OK"

cd data/n-fixtures
same_as_perl "scrape n-fixtures" scrape
same_as_perl "scrape n-fixtures --output json" scrape --output json
cd ../..
echo "scrape: OK"

# Parse errors are reported on STDERR; Perl exits 0 and so must the binary.
cd data
same_as_perl "scrape with parse errors" scrape --pl 1pl --only 1pl
rc=0; bin scrape --pl 1pl --only 1pl >/dev/null 2>&1 || rc=$?
[ "$rc" = 0 ] || fail "scrape with parse errors: binary exits $rc, want 0"
echo "scrape parse errors: OK"

same_as_perl "po2json --domain test" po2json --domain test locale/de_DE/LC_MESSAGES/test.po
same_as_perl "po2json edge.po (UTF-8)" po2json po2json/edge.po
same_as_perl "po2json --pretty" po2json --pretty po2json/edge.po
same_as_perl "po2json noplural.po" po2json po2json/noplural.po
bin po2json po2json/edge.po | perl -MJSON::PP -e 'local $/; my $j = JSON::PP->new->utf8->decode(<STDIN>); exit 0' \
  || fail "po2json edge.po: output is not valid UTF-8 JSON"
echo "po2json: OK"

# Error path: a missing file exits non-zero, the same code as Perl.
rc_want=0; rc_got=0
ref po2json nope.po >/dev/null 2>&1 || rc_want=$?
bin po2json nope.po >/dev/null 2>&1 || rc_got=$?
[ "$rc_want" -ne 0 ] || fail "po2json nope.po: perl exits 0, the reference is broken"
[ "$rc_want" = "$rc_got" ] || fail "po2json nope.po: exit code differs (binary $rc_got, perl $rc_want)"
echo "error path (po2json nope.po, exit $rc_got): OK"

echo "output equals perl -Ilib: OK"
echo "verify: OK"
