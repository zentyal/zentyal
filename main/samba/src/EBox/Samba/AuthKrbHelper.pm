use strict;
use warnings;

package EBox::Samba::AuthKrbHelper;

use EBox;
use EBox::Global;
use EBox::Sudo;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::Internal;

use Authen::Krb5::Easy qw(kinit kinit_pwd klist kdestroy kerror);

my $singleton;

# Method: new
#
#   Instance a new helper, getting the ticket for the specified principal.
#   The principal can be specified by name and optional realm, or with
#   and object SID.
#
# Parameters:
#
#   principal - The name of the principal
#   SID - The SID of the principal to get the ticket for
#   RID - The relative domain ID of the principal to get the ticket for
#   realm (optional) - The realm the principal belong to
#
sub new
{
    my ($class, %params) = @_;

    if (defined $singleton) {
        # Check ticket is still valid
        my $princ = $singleton->principal();
        my $realm = $singleton->realm();
        if ($singleton->checkTicket($princ, $realm)) {
            return $singleton;
        }
        # If ticket not valid or cache has been deleted, return new instance
        $singleton->destroy();
        $singleton = undef;
    }

    my $principal = undef;
    my $realm = undef;
    if ($params{SID}) {
        my $users = EBox::Global->modInstance('samba');
        my $ldap = $users->ldap();
        my $result = $ldap->search({base => $ldap->dn(),
                                   scope => 'sub',
                                   filter => "(objectSID=$params{SID})",
                                   attrs => ['samAccountName']});
        my $count = $result->count();
        if ($count != 1) {
            throw EBox::Exceptions::Internal("The specified domain SID " .
                "has returned $count results, expected one");
        }
        my $entry = $result->entry(0);
        $principal = $entry->get_value('samAccountName');
    } elsif (length $params{RID}) {
        my $users = EBox::Global->modInstance('samba');
        my $ldap = $users->ldap();
        my $sid = $ldap->domainSID() . '-' . $params{RID};
        my $result = $ldap->search({base => $ldap->dn(),
                                   scope => 'sub',
                                   filter => "(objectSID=$sid)",
                                   attrs => ['samAccountName']});
        my $count = $result->count();
        if ($count != 1) {
            throw EBox::Exceptions::Internal("The specified domain RID " .
                "has returned $count results, expected one");
        }
        my $entry = $result->entry(0);
        $principal = $entry->get_value('samAccountName');
    } elsif (length $params{principal}) {
        $principal = $params{principal};
    } else {
        throw EBox::Exceptions::MissingArgument('principal | SID | RID');
    }

    if (length $params{realm}) {
        $realm = $params{realm};
    } else {
        my $samba = EBox::Global->modInstance('samba');
        $realm = $samba->kerberosRealm();
    }

    unless (length $principal) {
        throw EBox::Exceptions::Internal("Empty principal name");
    }

    unless (length $realm) {
        throw EBox::Exceptions::Internal("Empty realm");
    }

    my ($targetPrincipal, $targetRealm) = split(/@/, $principal);
    if (length $targetRealm and $targetRealm ne $realm) {
        my $error = "The specified principal realm ($targetRealm) does not " .
            "match specified realm ($realm)";
        throw EBox::Exceptions::MissingArgument($error);
    }

    $singleton = {};
    $singleton->{principal} = $targetPrincipal;
    $singleton->{realm} = $realm;
    $singleton->{password} = $params{password};
    $singleton->{keytab} = EBox::Config::conf() . 'samba.keytab';
    bless ($singleton, $class);

    if ($singleton->{password}) {
        $singleton->_getTicketUsingPassword($singleton->{principal},
            $singleton->{realm}, $singleton->{password});
    } else {
        $singleton->_getTicketUsingKeytab($singleton->{principal},
            $singleton->{realm}, $singleton->{keytab});
    }

    return $singleton;
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
    if (not EBox::Sudo::fileTest('-f', $keytab) or $retry) {
        $self->_extractKeytab($principal, $realm, $keytab);
        $retry = 0;
    }

    # Try to get ticket
    my $ret = kinit($keytab, "$principal\@$realm");
    if (defined $ret and $ret == 1) {
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
    push (@cmds, "rm -f '$keytab'");
    push (@cmds, "samba-tool domain exportkeytab '$keytab' " .
                 "--principal='$principal\@$realm'");
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

# Method: principal
#
#   Return the name of the principal for which we hold tickets
#
sub principal
{
    my ($self) = @_;

    return $self->{principal};
}

# Method: realm
#
#   Return the name of the realm
#
sub realm
{
    my ($self) = @_;

    return $self->{realm};
}

# Method: DESTROY
#
#   This is the class destructor, which destroy the ticket cache when the
#   last reference to the class is destroyed
#
sub DESTROY
{
    my ($self) = @_;

    $self->destroy();
    $singleton = undef;
}

1;
