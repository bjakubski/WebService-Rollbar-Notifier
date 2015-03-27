
package WebService::Rollbar::Notifier;

use strict;
use warnings;

# VERSION

use Mojo::Base -base;
use Mojo::UserAgent;

my $API_URL = 'https://api.rollbar.com/api/1/';

has _ua => sub { Mojo::UserAgent->new; };
has callback => sub {
    ## Null by default, but not undef, because undef for callback
    ## means we want to block
};

has environment => 'production';
has [ qw/access_token  code_version/ ];

sub critical { my $self = shift; $self->notify( 'critical', @_ ); }
sub error    { my $self = shift; $self->notify( 'error',    @_ ); }
sub warning  { my $self = shift; $self->notify( 'warning',  @_ ); }
sub info     { my $self = shift; $self->notify( 'info',     @_ ); }
sub debug    { my $self = shift; $self->notify( 'debug',    @_ ); }

sub notify {
    my $self = shift;
    my ( $severity, $message, $custom ) = @_;

    my @optionals = (
        map +( defined $self->$_ ? ( $_ => $self->$_ ) : () ),
            qw/code_version/
    );

    my $response = $self->_ua->post(
        $API_URL . 'item/',
        json => {
            access_token => $self->access_token,
            data  => {
                environment => $self->environment,
                body => {
                    message => {
                        body => $message,
                        ( defined $custom ? ( %$custom ) : () ),
                    },
                },

                platform => $^O,
                title   => $message,
                timestamp   => time(),
                level   => $severity,

                @optionals,

                notifier => {
                    name => 'WebService::Rollbar::Notifier',
                    version => '1.1.1',
                },

                context => scalar(caller 1),
            },
        },

        ( $self->callback ? $self->callback : () ),
    );

    return $self->callback ? (1) : $response;
}


'
"Most of you are familiar with the virtues of a programmer.
 There are three, of course: laziness, impatience, and hubris."
                                                -- Larry Wall
';

__END__

=encoding utf8

=for stopwords Znet Zoffix subref www.rollbar.com.

=head1 NAME

WebService::Rollbar::Notifier - send messages to www.rollbar.com service

=head1 SYNOPSIS

=for pod_spiffy start code section

    use WebService::Rollbar::Notifier;

    my $roll = WebService::Rollbar::Notifier->new(
        access_token => 'YOUR_post_server_item_ACCESS_TOKEN',
    );

    $roll->debug("Testing example stuff!",
        # this is some optional, abitrary data we're sending
        { foo => 'bar',
            caller => scalar(caller()),
            meow => {
                mew => {
                    bars => [qw/1 2 3 4 5 /],
                },
        },
    });

=for pod_spiffy end code section

=head1 DESCRIPTION

This Perl module allows for blocking and non-blocking
way to send messages to L<www.rollbar.com|http://www.rollbar.com> service.

=head1 METHODS

=head2 C<< ->new() >>

=for pod_spiffy in key value | out object

    my $roll = WebService::Rollbar::Notifier->new(
        access_token => 'YOUR_post_server_item_ACCESS_TOKEN',

        # all these are optional; defaults shown:
        environment     => 'production',
        code_version    => undef,
        callback        => sub {},
    );

Creates and returns new C<WebService::Rollbar::Notifier> object.
Takes arguments as key/value pairs:

=head3 C<access_token>

=for pod_spiffy in scalar

    my $roll = WebService::Rollbar::Notifier->new(
        access_token => 'YOUR_post_server_item_ACCESS_TOKEN',
    );

B<Mandatory>. This is your C<post_server_item>
project access token.

=head3 C<environment>

=for pod_spiffy in scalar

    my $roll = WebService::Rollbar::Notifier->new(
        ...
        environment     => 'production',
    );

B<Optional>. Takes a string B<up to 255 characters long>. Specifies
the environment we're messaging from. B<Defaults to> C<production>.

=head3 C<code_version>

=for pod_spiffy in scalar

    my $roll = WebService::Rollbar::Notifier->new(
        ...
        code_version    => undef,
    );

B<Optional>. B<By default> is not specified.
Takes a string up to B<40 characters long>. Describes the version
of the application code. Rollbar understands these formats:
semantic version (e.g. C<2.1.12>), integer (e.g. C<45>),
git SHA (e.g. C<3da541559918a808c2402bba5012f6c60b27661c>).

=head3 C<callback>

=for pod_spiffy in subref

    # do nothing in the callback; this is default
    my $roll = WebService::Rollbar::Notifier->new(
        ...
        callback => sub {},
    );

    # perform a blocking call
    my $roll = WebService::Rollbar::Notifier->new(
        ...
        callback => undef,
    );

    # non-blocking; do something usefull in the callback
    my $roll = WebService::Rollbar::Notifier->new(
        ...
        callback => sub {
            my ( $ua, $tx ) = @_;
            say $tx->res->body;
        },
    );

