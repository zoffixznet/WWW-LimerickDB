package WWW::LimerickDB;

use warnings;
use strict;

our $VERSION = '0.0305';

use LWP::UserAgent;
use HTML::TokeParser::Simple;
use HTML::Entities;
use overload q|""| => sub { shift->limerick->{text} };

use base 'Class::Data::Accessor';
__PACKAGE__->mk_classaccessors qw/
    error
    ua
    limericks
    limerick
    new_line
/;

sub new {
    my ( $class, %args ) = @_;

    $args{ +lc } = delete $args{ $_ }
        for keys %args;

    $args{ua} ||= LWP::UserAgent->new(
        agent   => 'Mozilla',
        timeout => 30,
    );

    unless ( defined $args{new_line} ) {
        $args{new_line} = "\n";
    }

    my $self = bless {}, $class;

    $self->$_( $args{ $_ } )
        for keys %args;

    return $self;
}

sub get_top    { shift->_get('top150'); }
sub get_bottom { shift->_get('bottom'); }
sub get_latest { shift->_get('latest'); }
sub get_random { shift->_get('random'); }
sub get_high_random { shift->_get('random2'); }

sub get_limerick {
    my ( $self, $num ) = @_;
    my $limerick = $self->_get($num);
    ref $limerick
        or return;

    return $limerick->[0];
}

