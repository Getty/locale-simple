#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use utf8;

use Config qw( %Config );
use FindBin qw($Bin);
use JSON::PP ();

use Locale::Simple;

binmode Test::More->builder->$_, ':encoding(UTF-8)' for qw( output failure_output todo_output );

# b o u x X show a negative number as unsigned 64-bit (mo-reader.md §5).
# CORE::sprintf does that on a perl with an 8-byte IV only; with a 4-byte IV
# it shows 32 bits, and Locale::Simple formats such a value itself, with
# Math::BigInt. Locale::Simple::_ivsize answers 4 here, so the rows run that
# path on a 64-bit perl too. There CORE::sprintf gives the same strings, so
# the rows alone cannot tell the paths apart: the checks on Math::BigInt pin
# that the 4-byte path ran, and that the 8-byte path never loads it.

# Called through a reference, so the scraper of t/50 reads no msgid here.
my $translate = \&l;

l_nolocales(1);

my @warnings;
local $SIG{__WARN__} = sub { push @warnings, @_ };

my @rows = (
	[ '%x',          [-1],         'ffffffffffffffff' ],
	[ '%X',          [-1],         'FFFFFFFFFFFFFFFF' ],
	[ '%o',          [-1],         '1777777777777777777777' ],
	[ '%b',          [-1],         '1' x 64 ],
	[ '%u',          [-1],         '18446744073709551615' ],
	[ '%u',          [-2],         '18446744073709551614' ],
	[ '%x',          [-255],       'ffffffffffffff01' ],
	[ '%x',          ['-255'],     'ffffffffffffff01' ],
	[ '%x',          [-1.9],       'ffffffffffffffff' ],
	[ '%x',          [-0.5],       '0' ],
	[ '%x',          [-2**31],     'ffffffff80000000' ],
	[ '%x',          [-2**32],     'ffffffff00000000' ],
	[ '%u',          [-5000000000], '18446744068709551616' ],
	[ '%x',          [-2**63],     '8000000000000000' ],
	[ '%x',          [-2**70],     '8000000000000000' ],
	[ '%x',          [255],        'ff' ],
	[ '%#x',         [-1],         '0xffffffffffffffff' ],
	[ '%#X',         [-1],         '0XFFFFFFFFFFFFFFFF' ],
	[ '%#o',         [-1],         '01777777777777777777777' ],
	[ '%#b',         [-8],         '0b'.( '1' x 61 ).'000' ],
	[ '%#u',         [-1],         '18446744073709551615' ],
	[ '%+x % x',     [-1, -1],     'ffffffffffffffff ffffffffffffffff' ],
	[ '[%20x]',      [-1],         '[    ffffffffffffffff]' ],
	[ '[%-20x]',     [-1],         '[ffffffffffffffff    ]' ],
	[ '[%020x]',     [-1],         '[0000ffffffffffffffff]' ],
	[ '[%#020x]',    [-1],         '[0x00ffffffffffffffff]' ],
	[ '[%5x]',       [-1],         '[ffffffffffffffff]' ],
	[ '[%.20x]',     [-1],         '[0000ffffffffffffffff]' ],
	[ '[%.x]',       [-1],         '[ffffffffffffffff]' ],
	[ '[%022.18x]',  [-1],         '[    00ffffffffffffffff]' ],
	[ '[%020.x]',    [-1],         '[    ffffffffffffffff]' ],
	[ '[%#.25o]',    [-1],         '[0001777777777777777777777]' ],
	[ "[%'*20x]",    [-1],         '[****ffffffffffffffff]' ],
	[ "[%-'*20x]",   [-1],         '[ffffffffffffffff****]' ],
	[ "[%'*020x]",   [-1],         '[****ffffffffffffffff]' ],
	[ "[%'é18X]",    [-1],         '[ééFFFFFFFFFFFFFFFF]' ],
	[ '[%*x]',       [20, -1],     '[    ffffffffffffffff]' ],
	[ '[%*x]',       [-20, -1],    '[ffffffffffffffff    ]' ],
	[ '[%.*x]',      [20, -1],     '[0000ffffffffffffffff]' ],
	[ '[%.*x]',      [-1, -1],     '[ffffffffffffffff]' ],
	[ "[%'*-*x]",    [20, -1],     '[ffffffffffffffff****]' ],
	[ '%2$x %1$d',   [-1, -2],     'fffffffffffffffe -1' ],
	[ '%x %d',       [-1, -1],     'ffffffffffffffff -1' ],
);

