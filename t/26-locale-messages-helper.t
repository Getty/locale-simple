#!/usr/bin/env perl

# t/lib/LocaleMessages.pm decides which tests skip themselves where LC_MESSAGES
# cannot leave C. The decision is checked against a fake setlocale, the way
# t/24 fakes a platform without LC_MESSAGES.

use strict;
use warnings;
use Test::More;

use FindBin qw( $Bin );
use lib "$Bin/lib";
use LocaleMessages;

# A fake messages locale: %accept names the locales the "platform" takes over
# to the query; a locale not in it is ignored, like on a perl built with
# -DNO_LOCALE_MESSAGES (accept nothing) or on a box without that locale.
sub fake {
	my (%accept) = ( C => 'C', @_ );
	my $current = 'C';
	my @calls;
	my $code = sub {
		my ( $category, $locale ) = @_;
		push @calls, defined $locale ? $locale : '?';
		$current = $accept{$locale} if defined $locale && exists $accept{$locale};
		return $locale if defined $locale && exists $accept{$locale};    # the set's return value
		return defined $locale ? undef : $current;
	};
	return ( $code, \@calls, \$current );
}

my %with = ( lc_messages => sub { 5 } );

# the language itself is installed
{
	my ( $set, $calls, $current ) = fake( de_DE => 'de_DE' );
	my ( $ok, $reason ) = LocaleMessages::can_translate( 'de_DE', %with, setlocale => $set );
	ok( $ok, 'an installed language can leave C' );
	is( $reason, '', 'and gives no reason' );
	is( $$current, 'C', 'the messages locale is put back where it was' );
}

# only a fallback works
{
	my ( $set, $calls ) = fake( 'C.UTF-8' => 'C.UTF-8' );
	my ( $ok ) = LocaleMessages::can_translate( 'de_DE', %with, setlocale => $set );
	ok( $ok, 'C.UTF-8 is enough when the language is not installed' );
	is_deeply( [ grep { $_ ne '?' } @$calls ], [ 'de_DE', 'C.UTF-8', 'C' ], 'tried the language first, then C.UTF-8, then restored C' );
}
{
	my ( $set ) = fake( 'en_US.UTF-8' => 'en_US.UTF-8' );
	ok( ( LocaleMessages::can_translate( 'de_DE', %with, setlocale => $set ) )[0], 'en_US.UTF-8 is enough too' );
}

# keep leaves the working locale in place
{
	my ( $set, $calls, $current ) = fake( de_DE => 'de_DE' );
	LocaleMessages::can_translate( 'de_DE', %with, setlocale => $set, keep => 1 );
	is( $$current, 'de_DE', 'keep leaves LC_MESSAGES on the locale that worked' );
}

# the category never leaves C: the set claims success, the query says C
{
	my $current = 'C';
	my $set = sub { my ( $cat, $loc ) = @_; return defined $loc ? $loc : $current };    # lies: returns the locale, stays C
	my ( $ok, $reason ) = LocaleMessages::can_translate( 'de_DE', %with, setlocale => $set );
	ok( !$ok, 'a set that reports success but leaves the query on C is not trusted' );
	like( $reason, qr/LC_MESSAGES stays C/, 'the reason names the cause' );
	like( $reason, qr/de_DE -> C, C\.UTF-8 -> C, en_US\.UTF-8 -> C/, 'and every attempt with what the query answered' );
}
{
	my ( $set ) = fake();
	my ( $ok, $reason ) = LocaleMessages::can_translate( 'de_DE', %with, setlocale => $set );
	ok( !$ok, 'no locale taken at all is a skip' );
}

# POSIX also names the C locale
{
	my ( $set ) = fake( de_DE => 'POSIX', 'C.UTF-8' => 'POSIX', 'en_US.UTF-8' => 'POSIX' );
	ok( !( LocaleMessages::can_translate( 'de_DE', %with, setlocale => $set ) )[0], 'a query that answers POSIX counts as C' );
}

# an undefined query
{
	my $set = sub { return undef };
	my ( $ok, $reason ) = LocaleMessages::can_translate( 'de_DE', %with, setlocale => $set );
	ok( !$ok, 'a query that answers undef is a skip' );
	like( $reason, qr/de_DE -> undef/, 'and says so' );
}

# no LC_MESSAGES on the platform: the environment decides, nothing to skip
{
	my @calls;
	my ( $ok, $reason ) = LocaleMessages::can_translate(
		'de_DE',
		lc_messages => sub { return },
		setlocale   => sub { push @calls, [@_]; return },
	);
	ok( $ok, 'without LC_MESSAGES there is nothing to skip' );
	is_deeply( \@calls, [], 'and setlocale is left alone' );
}

# this perl, for the record
my ( $ok, $reason ) = LocaleMessages::can_translate('de_DE');
diag( $ok ? 'LC_MESSAGES can leave C on this perl' : "LC_MESSAGES cannot leave C on this perl: $reason" );

done_testing;
