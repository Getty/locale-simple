use strict;
use warnings;

package Locale::Simple::Scraper::Parser;
our $VERSION = '0.200';
# ABSTRACT: parser to finds translation tokens in a code file

use base qw( Parser::MGC );

use Moo;
use Try::Tiny;
use curry;

has func_qr => ( is => 'ro', lazy => 1, default => sub { shift->default_func_qr } );
has found  => ( is => 'ro', default => sub { [] } );
has type => ( is => 'ro', required => 1 );

with "Locale::Simple::Scraper::ParserShortcuts";

# The helper names are exported from a Go package, so they start with an
# upper case letter there. A package prefix before the dot needs no pattern of
# its own: the word boundary already matches after the dot.
sub default_func_qr {
    my ( $self ) = @_;
    return qr/\b(?:L(?:|n|p|np|d|dp|dn|dnp)\b|N(?:|n|p|np|d|dp|dn|dnp)_)/ if $self->type eq "go";

    # Rust has macros: a bang follows the name, and the deferred markers are
    # lower case there. The path before a macro needs no pattern either.
    return qr/\b(?:l(?:|n|p|np|d|dp|dn|dnp)!|n(?:|n|p|np|d|dp|dn|dnp)_!)/ if $self->type eq "rs";
    return qr/\b(?:l(?:|n|p|np|d|dp|dn|dnp)\b|N(?:|n|p|np|d|dp|dn|dnp)_)/;
}

# Maps a name as written in the source to the one the argument tables use.
sub canonical_func {
    my ( $self, $func ) = @_;
    $func =~ s/^L/l/ if $self->type eq "go";
    if ( $self->type eq "rs" ) {
        $func =~ s/!$//;
        $func = ucfirst $func if $func =~ /_$/;
    }
    return $func;
}

sub parse {
    my ( $self ) = @_;
    $self->sequence_of( $self->c_any_of( $self->curry::noise, $self->curry::call ) );
    return $self->found;
}

sub noise {
    my ( $self ) = @_;
    my $noise = $self->substring_before( $self->func_qr );
    $self->fail( "no noise found" ) if !length $noise;
    $self->debug( "discarded %d characters of noise", length $noise );
    return $noise;
}

# A call whose arguments do not parse is reported and skipped; reading goes
# on where they failed, at the top level and inside another call's argument
# alike. Nothing is read twice, so nothing is recorded twice.
sub call {
    my ( $self ) = @_;

    my $func = $self->canonical_func( $self->expect( $self->func_qr ) );
    my $line = ( $self->where )[0];
    $self->debug( "found func $func at line %d", $line );

    try {
        my $arguments = $self->arguments( $func );
        push @{ $self->found }, { func => $func, args => $arguments, line => $line };
    }
    catch {
        die $_ if !eval { $_->isa( "Parser::MGC::Failure" ) };
        $self->warn_failure( $_ );
    };

    return;
}

sub arguments {
    my ( $self, $func ) = @_;

    my @arguments = ( $self->op( "(" ), $self->required_args( $func ), $self->extra_arguments, $self->op( ")" ) );
    $self->debug( "found %d arguments", scalar @arguments );

    return \@arguments;
}

sub op {
    my ( $self, $op ) = @_;
    return if $self->with_ws( maybe_expect => qr/\s*\Q$op\E/ );
    $self->fail( "Expected \"$op\"" );
}

sub extra_arguments {
    my ( $self ) = @_;
    return if !$self->maybe_expect( "," );

    my $extra_args = $self->list_of( ",", sub { $self->argument( "argument" ) } );
    return @{$extra_args};
}

# An argument the catalogue does not need, the count or one after it: any
# code up to the comma or closing bracket that ends it. Returns its source
# text, or nothing when it is a translation call alone, as that call is
# recorded on its own.
sub argument {
    my ( $self, $name ) = @_;
    $self->skip_ws;
    my $start = $self->pos;
    my $parts = $self->sequence_of( $self->c_any_of( $self->code_parts ) );
    $self->fail( "Expected $name" ) if $self->pos == $start;
    return if !@{$parts};
    return substr $self->{str}, $start, $self->pos - $start;
}