B<Optional>. B<Takes> C<undef> or a subref as a value.
B<Defaults to> a null subref. If set to C<undef>, notifications to
L<www.rollbar.com|http://www.rollbar.com> will be
blocking, otherwise non-blocking, with
the C<callback> subref called after a request completes. The subref
will receive in its C<@_> the L<Mojo::UserAgent> object that
performed the call and L<Mojo::Transaction::HTTP> object with the
response.

=head2 C<< ->notify() >>

    $roll->notify('debug', "Message to send", {
        any      => 'custom',
        optional => 'data',
        to       => [qw/send goes here/],
    });

    # if we're doing blocking calls, then return value will be
    # the response JSON

    use JSON::MaybeXS;
    $roll->callback(undef);
    my $response = $roll->notify('debug', "Message to send");
    say decode_json( $response->res->body );

Takes two mandatory and one optional arguments. Always returns
true value if we're making non-blocking calls (see
C<callback> argument to constructor). Otherwise, returns the response
as L<Mojo::Transaction::HTTP> object. The arguments are:

=head3 First argument

=for pod_spiffy in scalar

    $roll->notify('debug', ...

B<Mandatory>. Specifies the type of message to send. Valid values
are C<critical>, C<error>, C<warning>, C<info>, and C<debug>.
The module provides shorthand methods with those names to call
C<notify>.

=head3 Second argument

=for pod_spiffy in scalar

    $roll->notify(..., "Message to send",

B<Mandatory>. Takes a string
that specifies the message to send to L<www.rollbar.com|http://www.rollbar.com>.

=head3 Third argument

=for pod_spiffy in hashref

    $roll->notify(
        ...,
        ..., {
        any      => 'custom',
        optional => 'data',
        to       => [qw/send goes here/],
    });

B<Optional>. Takes a hashref that will be converted to JSON and
sent along with the notification's message.

=head2 C<< ->critical() >>

=for pod_spiffy in scalar scalar optional

    $roll->critical( ... );

    # same as

    $roll->notify( 'critical', ... );

=head2 C<< ->error() >>

=for pod_spiffy in scalar scalar optional

    $roll->error( ... );

    # same as

    $roll->notify( 'error', ... );

=head2 C<< ->warning() >>

=for pod_spiffy in scalar scalar optional

    $roll->warning( ... );

    # same as

    $roll->notify( 'warning', ... );

=head2 C<< ->info() >>

=for pod_spiffy in scalar scalar optional

    $roll->info( ... );

    # same as

    $roll->notify( 'info', ... );

=head2 C<< ->debug() >>

=for pod_spiffy in scalar scalar optional

    $roll->debug( ... );

    # same as

    $roll->notify( 'debug', ... );

=head1 ACCESSORS/MODIFIERS

=head2 C<< ->access_token() >>

=for pod_spiffy in scalar optional | out scalar

    say 'Access token is ' . $roll->access_token;
    $roll->access_token('YOUR_post_server_item_ACCESS_TOKEN');

Getter/setter for C<access_token> argument to C<< ->new() >>.

=head2 C<< ->code_version() >>

=for pod_spiffy in scalar optional | out scalar

    say 'Code version is ' . $roll->code_version;
    $roll->code_version('1.42');

Getter/setter for C<code_version> argument to C<< ->new() >>.

=head2 C<< ->environment() >>

=for pod_spiffy in scalar optional | out scalar

    say 'Current environment is ' . $roll->environment;
    $roll->environment('1.42');

Getter/setter for C<environment> argument to C<< ->new() >>.

=head2 C<< ->callback() >>

=for pod_spiffy in subref | out subref

    $roll->callback->(); # call current callback
    $roll->callback( sub { say "Foo!"; } );

Getter/setter for C<callback> argument to C<< ->new() >>.

=head1 SEE ALSO

Rollbar API docs: L<https://rollbar.com/docs/api/items_post/>

=for pod_spiffy hr

=head1 REPOSITORY

=for pod_spiffy start github section

Fork this module on GitHub:
L<https://github.com/zoffixznet/WebService-Rollbar-Notifier>

=for pod_spiffy end github section

=head1 BUGS

=for pod_spiffy start bugs section

To report bugs or request features, please use
L<https://github.com/zoffixznet/WebService-Rollbar-Notifier/issues>

If you can't access GitHub, you can email your request
to C<bug-webservice-rollbar-notifier at rt.cpan.org>

=for pod_spiffy end bugs section

=head1 AUTHOR

=for pod_spiffy start author section

=for pod_spiffy author ZOFFIX

=for text Zoffix Znet <zoffix at cpan.org>

=for pod_spiffy end author section

=head1 LICENSE

You can use and distribute this module under the same terms as Perl itself.
See the C<LICENSE> file included in this distribution for complete
details.

=cut
