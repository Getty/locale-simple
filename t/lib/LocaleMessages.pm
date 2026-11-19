package LocaleMessages;

# Test helper: can this perl move LC_MESSAGES away from C?
#
# gettext ignores LANGUAGE while the messages locale is C or POSIX (libintl-perl
# >= 1.36, like GNU gettext). A perl built with -DNO_LOCALE_MESSAGES (OpenBSD)
# keeps the category on C whatever setlocale is told: POSIX::LC_MESSAGES exists,
# setlocale may even return a true value, and nothing ever translates. The tests
# that need a translation ask here and skip, with the reason, where that is so.
#
# Every attempt is judged by querying setlocale(LC_MESSAGES) afterwards, never by
# the return value of the set.
#
# The helper is test-only and does not call Locale::Simple.

use strict;
use warnings;
use Config;
use POSIX ();
use Test::More ();

# can_translate( $lang, %opt ) returns ( $ok, $reason ). $reason is empty when
# $ok is true. Options:
#   keep        leave LC_MESSAGES on the locale that worked (default: put it back)
#   setlocale   code ref called as setlocale( $category, $locale? ), for the
#               helper's own test
#   lc_messages code ref that returns the LC_MESSAGES category, or undef where
#               the platform has none
sub can_translate {
	my ( $lang, %opt ) = @_;
	my $setlocale   = $opt{setlocale}   || \&POSIX::setlocale;
	my $lc_messages = $opt{lc_messages} || sub { POSIX::LC_MESSAGES() };

	my $category = eval { $lc_messages->() };
	return ( 1, '' ) unless defined $category;    # no LC_MESSAGES (Windows): the environment decides

	my $original = $setlocale->($category);
	my @tried;
	for my $locale ( grep { defined && length } $lang, 'C.UTF-8', 'en_US.UTF-8' ) {
		$setlocale->( $category, $locale );
		my $now = $setlocale->($category);
		if ( defined $now && $now ne 'C' && $now ne 'POSIX' ) {
			$setlocale->( $category, $original ) if !$opt{keep} && defined $original;
			return ( 1, '' );
		}
		push @tried, $locale . ' -> ' . ( defined $now ? $now : 'undef' );
	}
	$setlocale->( $category, $original ) if !$opt{keep} && defined $original;

	my $reason = 'LC_MESSAGES stays C here (' . join( ', ', @tried ) . '), so gettext ignores LANGUAGE and nothing translates';
	$reason .= '; this perl is built with -DNO_LOCALE_MESSAGES' if ( $Config{ccflags} || '' ) =~ /NO_LOCALE_MESSAGES/;
	return ( 0, $reason );
}

# skip_all_unless_translatable( $lang ) is for the top of a test file, before any
# plan: it skips the whole file where no translation can happen, and leaves
# LC_MESSAGES on the locale that worked, for a test that calls gettext directly.
sub skip_all_unless_translatable {
	my ( $lang, %opt ) = @_;
	my ( $ok, $reason ) = can_translate( $lang, %opt );
	Test::More::plan( skip_all => $reason ) unless $ok;
	return;
}

1;
