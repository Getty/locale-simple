#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use IO::All;
use utf8;

use Encode qw( encode );
use FindBin qw($Bin);

use Locale::Simple;

use File::Temp qw/ tempfile tempdir /;

my $tmpdir = tempdir();

l_dry($tmpdir.'/dryrun.po');

is(
	l("Hello"),
	"Hello",
	"simple"
);

is(
	ln("You have %d message","You have %d messages",4),
	'You have 4 messages',
	"dryrun simple plural test with plural"
);

is(
	ln("You have %d message","You have %d messages",1),
	'You have 1 message',
	"dryrun simple plural test with single"
);

is(
	ln("You have %d message of %s","You have %d messages of %s",1,'harry'),
	'You have 1 message of harry',
	"dryrun complex plural test with single"
);

is(
	ln("You have %d message of %s","You have %d messages of %s",4,'harry'),
	'You have 4 messages of harry',
	"dryrun complex plural test with plural"
);

is(io($tmpdir.'/dryrun.po')->slurp,<<__EOT__,'checking generated po');
msgid "Hello"

msgid "You have %d message"
msgid_plural "You have %d messages"

msgid "You have %d message"
msgid_plural "You have %d messages"

msgid "You have %d message of %s"
msgid_plural "You have %d messages of %s"

msgid "You have %d message of %s"
msgid_plural "You have %d messages of %s"

__EOT__

# The same calls as the dry_run_shared_format case in python/test.py: both
# runtimes write this file byte for byte.
my $shared = $tmpdir.'/shared.po';
l_dry($shared);

is_deeply(
	[
		l('Hello'),
		l(''),
		ld('othertest','Hello'),
		lp('alien','Hello'),
		ln('%2$s has %1$d message','%2$s has %1$d messages',2,'harry'),
		ldnp('othertest','inbox','You have %d message','You have %d messages',1),
		l("Say \"%s\"\\n\nGrüße",'hi'),
		l("Tab\there\rand CR"),
	],
	[
		'Hello',
		'',
		'Hello',
		'Hello',
		'harry has 2 messages',
		'You have 1 message',
		"Say \"hi\"\\n\nGrüße",
		"Tab\there\rand CR",
	],
	'dry run formats domain, context, plural and positional calls',
);

is(io($shared)->binary->all,encode('UTF-8',<<'__EOT__'),'dry-run file matches the shared expected bytes');
msgid "Hello"

# domain: othertest
msgid "Hello"

msgctxt "alien"
msgid "Hello"

msgid "%2$s has %1$d message"
msgid_plural "%2$s has %1$d messages"

# domain: othertest
msgctxt "inbox"
msgid "You have %d message"
msgid_plural "You have %d messages"

msgid "Say \"%s\"\\n\nGrüße"

msgid "Tab\there\rand CR"

__EOT__

# Leaving dry-run mode brings back the l_dir check, as in the siblings.
l_dry(undef);
eval { l('Hello') };
like($@,qr/please set a locale directory/,'l_dry(undef) brings back the l_dir check');

# The dry-run file has LF line ends on every platform. A child perl with
# the :crlf default layer that Windows uses writes the same bytes.
{
	local $ENV{PERLIO} = ':unix:crlf';
	my $crlf = $tmpdir.'/crlf.po';
	system( $^X, ( map { '-I'.$_ } grep { !ref } @INC ), '-MLocale::Simple',
	  '-e', 'l_dry(shift); ld(q(othertest),q(Hello))', $crlf ) == 0
	  or die 'child perl failed: '.$?;
	my $bytes = io($crlf)->binary->all;
	unlike($bytes,qr/\r/,'dry-run file holds no CR under a :crlf default layer');
	is($bytes,qq{# domain: othertest\nmsgid "Hello"\n\n},'dry-run file keeps LF line ends');
}

done_testing;
