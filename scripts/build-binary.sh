#!/usr/bin/env bash
# Pack bin/locale-simple into one standalone executable with PAR::Packer.
# Run from the checkout root. Output: $LOCALE_SIMPLE_BIN_OUT (default ./locale-simple).
set -euo pipefail

OUT="${LOCALE_SIMPLE_BIN_OUT:-./locale-simple}"
[ -f bin/locale-simple ] || { echo "ERROR: run from the checkout root" >&2; exit 1; }
command -v pp >/dev/null 2>&1 || { echo "ERROR: pp (PAR::Packer) is not installed" >&2; exit 1; }

# Every module needed at run time must be installed, or the loaded set below is short.
perl -Ilib -MLocale::TextDomain -MParser::MGC -MMoo -MTry::Tiny -MIO::All -Mcurry -MJSON::PP -e1 \
  || { echo "ERROR: runtime dependencies missing (cpanm --installdeps .)" >&2; exit 1; }

# The loaded set: scripts/loaded-modules.pl runs the real scrape and po2json paths, the
# help/version/error paths, and prints every module that came from its own file. pp's
# scanner reads source and misses what loads by name (Locale::TextDomain picks its gettext
# backend at run time; Moo, Parser::MGC and the scraper's parsers load lazily). verify-binary.sh
# requires the same list inside the archive.
loaded=(); while IFS= read -r m; do loaded+=("$m"); done < <(perl -Ilib scripts/loaded-modules.pl)
[ "${#loaded[@]}" -gt 25 ] || { echo "ERROR: loaded set suspiciously small (${#loaded[@]})" >&2; exit 1; }
mods=(); for m in "${loaded[@]}"; do mods+=(-M "$m"); done

# PAR_VERBATIM=1: pp's POD-stripping filter corrupts files with POD between code.
# -I lib: the checkout's lib/ wins over any installed copy.
# -M 'Locale::Simple::**': the scraper's parsers load by name on some paths only.
PAR_VERBATIM=1 pp -o "$OUT" \
  -I lib \
  "${mods[@]}" \
  -M 'Locale::Simple::**' \
  bin/locale-simple

chmod +x "$OUT"
echo "Built $OUT ($(du -h "$OUT" | cut -f1), ${#loaded[@]} modules)"
