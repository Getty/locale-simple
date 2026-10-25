use strict;
use warnings;

package Locale::Simple::Scraper::Parser;
our $VERSION = '0.110';
# ABSTRACT: parser to finds translation tokens in a code file

use base qw( Parser::MGC );

use Moo;
use Try::Tiny;
use curry;

has func_qr => ( is => 'ro', default => sub { qr/\b(?:l(?:|n|p|np|d|dp|dn|dnp)\b|N(?:|n|p|np|d|dp|dn|dnp)_)/ } );
has found   => ( is => 'ro', default => sub { [] } );
has type => ( is => 'ro', required => 1 );

with "Locale::Simple::Scraper::ParserShortcuts";

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

sub call {
    my ( $self ) = @_;

    my $func = $self->expect( $self->func_qr );
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

    my @types = ( $self->curry::call, $self->curry::dynamic_string, $self->curry::token_int, $self->curry::variable );
    my $extra_args = $self->list_of( ",", $self->c_any_of( @types ) );
    return @{$extra_args};
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
sub plural_count { shift->named_token( "count of plural entity", "token_int" ) }
sub context_id   { shift->named_token( "context id" ) }
sub domain_id    { shift->named_token( "domain id" ) }
sub comma        { shift->op( "," ) }
sub variable     { shift->expect( qr/[\w\.]+/ ) }

sub constant_string {
    my ( $self, @components ) = @_;

    unshift @components, $self->literal_scopes;

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
    my %ops = ( js => "+", pl => ".", tx => qr/(_|~)/, py => "+" );
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
    );
    return @{ $forms{ shift->type } };
}

sub literal_scopes {
    my ( $self ) = @_;
    return map {
        ref $_
          ? $self->curry::scope_of( $_->[0], $self->c_with_ws( $_->[1] ), $_->[2] )
          : $self->c_with_ws( $_ )
    } $self->literal_forms;
}

sub dynamic_string {
    my ( $self ) = @_;
    return $self->constant_string( $self->curry::call, $self->curry::variable );
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

sub string_contents {
    my ( $self, @contents ) = @_;
    my $elements = $self->sequence_of( $self->c_any_of( @contents ) );
    return join "", @{$elements} if @{$elements};
    $self->fail( "no string contents found" );
}

1;
