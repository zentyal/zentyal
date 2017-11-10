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

use TryCatch;
use Net::LDAP;
use Net::LDAP::Constant qw(LDAP_LOCAL_ERROR);
use File::Slurp;
use EBox::Gettext;
use EBox::Util::Random;
use EBox::Samba::User;
use File::Copy;

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
#   Return the common name of the account used by the service. By default, it
#   is zentyal-<module name>-<hostname>, but it can be overrided by the module.
#
# Return:
#
#   The name of the account used by the module.
#
sub _kerberosServiceAccount
{
    my ($self) = @_;

    my $sysinfo = $self->global->modInstance('sysinfo');
    my $modname = $self->name();
    my $hostname = $sysinfo->hostName();
    my $account = "zentyal-$modname-$hostname";
    return $account;
}

# Method: _kerberosServiceAccountDN
#
#   Return the DN of the account used by the service.
#
# Return:
#
#   The name of the account used by the module.
#
sub _kerberosServiceAccountDN
{
    my ($self) = @_;

    my $ldap = $self->ldap();
    my $defaultNC = $ldap->rootDse->get_value('defaultNamingContext');
    my $cn = $self->_kerberosServiceAccount();
    return "CN=$cn,CN=Users,$defaultNC";
}

sub _kerberosServicePasswordFile
{
    my ($self) = @_;
    my $account = $self->_kerberosServiceAccount();
    my $pwdFile = EBox::Config::conf() . $account . ".passwd";
    return $pwdFile;
}

# Method: _kerberosServiceAccountPassword
#
#   Return the password of the account used by the service.
#
# Return:
#
#   The password of the account used by the module.
#
sub _kerberosServiceAccountPassword
{
    my ($self) = @_;

    my $pwdFile = $self->_kerberosServicePasswordFile();
    my $pass;
    unless (-f $pwdFile) {
        my $pass;

        while (1) {
            $pass = EBox::Util::Random::generate(20);
            # Check if the password meet the complexity constraints
            last if ($pass =~ /[a-z]+/ and $pass =~ /[A-Z]+/ and
                     $pass =~ /[0-9]+/ and length ($pass) >=8);
        }

        # We are generating a new password, set it
        my $dn = $self->_kerberosServiceAccountDN();
        my $obj = new EBox::Samba::User(dn => $dn);
        $obj->changePassword($pass, 0);
        $obj->setAccountEnabled(1);

        # And stash to file
        my $zuser = EBox::Config::user();
        my (undef, undef, $uid, $gid) = getpwnam($zuser);
        EBox::Module::Base::writeFile($pwdFile, $pass,
            { mode => '0600', uid => $uid, gid => $gid }
        );
        return $pass;
    }

    return File::Slurp::read_file($pwdFile);
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

    my $modSPNs = $self->_kerberosServicePrincipals();
    return [] unless defined $modSPNs;

    my $spns = [];
    foreach my $spn (@{$modSPNs}) {
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
    my $modname = $self->name();
    my $cn = $self->_kerberosServiceAccount();
    my $dn = $self->_kerberosServiceAccountDN();

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
        $self->_kerberosServiceAccountPassword();
    }

    # Set the system critical and show in advanced view only flags
    my $obj = new EBox::Samba::User(dn => $dn);
    $obj->setInAdvancedViewOnly(1, 0);
    $obj->setCritical(1, 0);

    # Disable expiration on service account
    EBox::Sudo::root("samba-tool user setexpiry $cn --noexpiry");
}

# Method: _kerberosSetSPNs
#
#   Add the SPNs to the service account
#
sub _kerberosSetSPNs
{
    my ($self) = @_;

    # Get the list of expanded SPNs
    my $spns = $self->_kerberosFullSPNs();
    return unless scalar @{$spns};

    my $ldap = $self->ldap();
    my $defaultNC = $ldap->rootDse->get_value('defaultNamingContext');
    my $dn = $self->_kerberosServiceAccountDN();

    # Remove SPNs from another accounts
    foreach my $spn (@{$spns}) {
        my $param = {
            base => $defaultNC,
            scope => 'sub',
            filter => "(servicePrincipalName=$spn)",
        };
        my $result = $ldap->search($param);
        foreach my $entry ($result->entries()) {
            next if (lc ($entry->dn()) eq lc ($dn));
            $entry->delete(servicePrincipalName => [ $spn ]);
            $entry->update($ldap->connection());
        }
    }

    # Add SPNs to the service account
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
    return unless defined $info;

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

sub aroundDumpConfig
{
    my ($self, $dir, @options) = @_;
    $self->_dumpServiceAccountPassword($dir);
    $self->SUPER::aroundDumpConfig($dir, @options);
}

sub aroundRestoreConfig
{
    my ($self, $dir, @options) = @_;
    $self->_restoreServiceAccountPassword($dir);
    $self->SUPER::aroundRestoreConfig($dir, @options);
}

sub _dumpPasswordFile
{
    my ($self, $dir) = @_;
    return "$dir/kerberosServicePassword";
}

sub _dumpServiceAccountPassword
{
    my ($self, $dir) = @_;
    my $pwdFile  = $self->_kerberosServicePasswordFile();
    if (-f $pwdFile) {
        my $dumpFile = $self->_dumpPasswordFile($dir);
        if (-e $dumpFile) {
            throw EBox::Exceptions::Internal("Error backing up '$dumpFile' shoud not exist");
        }
        my $ok = copy($pwdFile, $dumpFile);
        if (not $ok) {
            throw EBox::Exceptions::Internal("Error copying '$dumpFile' into backup: $!");
        }
    }
}

sub _restoreServiceAccountPassword
{
    my ($self, $dir) = @_;
    my $dumpFile = $self->_dumpPasswordFile($dir);
    if (-f $dumpFile) {
        my $pwdFile  = $self->_kerberosServicePasswordFile();
        if (-d $pwdFile) {
            throw EBox::Exceptions::Internal("Error restoring '$pwdFile' should not be a directory");
        }
        my $ok = copy($dumpFile, $pwdFile);
        if (not $ok) {
            throw EBox::Exceptions::Internal("Error restoring '$pwdFile' from backup: $!");
        }
    }
}

1;
