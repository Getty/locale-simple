#!/usr/bin/env perl
use strict;
use warnings;

# Usage: xbin/release.pl python <perl-version>
#
# Called from dist.ini's run_after_release hook. Bumps Python's version file
# to match the Perl version, builds the wheel/sdist, and uploads to PyPI.
#
# JS is intentionally NOT handled here — it is published by
# .github/workflows/publish-js.yml on tag push using npm Trusted Publishing
# (OIDC), so a flaky `npm publish` can never poison a dzil release.

use File::Spec;
use FindBin qw($Bin);

my ( $target, $perl_version ) = @ARGV;
die "usage: $0 python <perl-version>\n" unless $target and $perl_version;
die "unknown target: $target (only 'python' is handled here; JS is in CI)\n"
    unless $target eq 'python';

my $root = File::Spec->rel2abs( "$Bin/.." );

sub run {
    my @cmd = @_;
    print "+ @cmd\n";
    system( @cmd ) == 0 or die "command failed (exit @{[ $? >> 8 ]}): @cmd\n";
}

chdir "$root/python" or die "chdir python: $!";

my $file = 'locale_simple.py';
open my $in,  '<', $file or die "read $file: $!";
my @lines = <$in>;
close $in;
for ( @lines ) {
    s/__version__ = .*/__version__ = "$perl_version"/;
}
open my $out, '>', $file or die "write $file: $!";
print $out @lines;
close $out;

run( 'rm', '-rf', 'dist' );
run( 'python', '-m', 'build' );

opendir my $dh, 'dist' or die "opendir dist: $!";
my @dist = grep { !/^\./ } readdir $dh;
closedir $dh;
run( 'twine', 'upload', map { "dist/$_" } @dist );