# The pieces such code is made of. Translation calls in it are recorded.
# String literals and bracket pairs are read as a whole, so a comma or a
# bracket inside them does not end the argument.
sub code_parts {
    my ( $self ) = @_;
    return (
        $self->curry::call,
        $self->skipped_literals,
        $self->curry::bracketed,
        $self->c_expect( qr/\w+|[^\w\s,()\[\]{}]/ ),
    );
}

# A bracket pair with what it holds, commas included. A pair left open (in
# broken code, or opened inside a literal form the scraper does not know)
# ends where its contents do. It never fails once opened, so what is read
# inside it is never read again.
sub bracketed {
    my ( $self ) = @_;
    my $open = $self->expect( qr/[(\[{]/ );
    ( my $close = $open ) =~ tr/([{/)]}/;
    $self->sequence_of( $self->c_any_of( $self->code_parts, $self->c_expect( "," ) ) );
    $self->maybe_expect( $close );
    return $open;
}

# The language's string literals as they appear in skipped code. The quoted
# forms are read leniently, any escape and empty included, as their text is
# not kept; the others are read as for a msgid.
sub skipped_literals {
    my ( $self ) = @_;
    my @literals = map {
        ref $_ && $_->[0] =~ /^["']\z/
          ? $self->c_expect( $self->quoted_qr( $_->[0] ) )
          : $self->literal_scope( $_ )
    } $self->literal_forms;
    return @literals, map { $self->c_expect( $_ ) } $self->code_only_literals;
}

sub quoted_qr {
    my ( $self, $quote ) = @_;
    my $q = quotemeta $quote;
    return qr/$q(?:[^\\$q]|\\.)*$q/s;
}

# Literals that never hold a msgid but must not be read as code: JavaScript
# template literals, Go runes and Rust chars (one character or one escape; a
# Rust lifetime has no closing quote and stays code).
sub code_only_literals {
    my $char = qr/'(?:\\.[^'\\\n]*|[^'\\\n])'/;
    my %literals = ( js => [qr/`(?:[^`\\]|\\.)*`/s], go => [$char], rs => [$char] );
    return @{ $literals{ shift->type } || [] };
}

sub required_args {
    my ( $self, $func ) = @_;
    my %arg_lists = (
        l     => [qw( tr_token )],
        ln    => [qw( tr_token    comma  plural_token  comma  plural_count )],
        lp    => [qw( context_id  comma  tr_token )],
        lnp   => [qw( context_id  comma  tr_token      comma  plural_token  comma  plural_count )],
        ld    => [qw( domain_id   comma  tr_token )],
        ldn   => [qw( domain_id   comma  tr_token      comma  plural_token  comma  plural_count )],
        ldp   => [qw( domain_id   comma  context_id    comma  tr_token )],
        ldnp  => [qw( domain_id   comma  context_id    comma  tr_token      comma  plural_token  comma  plural_count )],

        # Deferred-translation markers — runtime no-ops, scraper treats
        # them identically to their l* twins.
        N_    => [qw( tr_token )],
        Nn_   => [qw( tr_token    comma  plural_token )],
        Np_   => [qw( context_id  comma  tr_token )],
        Nnp_  => [qw( context_id  comma  tr_token      comma  plural_token )],
        Nd_   => [qw( domain_id   comma  tr_token )],
        Ndn_  => [qw( domain_id   comma  tr_token      comma  plural_token )],
        Ndp_  => [qw( domain_id   comma  context_id    comma  tr_token )],
        Ndnp_ => [qw( domain_id   comma  context_id    comma  tr_token      comma  plural_token )],
    );
    return $self->collect_from( $arg_lists{$func} );
}

sub tr_token     { shift->named_token( "translation token" ) }
sub plural_token { shift->named_token( "plural translation token" ) }
sub plural_count { shift->argument( "count of plural entity" ) }
sub context_id   { shift->named_token( "context id" ) }
sub domain_id    { shift->named_token( "domain id" ) }
sub comma        { shift->op( "," ) }

sub constant_string {
    my ( $self ) = @_;

    my @components = $self->literal_scopes;

    my $string;
    if ( defined $self->concat_op ) {
        $string = $self->list_of( $self->concat_op, $self->c_any_of( @components ) );
    }
    else {
        # No concatenation operator: a string argument is a single literal.
        my $single = $self->maybe( sub { $self->any_of( @components ) } );
        $string = defined $single ? [$single] : [];
    }

    return join "", map { $_ ? $_ : "" } @{$string} if @{$string};

    $self->fail;
}

# undef means the language has no concatenation operator.
sub concat_op {
    my %ops = ( js => "+", pl => ".", tx => qr/(_|~)/, py => "+", php => ".", go => "+", rs => undef );
    return $ops{ shift->type };
}

# String literal forms per language type. An entry is either
# [ open, content method, close ] or the name of a method that parses a whole
# literal by itself (for forms whose terminator depends on the opening).
sub literal_forms {
    my $dq  = [ q["], "double_quote_string_contents", q["] ];
    my $sq  = [ q['], "single_quote_string_contents", q['] ];
    my %forms = (
        js => [ $dq, $sq ],
        pl => [ $dq, $sq ],
        py => [ $dq, $sq ],
        tx => [ $dq, $sq ],
        # No single quotes: in Go they delimit a rune, not a string.
        go  => [ $dq, [ q[`], "go_backtick_string_contents", q[`] ] ],
        # No single quotes either (chars and lifetimes), and no concatenation.
        rs  => [ $dq, "rust_raw_string" ],
        php => [ [ q["], "php_double_quote_string_contents", q["] ], $sq, "php_heredoc_or_nowdoc" ],
    );
    return @{ $forms{ shift->type } };
}

sub literal_scopes {
    my ( $self ) = @_;
    return map { $self->literal_scope( $_ ) } $self->literal_forms;
}

sub literal_scope {
    my ( $self, $form ) = @_;
    return ref $form
      ? $self->curry::scope_of( $form->[0], $self->c_with_ws( $form->[1] ), $form->[2] )
      : $self->c_with_ws( $form );
}

sub double_quote_string_contents {
    my ( $self ) = @_;
    return $self->string_contents( $self->c_expect( qr/[^\\"]+/ ), $self->c_expect_escaped( q["] ) );
}

sub single_quote_string_contents {
    my ( $self ) = @_;
    return $self->string_contents(
        $self->c_expect( qr/[^\\']+/ ),
        $self->c_expect_escaped( q['] ),
        $self->c_expect_escaped( q[\\] ),
        $self->c_expect( qr/\\/ ),
    );
}

# PHP double quotes also escape the dollar sign; any other backslash is kept
# as it is. Interpolated variables stay part of the text.
sub php_double_quote_string_contents {
    my ( $self ) = @_;
    return $self->string_contents(
        $self->c_expect( qr/[^\\"]+/ ),
        $self->c_expect_escaped( q["] ),
        $self->c_expect_escaped( q[$] ),
        $self->c_expect_escaped( q[\\] ),
        $self->c_expect( qr/\\/ ),
    );
}

# Heredoc and nowdoc: the closing identifier is the one that was opened, so
# the whole literal is parsed here. Contents are taken verbatim.
sub php_heredoc_or_nowdoc {
    my ( $self ) = @_;
    my @open = $self->expect( qr/<<<[ \t]*(?:'(\w+)'|"(\w+)"|(\w+))[ \t]*\r?\n/ );
    shift @open;    # the whole match comes first, then the captures
    my ( $id ) = grep { defined } @open;
    my $close = qr/\r?\n[ \t]*\Q$id\E\b/;
    my $text = $self->raw_string_contents( $close );
    $self->expect( $close );
    return $text;
}

# A raw string ends at a quote followed by as many hashes as it was opened
# with, so it is parsed as a whole.
sub rust_raw_string {
    my ( $self ) = @_;
    my ( undef, $hashes ) = $self->expect( qr/r(#*)"/ );
    my $close = qr/"\Q$hashes\E/;
    my $text = $self->raw_string_contents( $close );
    $self->expect( $close );
    return $text;
}

sub go_backtick_string_contents { shift->raw_string_contents( q[`] ) }

# Contents up to the given terminator pattern, no escapes (PHP heredoc and
# nowdoc, Go backticks).
sub raw_string_contents {
    my ( $self, $stop ) = @_;
    my $text = $self->substring_before( $stop );
    $self->fail( "no string contents found" ) if !length $text;
    return $text;
}

sub string_contents {
    my ( $self, @contents ) = @_;
    my $elements = $self->sequence_of( $self->c_any_of( @contents ) );
    return join "", @{$elements} if @{$elements};
    $self->fail( "no string contents found" );
}

1;
