use strict;
use warnings;

package EBox::Samba::AuthKrbHelper;

use EBox;
use EBox::Sudo;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::Internal;

use Authen::Krb5::Easy qw(kinit kinit_pwd klist kdestroy kerror);

sub new
{
    my ($class, %params) = @_;

    unless ($params{principal}) {
        throw EBox::Exceptions::MissingArgument('principal');
    }
    unless ($params{realm}) {
        throw EBox::Exceptions::MissingArgument('realm');
    }

    my ($targetPrincipal, $targetRealm) = split(/@/, $params{principal});
    if (length $targetRealm and $targetRealm ne $params{realm}) {
        my $error = "The specified principal realm ($targetRealm) does not match specified realm ($params{realm})";
        throw EBox::Exceptions::MissingArgument($error);
    }

    # Set the ticket cache path
    my $ccache = EBox::Config::tmp() . 'samba.ccache';
    $ENV{KRB5CCNAME} = $ccache;

    my $self = {};
    $self->{principal} = $targetPrincipal;
    $self->{realm} = $params{realm};
    $self->{password} = $params{password};
    $self->{keytab} = EBox::Config::conf() . 'samba.keytab';
    bless ($self, $class);

    if ($self->{password}) {
        $self->_getTicketUsingPassword($self->{principal}, $self->{realm}, $self->{password});
    } else {
        $self->_getTicketUsingKeytab($self->{principal}, $self->{realm}, $self->{keytab});
    }

    return $self;
}

sub destroy
{
    my ($self) = @_;

    kdestroy();
}

sub _getTicketUsingKeytab
{
    my ($self, $principal, $realm, $keytab, $retry) = @_;

    unless (defined $principal and length $principal) {
        throw EBox::Exceptions::MissingArgument('principal');
    }

    unless (defined $keytab and length $keytab) {
        throw EBox::Exceptions::MissingArgument('keytab');
    }

    unless (defined $realm and length $realm) {
        throw EBox::Exceptions::MissingArgument('realm');
    }

    unless (defined $retry) {
        $retry = 1;
    }

    # If we already have a ticket and it is not expired, return
    if ($self->checkTicket($principal, $realm)) {
        return;
    }

    # If the keytab does not exists, extract it
    unless (EBox::Sudo::fileTest('-f', $keytab)) {
        $self->_extractKeytab($principal, $realm, $keytab);
        $retry = 0;
    }

    # Try to get ticket
    if (kinit($keytab, "$principal\@$realm") == 1) {
        return;
    } elsif ($retry) {
        # Something was wrong, maybe the password has changed and the keytab
        # is outdated. Try again extracting the again.
        $self->_getTicketUsingKeytab($principal, $realm, $keytab, 0);
        return;
    }

    my $error = kerror();
    throw EBox::Exceptions::Internal("Could not get ticket: $error")
}

sub _getTicketUsingPassword
{
    my ($self, $principal, $realm, $password) = @_;

    unless (defined $principal and length $principal) {
        throw EBox::Exceptions::MissingArgument('principal');
    }

    unless (defined $password and length $password) {
        throw EBox::Exceptions::MissingArgument('password');
    }

    unless (defined $realm and length $realm) {
        throw EBox::Exceptions::MissingArgument('realm');
    }

    # If we already have a ticket and it is not expired, return
    if ($self->checkTicket($principal, $realm)) {
        return;
    }

    # Try to get ticket
    if (kinit_pwd("$principal\@$realm", $password) == 1) {
        return;
    }

    my $error = kerror();
    throw EBox::Exceptions::Internal("Could not get ticket: $error")
}

sub _extractKeytab
{
    my ($self, $principal, $realm, $keytab) = @_;

    unless (defined $principal and length $principal) {
        throw EBox::Exceptions::MissingArgument('principal');
    }

    unless (defined $keytab and length $keytab) {
        throw EBox::Exceptions::MissingArgument('keytab');
    }

    unless (defined $realm and length $realm) {
        throw EBox::Exceptions::MissingArgument('realm');
    }

    my $ownerUser = EBox::Config::user();
    my $ownerGroup = EBox::Config::group();

    my @cmds;
    push (@cmds, "samba-tool domain exportkeytab '$keytab' --principal='$principal\@$realm'");
    push (@cmds, "chown '$ownerUser:$ownerGroup' '$keytab'");
    push (@cmds, "chmod 400 '$keytab'");
    EBox::Sudo::root(@cmds);
}

# Method: checkTicket
#
#   Return 1 if we have a valid ticket for the principal, 0 otherwise
#
sub checkTicket
{
    my ($self, $principal, $realm) = @_;

    unless (defined $principal and length $principal) {
        throw EBox::Exceptions::MissingArgument('principal');
    }

    unless (defined $realm and length $realm) {
        throw EBox::Exceptions::MissingArgument('realm');
    }

    my $creds = klist();
    foreach my $ticket (@{$creds}) {
        my ($ticketPrincipal, $ticketRealm) = split(/@/, $ticket->{client}, 2);
        if ($ticketPrincipal eq $principal and
            $ticketRealm eq $realm and
            not $ticket->{expired}) {
            return 1;
        }
    }

    return 0;
}

1;
