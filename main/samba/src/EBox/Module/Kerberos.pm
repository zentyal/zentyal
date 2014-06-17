# Copyright (C) 2012-2014 Zentyal S.L.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

use strict;
use warnings;

package EBox::Module::Kerberos;

use base qw(
    EBox::Module::LDAP
);

use TryCatch::Lite;
use Net::LDAP;
use Net::LDAP::Constant qw(LDAP_LOCAL_ERROR);
use EBox::Gettext;
use EBox::Util::Random;
use EBox::Samba::User;

sub new
{
	my $class = shift;
	my $self = {};
	bless ($self, $class);
	return $self;
}

# Method: _kerberosServicePrincipals
#
#   Return the service principal names to add to the service account.
#
#   To be implemented by the module.
#
# Return:
#
#   Array ref - Containing the SPNs
#
sub _kerberosServicePrincipals
{
    my ($self) = @_;

    throw EBox::Exceptions::NotImplemented('_kerberosServicePrincipals');
}

# Method: _kerberosKeytab
#
#   Return the necessary information to extract the keytab for the service.
#   The keytab will contain the service account keys with all its service
#   principals.
#
#   To be implemented by the module
#
# Return:
#
#   Hash ref - Containig the following pairs:
#       path - The path where the keytab will be extracted
#       user - The owner user for the extracted keytab
#       group - The owner group for the extracted keytab
#       mode - The mode for the extracted keytab
#
sub _kerberosKeytab
{
    my ($self) = @_;

    throw EBox::Exceptions::NotImplemented('_kerberosKeytab');
}

# Method: _kerberosServiceAccount
#
#   Return the name of the account used by the service. By default, it is
#   zentyal-<module name>, but it can be overrided by the module.
#
# Return:
#
#   The name of the account used by the module.
#
sub _kerberosServiceAccount
{
    my ($self) = @_;

    my $account = "zentyal-" . $self->name();
    return $account;
}

# Method: _kerberosFullSPNs
#
#   Return the expanded service principal names: for each SPN returned by
#   the module build:
#       <spn>/<host fqdn>
#       <spn>/<host fqdn>@<realm>
#
sub _kerberosFullSPNs
{
    my ($self) = @_;

    my $samba = $self->global->modInstance('samba');
    my $sysinfo = $self->global->modInstance('sysinfo');
    my $fqdn = $sysinfo->fqdn();
    my $realm = $samba->kerberosRealm();
    my $spns = [];
    foreach my $spn (@{$self->_kerberosServicePrincipals}) {
        push (@{$spns}, "$spn/$fqdn");
        push (@{$spns}, "$spn/$fqdn\@$realm");
    }
    return $spns;
}

# Method: _kerberosCreateServiceAccount
#
#   Creates the module service account
#
sub _kerberosCreateServiceAccount
{
    my ($self) = @_;

    # Create service account
    my $ldap = $self->ldap();
    my $defaultNC = $ldap->rootDse->get_value('defaultNamingContext');
    my $modname = $self->name();
    my $cn = $self->_kerberosServiceAccount();
    my $dn = "CN=$cn,CN=Users,$defaultNC";
    my $obj;

    my $param = {
        base => $dn,
        scope => 'base',
        filter => 'objectClass=*',
    };
    my $result = $ldap->search($param);
    if ($result->count() == 0) {
        # The principal does not exists, so create it
        my $userAccountControl = EBox::Samba::User::NORMAL_ACCOUNT() |
                                 EBox::Samba::User::ACCOUNTDISABLE() |
                                 EBox::Samba::User::DONT_EXPIRE_PASSWORD();
        my @attr = ();
        push (@attr, objectClass => ['top', 'person', 'organizationalPerson', 'user']);
        push (@attr, cn          => $cn);
        push (@attr, description => "Zentyal $modname Service Account");
        push (@attr, name => $cn);
        push (@attr, samAccountName => $cn);
        push (@attr, userAccountControl => $userAccountControl);

        my $entry = new Net::LDAP::Entry($dn, @attr);
        $result = $entry->update($ldap->connection());
        if ($result->is_error()) {
            unless ($result->code() == LDAP_LOCAL_ERROR and
                    $result->error() eq 'No attributes to update')
            {
                throw EBox::Exceptions::LDAP(
                    message => __('Error on LDAP entry creation:'),
                    result => $result,
                    opArgs => EBox::Samba::LdapObject->entryOpChangesInUpdate($entry),
                );
            }
        }

        # Set the password
        my $password = EBox::Util::Random::generate(20);
        $obj = new EBox::Samba::User(dn => $dn);
        $obj->changePassword($password, 0);
        $obj->setAccountEnabled(1);
    } else {
        $obj = new EBox::Samba::User(dn => $dn);
    }

    # Set the system critical and show in advanced view only flags
    $obj->setInAdvancedViewOnly(1, 0);
    $obj->setCritical(1, 0);
}

