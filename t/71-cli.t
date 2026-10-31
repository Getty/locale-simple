use strict;
use warnings;
use utf8;
use Test::More;
use Test::InDistDir;
use Capture::Tiny 'capture';
use File::pushd;
use File::Temp 'tempdir';
use JSON::PP 'decode_json';
use Path::Tiny;
use Locale::Simple::CLI;
use Locale::Simple::PO2JSON qw( po2data data2json );

my $po = 't/data/locale/de_DE/LC_MESSAGES/test.po';
my ( $out, $err, $rc );

( $out, $err, $rc ) = capture { Locale::Simple::CLI::run( 'po2json', '--domain', 'myapp', $po ) };
is $rc, 0, 'po2json exits 0';
is_deeply [ keys %{ decode_json($out) } ], ['myapp'], '--domain names the bundle';

( $out, undef, $rc ) = capture { Locale::Simple::CLI::run( 'po2json', $po ) };
ok exists decode_json($out)->{test}, 'domain from file name';
is $out, path('t/data/po2json/test.domain.json')->slurp_raw, 'JS fixture is current';

( $out, undef, $rc ) = capture { Locale::Simple::CLI::run( 'po2json', '--pretty', $po ) };
like $out, qr/\n   /, '--pretty indents';

( $out, undef, $rc ) = capture { Locale::Simple::CLI::run('--version') };
is $rc, 0, '--version exits 0';
like $out, qr/^locale-simple \d+\.\d+\n\z/, '--version text';

for my $h (qw( help --help -h )) {
    ( $out, undef, $rc ) = capture { Locale::Simple::CLI::run($h) };
    is $rc, 0, "$h exits 0";
    like $out, qr/Usage/, "$h prints usage on STDOUT";
}

( undef, $err, $rc ) = capture { Locale::Simple::CLI::run('frobnicate') };
is $rc, 2, 'unknown command exits 2';
like $err, qr/Usage/, 'usage on STDERR';
( undef, $err, $rc ) = capture { Locale::Simple::CLI::run() };
is $rc, 2, 'no command exits 2';

( undef, $err, $rc ) = capture { Locale::Simple::CLI::run( 'po2json', 'nope.po' ) };
is $rc, 1, 'unreadable PO exits 1';
like $err, qr/Cannot read PO file/, 'message on STDERR';
( undef, $err, $rc ) = capture { Locale::Simple::CLI::run('po2json') };
is $rc, 2, 'po2json without file exits 2';

{
    my $g = pushd('t/data/n-fixtures');
    ( $out, undef, $rc ) = capture { Locale::Simple::CLI::run( 'scrape', '--only', 'N-calls\.pl' ) };
    is $rc, 0, 'scrape exits 0';
    like $out, qr/^msgid "/m, 'scrape prints a template';
}
{
    my $g = pushd( tempdir( CLEANUP => 1 ) );
    ( $out, undef, $rc ) = capture { Locale::Simple::CLI::run('scrape') };
    is $rc, 0, 'scrape in an empty dir exits 0';
    is $out, '', 'empty dir, empty output';
}

( $out, undef, $rc ) = capture { system $^X, '-Ilib', 'bin/po2json', $po };
is $out, data2json( po2data($po) ) . "\n", 'bin/po2json keeps its shape';
( $out, undef, $rc ) = capture { system $^X, '-Ilib', 'bin/po2json', '-p', $po };
is $out, data2json( po2data( $po, domain => 'test' ), pretty => 1 ) . "\n", 'bin/po2json -p';
( $out, undef, $rc ) = capture { system $^X, '-Ilib', 'bin/po2json', '-h' };
is $? >> 8, 1, 'bin/po2json -h exits 1';
( undef, $err ) = capture { system $^X, '-Ilib', 'bin/po2json', 'nope.po' };
is $? >> 8, 1, 'bin/po2json unreadable exits 1';
like $err, qr/Cannot read PO file/, 'bin/po2json message';

( $out, undef, $rc ) = capture { system $^X, '-I' . path('lib')->absolute, path('bin/locale-simple')->absolute, '--version' };
like $out, qr/^locale-simple /, 'bin/locale-simple runs';

{
    my $g = pushd('t/data/n-fixtures');
    ( $out, undef, $rc ) = capture { Locale::Simple::CLI::run( 'scrape', '--output', 'json', '--only', 'N-calls\.pl' ) };
    is ref decode_json($out), 'ARRAY', 'scrape json is an array';
    SKIP: {
        skip 'YAML not installed', 1 unless eval { require YAML; 1 };
        ( $out, undef, $rc ) = capture { Locale::Simple::CLI::run( 'scrape', '--output', 'yaml', '--only', 'N-calls\.pl' ) };
        like $out, qr/^---/, 'scrape yaml';
    }
}

{
    my $g = pushd('t/data/utf8-fixtures');
    ( $out, undef, $rc ) = capture { Locale::Simple::CLI::run( 'scrape', '--output', 'json' ) };
    my $found = JSON::PP->new->utf8->decode($out);
    is $found->[0]{msgid}, "Größe", 'scrape json is valid UTF-8 and decodes to the msgid';
}

{
    local @INC = ( sub { die "YAML.pm blocked\n" if $_[1] eq 'YAML.pm'; return }, @INC );
    local %INC = %INC;
    delete $INC{'YAML.pm'};
    my $g = pushd('t/data/n-fixtures');
    ( $out, $err, $rc ) = capture { Locale::Simple::CLI::run( 'scrape', '--output', 'yaml', '--only', 'N-calls\.pl' ) };
    is $rc, 1, 'scrape exits 1 when the scraper dies';
    like $err, qr/--output yaml needs the YAML module/, 'message on STDERR';
    is $out, '', 'nothing on STDOUT';
}

done_testing;
