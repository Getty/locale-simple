use strict;
use warnings;
use Test::More;

use Test::InDistDir;
use Test::Warn;
use Test::Fatal;
use Path::Tiny;
use JSON::PP qw( decode_json );
use Locale::Simple::PO2JSON qw( po2data data2json );

my $test = 't/data/locale/de_DE/LC_MESSAGES/test.po';
my $d = po2data($test);
is $d->{''}{Language}, 'de_DE', 'header trimmed';
is $d->{''}{lang},     'de_DE', 'lang from Language';
is_deeply $d->{"alien\x04Hello"}, [ undef, 'Hallo Ausserirdischer' ], 'context key';
is_deeply $d->{'You have %d message'},
  [ 'You have %d messages', 'Du hast %d Nachricht', 'Du hast %d Nachrichten' ], 'plural';
is_deeply [ keys %{ po2data( $test, domain => 'myapp' ) } ], ['myapp'], 'domain wrap';
is_deeply decode_json( path('t/data/po2json/test.expected.json')->slurp_raw ), $d, 'golden';

my $e = po2data('t/data/po2json/edge.po');
is $e->{multi}[1], "Zeile 1\nZeile 2", 'multi-line joined';
is $e->{esc}[1],   "Ein \"Zitat\", ein \\ und ein\tTab", 'escapes';
is $e->{Size}[1],  "Gr\x{f6}\x{df}e \x{2192}", 'utf8 decoded';
ok !exists $e->{$_}, "$_ skipped" for qw(fuzzy empty old);
is scalar @{ $e->{'%d file'} }, 4, 'three plural forms + msgid_plural';
is_deeply decode_json( data2json($e) ), $e, 'json round-trip keeps utf8';
is data2json($e), data2json($e), 'canonical';
like data2json( $e, pretty => 1 ), qr/\n   /, 'pretty';
unlike data2json($e), qr/\n\z/, 'no trailing newline';
unlike data2json( $e, pretty => 1 ), qr/\n\z/, 'no trailing newline when pretty';
warnings_like { po2data('t/data/po2json/noplural.po') } [qr/Plural-Forms/], 'warns once';
like exception { po2data('t/data/po2json/missing.po') }, qr/Cannot read PO file t\/data\/po2json\/missing\.po: /, 'missing';

done_testing;
