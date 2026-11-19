#!/usr/bin/env perl

# l_lang() judges every setlocale(LC_MESSAGES, ...) it makes, for the language
# and for each fallback, by what setlocale(LC_MESSAGES) answers afterwards,
# not by what the set returns: a perl built without the messages category
# (-DNO_LOCALE_MESSAGES, OpenBSD) takes every set and stays at C. While the
# answer is C, POSIX or undef, l_lang goes on to the next fallback.
#
# The fake setlocale plays the messages category: a set moves it only to a
# locale in "lands", returns what "returns" says, and every call is recorded.

use strict;
use warnings;

use POSIX ();
use Test::More;

use Locale::Simple;

plan skip_all => 'POSIX has no LC_MESSAGES on this platform'
	unless defined eval { POSIX::LC_MESSAGES() };

sub attempts {
	my ( %fake ) = @_;
	my $now = $fake{start};
	my @calls;
	local *Locale::Simple::setlocale = sub {
		my ( $category, $locale ) = @_;
		if ( @_ == 1 ) {
			push @calls, 'query';
			return $now;
		}
		push @calls, 'set '.$locale;
		$now = $locale if $fake{lands}{$locale};
		return $fake{returns}->($locale);
	};
	local %ENV = %ENV;
	l_lang('de_DE');
	return \@calls;
}

my $every = [ 'set de_DE', 'query', 'set C.UTF-8', 'query', 'set en_US.UTF-8', 'query' ];

for my $start ( 'C', 'POSIX', undef ) {
	my $name = defined $start ? $start : 'undef';
	is_deeply(
		attempts( start => $start, lands => {}, returns => sub { $_[0] } ),
		$every,
		'the set returns true, the query stays '.$name.': l_lang tries the language and both fallbacks',
	);
}

is_deeply(
	attempts( start => 'C', lands => { 'en_US.UTF-8' => 1 }, returns => sub { $_[0] } ),
	$every,
	'every set returns true, only the second fallback lands: l_lang queries after each and ends there',
);

is_deeply(
	attempts(
		start   => 'C',
		lands   => { 'en_US.UTF-8' => 1 },
		returns => sub { $_[0] eq 'en_US.UTF-8' ? $_[0] : undef },
	),
	$every,
	'the language and C.UTF-8 fail, en_US.UTF-8 lands: l_lang queries after each',
);

is_deeply(
	attempts( start => 'C', lands => { 'C.UTF-8' => 1 }, returns => sub { $_[0] } ),
	[ 'set de_DE', 'query', 'set C.UTF-8', 'query' ],
	'the first fallback lands: l_lang stops there',
);

is_deeply(
	attempts( start => 'C', lands => { 'C.UTF-8' => 1 }, returns => sub { undef } ),
	[ 'set de_DE', 'query', 'set C.UTF-8', 'query' ],
	'the first fallback lands although its set returns false: l_lang stops there',
);

is_deeply(
	attempts( start => 'C', lands => { de_DE => 1 }, returns => sub { $_[0] } ),
	[ 'set de_DE', 'query' ],
	'the language lands: l_lang tries no fallback',
);

done_testing;
