#!/usr/bin/env perl
use strict;
use warnings;

# Usage: xbin/release.pl <target> <perl-version>
#   target = python | js
#
# Called from dist.ini's run_after_release hook. Bumps the target
# language's version file to match the Perl version, builds the package,
# and uploads it.
#
# Perl versions carry three decimal digits after the dot, interpreted as
# minor (first digit) and patch (remaining two) when converted to npm:
#
#   0.019  ->  0.0.19
#   0.020  ->  0.0.20
#   0.100  ->  0.1.0
#   0.123  ->  0.1.23
#
# Already-semver strings (three dot-separated segments) pass through.

use File::Spec;
use FindBin qw($Bin);

my ( $target, $perl_version ) = @ARGV;
die "usage: $0 <python|js> <perl-version>\n" unless $target and $perl_version;

my $root = File::Spec->rel2abs( "$Bin/.." );

sub run {
    my @cmd = @_;
    print "+ @cmd\n";
    system( @cmd ) == 0 or die "command failed (exit @{[ $? >> 8 ]}): @cmd\n";
}

if ( $target eq 'python' ) {
    chdir "$root/python" or die "chdir python: $!";

    # Bump __version__ = "..."
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
}
elsif ( $target eq 'js' ) {
    my $npm_version;
    if ( $perl_version =~ /^(\d+)\.(\d+)\.(\d+)$/ ) {
        $npm_version = "$1.$2.$3";
    }
    elsif ( $perl_version =~ /^(\d+)\.(\d)(\d*)$/ ) {
        $npm_version = sprintf "%d.%d.%d", $1, $2, ( $3 || 0 );
    }
    else {
        die "cannot parse perl version: $perl_version\n";
    }

    chdir "$root/js" or die "chdir js: $!";

    run( qw( npm version ), $npm_version,
         qw( --no-git-tag-version --allow-same-version ) );
    run( qw( npm run build ) );
    run( qw( npm publish ) );
}
else {
    die "unknown target: $target (use python or js)\n";
}
