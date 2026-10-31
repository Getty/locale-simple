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

# The loaded set: run the real scrape and po2json paths, then print every module that
# came from its own file. pp's scanner reads source and misses what loads by name
# (Locale::TextDomain picks its gettext backend at run time; Moo, Parser::MGC and the
# scraper's per-language parsers load lazily). A module that fails to load is reported.
mapfile -t loaded < <(perl -Ilib - <<'PERL'
use strict; use warnings;
use File::Find ();
use File::Temp ();
my %mods;
for my $dir ( grep { !ref } @INC ) {
  next unless -d "$dir/Locale/Simple";
  File::Find::find( { no_chdir => 1, wanted => sub {
    return unless /\.pm\z/;
    ( my $m = substr $_, length($dir) + 1 ) =~ s{/}{::}g;
    $m =~ s/\.pm\z//;
    $mods{$m} = 1;
  } }, "$dir/Locale/Simple" );
}
# The gettext backends of Locale::TextDomain (gettext_pp / gettext_dumb are chosen at run time).
$mods{$_} = 1 for qw(
  Locale::TextDomain Locale::Messages Locale::gettext_pp Locale::gettext_dumb
  Locale::Recode Locale::Recode::_Aliases
);
for my $m ( sort keys %mods ) {
  eval "require $m; 1" or warn "build-binary: not bundled: $m (" . ( split /\n/, $@ )[0] . ")\n";
}
# Run both commands for real, so the lazy loads happen.
require Locale::Simple::CLI;
my $dir = File::Temp::tempdir( CLEANUP => 1 );
open my $fh, '>', "$dir/a.pl" or die $!;
print $fh qq{use Locale::Simple;\nl("hello");\nln("one","many",2);\nlp("ctx","x");\n};
close $fh;
open my $po, '>', "$dir/x.po" or die $!;
print $po qq{msgid ""\nmsgstr ""\n"Content-Type: text/plain; charset=UTF-8\\n"\n"Plural-Forms: nplurals=2; plural=(n != 1);\\n"\n\nmsgid "a"\nmsgstr "b"\n};
close $po;
{
  chdir $dir or die $!;
  open my $oldout, '>&', \*STDOUT or die;
  open STDOUT, '>', '/dev/null' or die;
  open my $olderr, '>&', \*STDERR or die;
  open STDERR, '>', '/dev/null' or die;
  for my $fmt (qw(po json perl)) {
    Locale::Simple::CLI::run( 'scrape', '--output', $fmt );
  }
  Locale::Simple::CLI::run( 'po2json', '--pretty', "$dir/x.po" );
  open STDOUT, '>&', $oldout or die;
  open STDERR, '>&', $olderr or die;
  chdir '/';
}
for my $file ( sort keys %INC ) {
  next unless $file =~ m{\A[\w/]+\.pm\z};
  next unless defined $INC{$file} && !ref $INC{$file} && $INC{$file} =~ m{/\Q$file\E\z};
  ( my $m = $file ) =~ s{/}{::}g;
  $m =~ s/\.pm\z//;
  print "$m\n";
}
PERL
)
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