# Method: _kerberosSetSPNs
#
#   Add the SPNs to the service account
#
sub _kerberosSetSPNs
{
    my ($self) = @_;

    my $ldap = $self->ldap();
    my $defaultNC = $ldap->rootDse->get_value('defaultNamingContext');
    my $account = $self->_kerberosServiceAccount();
    my $dn = "CN=$account,CN=Users,$defaultNC";

    my $param = {
        base => $dn,
        scope => 'base',
        filter => 'objectClass=*',
    };
    my $result = $ldap->search($param);
    if ($result->count() != 1) {
        throw EBox::Exceptions::Internal(
            __x('Unexpected number of LDAP entries found searching for {dn}: Expected one, got {count}',
                dn => $dn, count => $result->count()));
    }

    my $spns = $self->_kerberosFullSPNs();
    return unless scalar @{$spns};

    my $entry = $result->entry(0);
    $entry->replace(servicePrincipalName => $spns);
    $result = $entry->update($ldap->connection());
    if ($result->is_error()) {
        unless ($result->code() == LDAP_LOCAL_ERROR and
                $result->error() eq 'No attributes to update')
        {
            throw EBox::Exceptions::LDAP(
                message => __('Error on LDAP entry update:'),
                result => $result,
                opArgs => EBox::Samba::LdapObject->entryOpChangesInUpdate($entry),
            );
        }
    }
}

# Method: _kerberosRefreshKeytab()
#
#   Refresh the keytab used by the module
#
sub _kerberosRefreshKeytab
{
    my ($self) = @_;

    my $info = $self->_kerberosKeytab();
    my $account = $self->_kerberosServiceAccount();
    my $spns = $self->_kerberosFullSPNs();

    my $keytabPath = $info->{path};
    unless (defined $keytabPath) {
        throw EBox::Exceptions::Internal("No keytab path supplied");
    }
    my $keytabUser = defined $info->{user} ? $info->{user} : 'root';
    my $keytabGroup = defined $info->{group} ? $info->{group} : 'root';
    my $keytabMode = defined $info->{mode} ? $info->{mode} : '400';

    my @cmds;
    push (@cmds, "samba-tool domain exportkeytab '$keytabPath' --principal '$account'");
    foreach my $spn (@{$spns}) {
        push (@cmds, "samba-tool domain exportkeytab '$keytabPath' --principal '$spn'");
    }
    push (@cmds, "chown '$keytabUser':'$keytabGroup' '$keytabPath'");
    push (@cmds, "chmod '$keytabMode' '$keytabPath'");
    EBox::Sudo::root(@cmds);
}

# Method: _kerberosSetup
#
#   Perform the kerberos module setup:
#       - Create the service account for the module if not exists
#       - Add the SPNs to the service account
#       - Refresh the module keytab.
#
sub _kerberosSetup
{
    my ($self) = @_;

    $self->_kerberosCreateServiceAccount();
    $self->_kerberosSetSPNs();
    $self->_kerberosRefreshKeytab();
}

# Method: _regenConfig
#
#   Overrides <EBox::Module::Service::_regenConfig>
#
sub _regenConfig
{
    my $self = shift;

    return unless $self->configured();

    my $samba = $self->global->modInstance('samba');
    if ($samba->isProvisioned()) {
        $self->_kerberosSetup();
        $self->SUPER::_regenConfig(@_);
    }
}

1;
