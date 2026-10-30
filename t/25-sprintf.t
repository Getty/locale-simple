#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use utf8;

use Locale::Simple;

binmode Test::More->builder->$_, ':encoding(UTF-8)' for qw( output failure_output todo_output );

# The sprintf of the translation functions, row by row: the conversions, flags,
# width, precision and N$ position of mo-reader.md §5, as C and Perl format
# them. A placeholder without an argument stays as it is, extra arguments are
# ignored, and neither warns. python/test.py runs the same rows (sprintf_table).

l_nolocales(1);

my @rows = (
	[ '%2$s %1$s', [ 'a', 'b' ], 'b a' ],
	[ '%1$s %s', [ 'a', 'b' ], 'a a' ],
	[ '[%5d]', [ 42 ], '[   42]' ],
	[ '[%-5d]', [ 42 ], '[42   ]' ],
	[ '[%05d]', [ 42 ], '[00042]' ],
	[ '[%05d]', [ -42 ], '[-0042]' ],
	[ '%.3d', [ 5 ], '005' ],
	[ '[%06.3d]', [ 5 ], '[   005]' ],
	[ '%.0d', [ 0 ], '' ],
	[ '%+.0d', [ 0 ], '+' ],
	[ '%.2f', [ 3.14159 ], '3.14' ],
	[ '[%5.1f]', [ 3.14159 ], '[  3.1]' ],
	[ '%.f', [ 2.7 ], '3' ],
	[ '%f', [ 1.5 ], '1.500000' ],
	[ '%F', [ 1.5 ], '1.500000' ],
	[ '%e', [ 1234.5 ], '1.234500e+03' ],
	[ '%.1e', [ 0.00012 ], '1.2e-04' ],
	[ '100%% %s', [ 'x' ], '100% x' ],
	[ q{[%'*8s]}, [ 'ab' ], '[******ab]' ],
	[ q{[%-'*8s]}, [ 'ab' ], '[ab******]' ],
	[ q{[%'*6d]}, [ -42 ], '[***-42]' ],
	[ q{[%'.8s]}, [ 'ab' ], '[......ab]' ],
	[ q{[%'é5s]}, [ 'ab' ], '[éééab]' ],
	[ q{[%'*s]}, [ 'ab' ], '[ab]' ],
	[ '[%06s]', [ 'ab' ], '[0000ab]' ],
	[ '[%-06s]', [ 'ab' ], '[ab    ]' ],
	[ '%+d %+d', [ 5, -5 ], '+5 -5' ],
	[ '% d', [ 5 ], ' 5' ],
	[ '%+x % u', [ 255, 3 ], 'ff 3' ],
	[ '%b %o %x %X', [ 5, 8, 255, 255 ], '101 10 ff FF' ],
	[ '[%08b]', [ 5 ], '[00000101]' ],
	[ '[%-6b]', [ 5 ], '[101   ]' ],
	[ '%x', [ -1 ], 'ffffffffffffffff' ],
	[ '%u', [ 3 ], '3' ],
	[ '%c', [ 65 ], 'A' ],
	[ '%c', [ 233 ], 'é' ],
	[ '%.3s', [ 'abcdef' ], 'abc' ],
	[ '%d', [ '12' ], '12' ],
	[ '%d', [ 3.9 ], '3' ],
	[ '%x', [ '255' ], 'ff' ],
	[ '%.1f', [ '2.25e1' ], '22.5' ],
	[ '%s', [ 'a', 'b', 'c' ], 'a' ],
	[ '%s and %s', [ 'a' ], 'a and %s' ],
	[ '%2$s and %1$s', [ 'a' ], '%2$s and a' ],
	[ '%3$s', [ 'a' ], '%3$s' ],
	[ '%2$05d', [ 0, 7 ], '00007' ],
	[ '50% off', [], '50% off' ],
	[ '100%', [], '100%' ],
	[ '%y', [ 'a' ], '%y' ],
	[ 'plain', [], 'plain' ],
	[ 'héllo %s', [ 'wörld' ], 'héllo wörld' ],
	[ '[%4s]', [ 'é' ], '[   é]' ],
);

# Beyond §5, Perl and Python also take a * width or precision, the # flag and
# the conversions i, E, g and G.
push @rows, (
	[ '[%*d]', [ 5, 42 ], '[   42]' ],
	[ '[%-*d]', [ 5, 42 ], '[42   ]' ],
	[ '[%*d]', [ -5, 42 ], '[42   ]' ],
	[ '%.*f', [ 1, 3.14159 ], '3.1' ],
	[ q{[%'*-*s]}, [ 5, 'ab' ], '[ab***]' ],
	[ '[%*d]', [ 5 ], '[%*d]' ],
	[ '%#o %#x %#X %#b', [ 8, 255, 255, 5 ], '010 0xff 0XFF 0b101' ],
	[ '%#x', [ 0 ], '0' ],
	[ '%i', [ 7 ], '7' ],
	[ '%E', [ 1234.5 ], '1.234500E+03' ],
	[ '%g %G', [ 0.0001, 1e-10 ], '0.0001 1E-10' ],
);

my @warnings;
local $SIG{__WARN__} = sub { push @warnings, @_ };

# Called through a reference, so the scraper of t/50 reads no msgid here.
my $translate = \&l;
for my $row (@rows) {
	my ( $format, $args, $want ) = @{$row};
	is( $translate->( $format, @{$args} ), $want, 'sprintf '.$format );
}

is_deeply( \@warnings, [], 'missing and extra arguments give no warning' );

done_testing;