# The seam answers the IV size Configure recorded for this perl.
my $ivsize = Locale::Simple->can('_ivsize');
is( $ivsize && $ivsize->(), $Config{ivsize}, 'Locale::Simple::_ivsize answers the IV size of this perl' );

if ( $Config{ivsize} >= 8 ) {
	$translate->( $_->[0], @{ $_->[1] } ) for @rows;
	ok( !$INC{'Math/BigInt.pm'}, 'an 8-byte IV formats without Math::BigInt' );
}

{
	no warnings 'redefine';
	*Locale::Simple::_ivsize = sub { 4 };
}

for my $row (@rows) {
	my ( $format, $args, $want ) = @{$row};
	is( $translate->( $format, @{$args} ), $want, '4-byte IV: '.$format.' of '.join( ', ', @{$args} ) );
}
ok( $INC{'Math/BigInt.pm'}, 'the 4-byte IV path formats with Math::BigInt' );

# A string that is not a number reaches CORE::sprintf untouched on the 4-byte
# path and warns there exactly as on the 8-byte path.
{
	my ( @small, @large );
	{
		local $SIG{__WARN__} = sub { push @small, @_ };
		is( $translate->( '%x', 'abc' ), '0', '4-byte IV: %x of abc' );
	}
	{
		no warnings 'redefine';
		local *Locale::Simple::_ivsize = sub { 8 };
		local $SIG{__WARN__} = sub { push @large, @_ };
		$translate->( '%x', 'abc' );
	}
	like( $small[0], qr/isn't numeric in sprintf/, '4-byte IV: %x of abc warns that it is not numeric' );
	is_deeply( \@small, \@large, '4-byte IV: %x of abc warns as on the 8-byte path' );
}

# The shared rows of t/25-sprintf.t pass on the 4-byte path as well.
my $vectors = do {
	open my $fh, '<:raw', $Bin.'/data/sprintf.json' or die 'sprintf.json: '.$!;
	local $/;
	JSON::PP->new->utf8->decode(<$fh>);
};
for my $row ( @{ $vectors->{rows} }, @{ $vectors->{perl_python_rows} } ) {
	is( $translate->( $row->{format}, @{ $row->{args} } ), $row->{want}, '4-byte IV, sprintf.json: '.$row->{format} );
}

# On an 8-byte IV CORE::sprintf is the reference: every combination of
# conversion, flags, width, precision and value formats alike on both paths.
SKIP: {
	skip 'CORE::sprintf of a '.$Config{ivsize}.'-byte IV shows no 64 bits', 1 unless $Config{ivsize} >= 8;
	my @differ;
	for my $conversion (qw( b o u x X )) {
		for my $flags ( '', '#', '-', '0', '#0', '-#', '+', "'*", "-'*" ) {
			for my $width ( '', 5, 30 ) {
				for my $precision ( undef, '', 20, 25 ) {
					my $format = '%'.$flags.$width.( defined $precision ? '.'.$precision : '' ).$conversion;
					for my $value ( -1, '-255', -5000000000, -2**70 ) {
						my $small = $translate->( $format, $value );
						my $large = do {
							no warnings 'redefine';
							local *Locale::Simple::_ivsize = sub { 8 };
							$translate->( $format, $value );
						};
						push @differ, $format.' of '.$value.': '.$small.' vs '.$large unless $small eq $large;
					}
				}
			}
		}
	}
	is_deeply( \@differ, [], '4-byte IV path formats as CORE::sprintf of an 8-byte IV' );
}

is_deeply( \@warnings, [], 'no warnings' );

done_testing;