sub get_cached {
    my ( $self, $method, $reset ) = @_;
    $reset ||= 0;
    unless ( $method =~ /top|bottom|latest|random|high_random/ ) {
        return $self->_set_error('Method must be either top|bottom|latest|random|high_random');
    }
    if ( @{ $self->limericks || [] } < $reset or not @{ $self->limericks || [] } ) {
        my $error_count = 0;
        REDO_ON_ERROR: {
            if ( $error_count > 2 ) {
                return $self->_set_error(q|Can't fetch, last error: | . $self->error);
            }

            $self->${\"get_$method"}
                or $error_count++
                and redo;
        }
    }
    my $ret = shift @{ $self->limericks };
    $self->limerick( $self->limericks->[0] );
    return $ret;
}

sub _get {
    my ( $self, $what ) = @_;

    $self->$_( undef )
        for qw/limericks limerick error/;

    my $response = $self->ua->get("http://limerickdb.com/?$what");

    $response->is_success
        or return $self->_set_error( $response );

    return $self->_parse_quotes( $response->decoded_content );
}

sub _parse_quotes {
    my ( $self, $html ) = @_;

    my $p = HTML::TokeParser::Simple->new( \ $html );
    my @quotes;
    my $cur_quote = { text => '' };
    my %nav;
    @nav{ qw/get_quote_text  get_rating/ } = (0, 0);
    while ( my $t = $p->get_token ) {
        if ( $t->is_start_tag('a')
            and defined $t->get_attr('href')
            and my ( $number ) = $t->get_attr('href') =~ /^\?(\d+)$/
        ) {
            $cur_quote->{number} = $number;
        }
        elsif ( $t->is_start_tag('a')
            and defined $t->get_attr('href')
            and $t->get_attr('href') =~ /^\?ratingplus/
        ) {
            $nav{get_rating} = 1;
        }
        elsif ( $nav{get_rating} == 1 and $t->is_end_tag('a') ) {
            $nav{get_rating} = 2;
        }
        elsif ( $nav{get_rating} == 2 and $t->is_text ) {
            $cur_quote->{rating} = $t->as_is;
            $cur_quote->{rating} =~ s/[^\d-]+//g;
            $nav{get_rating} = 0;
        }
        elsif ( $t->is_start_tag('div')
            and defined $t->get_attr('class')
            and $t->get_attr('class') eq 'quote_output'
        ) {
            $nav{get_quote_text} = 1;
        }
        elsif ( $nav{get_quote_text} and $t->is_text ) {
            $cur_quote->{text} .= $t->as_is;
        }
        elsif ( $nav{get_quote_text} and $t->is_end_tag('div') ) {
            decode_entities $cur_quote->{text};
            for ( $cur_quote->{text} ) {
                s/\240/ /g;
                s/[^\S\n]+/ /g;
                s/^\s+//;
                s/\s+$//;
                my $nl = $self->new_line;
                s/\n/$nl/g;
            }
            push @quotes, $cur_quote;
            $nav{get_quote_text} = 0;
            $cur_quote = { text => '' };
        }
    }

    $self->limerick( $quotes[0] );
    return $self->limericks( [ @quotes ] );
}


sub _set_error {
    my ( $self, $response ) = @_;
    if ( ref $response ) {
        $self->error( "Network error: " . $response->status_line );
    }
    else {
        $self->error( $response );
    }
    return;
}

1;
__END__

=head1 NAME

WWW::LimerickDB - interface to fetch limericks from http://limerickdb.com/

=head1 SYNOPSIS

    use strict;
    use warnings;
    use WWW::LimerickDB;

    my $lime = WWW::LimerickDB->new;

    $lime->get_limerick(228)
        or die $lime->error;

    print "$lime\n";

=head1 DESCRIPTION

The module provides interface to fetch limericks ("quotes" if you prefer) from
L<http://limerickdb.com/>

=head1 CONSTRUCTOR

=head2 C<new>

    my $lime = WWW::LimerickDB->new;

    my $lime = WWW::LimerickDB->new(
        ua       => LWP::UserAgent->new( agent => 'Fox', timeout => 50 ),
        new_line => '/',
    );

Constructs and returns a freshly cooked C<WWW::LimerickDB> object. Takes two optional arguments
in a key/value fashion.

=head3 C<ua>

    my $lime = WWW::LimerickDB->new(
        ua => LWP::UserAgent->new( agent => 'Fox', timeout => 50 ),
    );

B<Optional>. Takes an L<LWP::UserAgent>-like object as a value, in other words an object with
a C<get()> method that returns L<HTTP::Response> object. B<By default>, the following will be
used: C<< LWP::UserAgent->new( agent => 'Mozilla', timeout => 30 ) >>

=head3 C<new_line>

    my $lime = WWW::LimerickDB->new(
        new_line => '/',
    );

B<Optional>. Takes a string as a value. All "new line" (C<\n>) characters in fetched
limericks will be replaced by this character. B<Defaults to:> C<\n> (no replacing of new lines)

=head1 FETCHING METHODS

All of fetching methods return either C<undef> or an empty list on failure and
the reason for failure will be available via C<error> method (see below).

=head2 LIMERICK HASHREF

    {
        'number' => '5',
        'text' => 'There is something about satyriasis
                    That arouses psychiatrists\' biases.
                    But we\'re both very pleased
                    we\'re this way diseased,
                    as the damsel who\'s waiting to try us is.',
        'rating' => '-12'
    }

All of the fetching method return either one of these hashrefs or an arrayref filled with
them. The keys/values of these hashrefs are as follows:

=head3 C<number>

    'number' => '5',

Contains the number of the limerick on the site. This can also be used to construct the
URI pointing to the limerick on the site, i.e. L<http://limerickdb.com/?5>

=head3 C<rating>

    'rating' => '-12'

Contains the rating of the limerick, this will match C</[\d-]+/>.

=head3 C<text>

    'text' => 'There is something about satyriasis
            That arouses psychiatrists\' biases. 
            But we\'re both very pleased 
            we\'re this way diseased, 
            as the damsel who\'s waiting to try us is.',

Contains the actual text of the limerick.

=head2 C<get_limerick>

    my $limerick = $lime->get_limerick(288)
        or die $lime->error;

Takes one mandatory argument which is the number of the limerick you wish to retrieve.
On success returns a "limerick hashref" described above.

=head2 C<get_top>

    my $top_limericks_ref = $lime->get_top
        or die $lime->error;

Takes no arguments. On success returns an arrayref of "limerick hashrefs" that represent
"Top" rated limericks.

=head2 C<get_bottom>

    my $lime_limericks_ref = $lime->get_bottom
        or die $lime->error;

Takes no arguments. On success returns an arrayref of "limerick hashrefs" that represent
"Bottom" rated limericks.

=head2 C<get_latest>

    my $latest_limericks_ref = $lime->get_latest
        or die $lime->error;

Takes no arguments. On success returns an arrayref of "limerick hashrefs" that represent
"Latest" limericks.

=head2 C<get_random>

    my $random_limericks_ref = $lime->get_random
        or die $lime->error;

Takes no arguments. On success returns an arrayref of "limerick hashrefs" that represent
"Random" limericks.

=head2 C<get_high_random>

    my $random_high_limericks_ref = $lime->get_high_random
        or die $lime->error;

Takes no arguments. On success returns an arrayref of "limerick hashrefs" that represent
"Random > 0" (i.e. random with
no negative ratings) limericks.

=head2 C<get_cached>

    my $limerick = $lime->get_cached( 'random', 10 );

    for ( 1 .. 1000 ) {
        print $lime->get_cached('random');
    }

Takes one mandatory and one optional arguments. The first argument is a string that must
be one of the following:

    top
    bottom
    latest
    random
    high_random

Each of those corresponds to one of the "fetching methods", i.e. C<top> corresponds to
C<get_top()>. The second (optional) argument takes an integer value. If the
number of available limericks is less than the value specified then C<get_cached()> will
fetch some fresh limericks... read along to
understand. The C<get_cached()> method fetches the limericks using the method you specified
as the first argument. That call fills in an arrayref of limerick hashrefs (avalaible via
C<limericks()> call described below). When that arrayref gets empty, C<get_cached()>
does a new fetch automatically. When the second optional argument is provided, C<get_cached()>
will refill that arrayref if it contains less than the specified number
and make a call for a new fetch. You can also "reset" by
giving an empty arrayref to C<limericks()> method. In other words, these two are the
same:

    print $lime->get_cached('random', 100000)->{text} . "\n";
    for ( 1..1000 ) {
        print $lime->get_cached('random')->{text};
    }

    # SAME AS

    $lime->limericks( [] );
    for ( 1..1001 ) {
        print $lime->get_cached('random')->{text};
    }

Calls to C<get_cached()> also adjust the return value of C<limerick()> method (see below) so
it points to the next limerick to be returned by C<get_cached()> providing there
is enough limericks still available.

If you never called any of the "fetching methods" before calling C<get_cached()> you do NOT
need to reset anything, in fact, you do not have to reset anything at all if you do not
wish to do so. The only reason for resetting is to fetch new limericks and avoid use of
whatever is there already available via C<limericks()> method.

If a network error occurs during the "refreshing" of limericks by C<get_cached()> it will
retry 2 more times, if all attempts fail it will return either C<undef> or an empty list
with the last error available via C<error()> method.

=head1 OTHER METHODS

=head2 C<error>

    my $limerick = $lime->get_limerick(288)
        or die $lime->error;

If either of the "FETCHING METHODS" described above fail they return either C<undef>
or an empty list, depending on the context, and the reason for failure will be available
via C<error> method. Takes no arguments, return a human parsable string explaining why
a fetching method failed.

=head2 C<limerick>

    my $limerick = $lime->limerick->{text};

    # OR

    my $limerick = "$lime";

Note the B<singular> form. Takes no arguments.
Must be called after a successful call to one of the "FETCHING
METHODS". If the "fetching method" is a C<get_limerick()> returns the same limerick that
call returned; otherwise, returns the first quote out of quotes retrieved. B<This method
is overloaded> on C<q|""|> and returns the value of C<{text}> key in "limerick hashref",
in other words, you can interpolate the object in a string to obtain the value of the call to
C<limerick()->{text}>.

=head2 C<limericks>

    my $limericks_ref = $lime->limericks;

    $lime->limericks( [] );

Note the B<plural> form. When called with an B<optional> argument assigns that value as
a list of limericks, generally you'd only want to do that when using C<get_cached()> method.
Without an argument must be called after a successful call to one of the "FETCHING
METHODS" or after assigning something meaningingful.
Returns the same arrayref as all but C<get_limerick()> fetching methods returned. In
case of method being C<get_limerick()> returns an arrayref with just one quote that was
fetched.

=head2 C<new_line>

    my $old_new_line_char = $lime->new_line;
    $lime->new_line('/');

Returns the currently used "new line" character. When called with an argument sets that
argument as a new line character used by the module. See C<new_line> argument to
constructor for more details.

=head2 C<ua>

    my $ua = $lime->ua;
    $ua->proxy('http', 'http://foo.com');
    $lime->ua( $ua );

Returns the object currently used for fetching quotes. When called with one optional
argument sets a new object that is the argument. See C<ua> argument to the constructor
for more details.

=head1 AUTHOR

'Zoffix, C<< <'zoffix at cpan.org'> >>
(L<http://zoffix.com/>, L<http://haslayout.net/>, L<http://zofdesign.com/>)

=head1 BUGS

Please report any bugs or feature requests to C<bug-www-limerickdb at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-LimerickDB>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::LimerickDB

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=WWW-LimerickDB>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/WWW-LimerickDB>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/WWW-LimerickDB>

=item * Search CPAN

L<http://search.cpan.org/dist/WWW-LimerickDB>

=back

=head1 COPYRIGHT & LICENSE

Copyright 2008 'Zoffix, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

