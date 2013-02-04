# Copyright (C) 2012 eBox Technologies S.L.
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

package EBox::Samba::Provision;

use constant SAMBA_PROVISION_FILE => '/home/samba/.provisioned';

sub new
{
	my ($class, %params) = @_;
	my $self = {};
    bless ($self, $class);
    return $class;
}

sub isProvisioned
{
	my ($self) = @_;

 	return EBox::Sudo::fileTest('-f', SAMBA_PROVISION_FILE);
}

sub setProvisioned
{
    my ($self, $provisioned) = @_;

    if ($provisioned) {
        EBox::Sudo::root("touch " . SAMBA_PROVISION_FILE);
    } else {
        EBox::Sudo::root("rm -f " . SAMBA_PROVISION_FILE);
    }
}

# Method: checkEnvironment
#
#   This method ensure that the environment is properly configured for
#   samba provision.
#
# Arguments:
#
#   throwException - 0 print warn on log, 1 throw exception
#
# Returns:
#
#   The IP address to use for provision
#
sub checkEnvironment
{
    my ($self, $throwException) = @_;

    unless (defined $throwException) {
        throw EBox::Exceptions::MissingArgument('throwException');
    }

    # Get the own doamin
    my $sysinfo    = EBox::Global->modInstance('sysinfo');
    my $hostDomain = $sysinfo->hostDomain();
    my $hostName   = $sysinfo->hostName();

    # Get the kerberos realm
    my $users = EBox::Global->modInstance('users');
    my $realm = $users->kerberosRealm();

    # The own doamin and the kerberos realm must be equal
    my $samba = EBox::Global->modInstance('samba');
    unless (lc $hostDomain eq lc $realm) {
        $samba->enableService(0);
        my $err = __x("The host domain '{d}' has to be the same than the " .
                      "kerberos realm '{r}'", d => $hostDomain, r => $realm);
        if ($throwException) {
            throw EBox::Exceptions::External($err);
        } else {
            EBox::warn($err);
        }
    }

    # Check the domain exists in DNS module
    my $dns = EBox::Global->modInstance('dns');
    my $domainModel = $dns->model('DomainTable');
    my $domainRow = $domainModel->find(domain => $hostDomain);
    unless (defined $domainRow) {
        $samba->enableService(0);
        my $err = __x("The required domain '{d}' could not be found in the " .
                      "dns module", d => $hostDomain);
        if ($throwException) {
            throw EBox::Exceptions::External($err);
        } else {
            EBox::warn($err);
        }
    }

    # Check the hostname exists in the DNS module
    my $hostsModel = $domainRow->subModel('hostnames');
    my $hostRow = $hostsModel->find(hostname => $hostName);
    unless (defined $hostRow) {
        $samba->enableService(0);
        my $err = __x("The required host record '{h}' could not be found in " .
                      "the domain '{d}'", h => $hostName, d => $hostDomain);
        if ($throwException) {
            throw EBox::Exceptions::External($err);
        } else {
            EBox::warn($err);
        }
    }

    # Get the IP addresses models (domain and hostname)
    my $domainIPsModel = $domainRow->subModel('ipAddresses');
    my $hostIPsModel = $hostRow->subModel('ipAddresses');

    # Get the IP address to use for provision, and check that this IP is assigned
    # to the domain
    my $network = EBox::Global->modInstance('network');
    my $ifaces = $samba->sambaInterfaces();
    my $provisionIP = undef;
    foreach my $iface (@{$ifaces}) {
        next if $iface eq 'lo';
        my $ifaceAddrs = $network->ifaceAddresses($iface);
        foreach my $data (@{$ifaceAddrs}) {
            # Got one candidate address, check that it is assigned to the DNS domain
            my $inDomainModel = 0;
            my $inHostModel = 0;
            foreach my $rowId (@{$domainIPsModel->ids()}) {
                my $row = $domainIPsModel->row($rowId);
                if ($row->valueByName('ip') eq $data->{address}) {
                    $inDomainModel = 1;
                    last;
                }
            }
            foreach my $rowId (@{$hostIPsModel->ids()}) {
                my $row = $hostIPsModel->row($rowId);
                if ($row->valueByName('ip') eq $data->{address}) {
                    $inHostModel = 1;
                    last;
                }
            }
            if ($inDomainModel and $inHostModel) {
                $provisionIP = $data->{address};
                last;
            }
        }
        last if defined $provisionIP;
    }
    unless (defined $provisionIP) {
        $samba->enableService(0);
        my $err = __("Samba can't be provisioned if no IP addresses are set and the " .
                   "DNS domain is properly configured. Ensure that you have at least a " .
                   "IP address assigned to an internal interface, and this IP has to be " .
                   "assigned to the domain and to the hostname in the DNS domain.");
        if ($throwException) {
            throw EBox::Exceptions::External($err);
        } else {
            EBox::warn($err);
        }
    }

    return $provisionIP;
}

# Method: setupDNS
#
#   Modify the domain setup for samba or for users module
#
# Parameters:
#
#   dlz - If set to 1, the domain will be set up for samba, else it will be
#         set up for users module
#
sub setupDNS
{
    my ($self, $dlz) = @_;

    my $dnsModule = EBox::Global->modInstance('dns');
    my $sysinfo = EBox::Global->modInstance('sysinfo');

    # Ensure that the managed domain exists
    my $domainModel = $dnsModule->model('DomainTable');
    my $domainRow = $domainModel->find(domain => $sysinfo->hostDomain());
    unless (defined $domainRow) {
        throw EBox::Exceptions::Internal("Domain named '" . $sysinfo->hostDomain()
            . "' not found");
    }

    # Mark the domain as samba
    if ($dlz) {
        EBox::debug('Setting up DNS for samba');
        $domainRow->elementByName('samba')->setValue(1);
    } else {
        EBox::debug('Setting up DNS for users');
        $domainRow->elementByName('samba')->setValue(0);
    }
    $domainRow->store();

    # Stop service to avoid nsupdate failure
    $dnsModule->stopService();

    # And force service restart
    $dnsModule->save();

    my $samba = EBox::Global->modInstance('samba');
    if (EBox::Sudo::fileTest('-f', $samba->SAMBA_DNS_KEYTAB())) {
        my @cmds;
        push (@cmds, "chgrp bind " . $samba->SAMBA_DNS_KEYTAB());
        push (@cmds, "chmod g+r " . $samba->SAMBA_DNS_KEYTAB());
        EBox::Sudo::root(@cmds);
    }
}

# Method: provision
#
#   This method provision the database
#
sub provision
{
    my ($self) = @_;

    # Stop the service
    my $samba = EBox::Global->modInstance('samba');
    $samba->stopService();

    # Check environment
    my $provisionIP = $self->checkEnvironment(2);

    # Delete samba config file and private folder
    my @cmds;
    push (@cmds, 'rm -f ' . $samba->SAMBACONFFILE());
    push (@cmds, 'rm -rf ' . $samba->PRIVATE_DIR() . '/*');
    push (@cmds, 'rm -rf ' . $samba->SYSVOL_DIR() . '/*');
    EBox::Sudo::root(@cmds);

    my $mode = $samba->mode();
    if ($mode eq EBox::Samba::Model::GeneralSettings::MODE_DC()) {
        $self->provisionDC($provisionIP);
    } elsif ($mode eq EBox::Samba::Model::GeneralSettings::MODE_ADC()) {
        $self->provisionADC();
    } else {
        throw EBox::Exceptions::External(__x('The mode {mode} is not supported'), mode => $mode);
    }
}

sub resetSysvolACL
{
    my ($self) = @_;

    # Reset the sysvol permissions
    EBox::info("Reseting sysvol ACLs to defaults");
    my $cmd = SAMBATOOL . " ntacl sysvolreset";
    EBox::Sudo::rootWithoutException($cmd);
}

sub mapAccounts
{
    my ($self) = @_;

    my $domainSID = $self->ldb->domainSID();

    # Map unix root account to domain administrator. The accounts are
    # imported to Zentyal here to avoid s4sync overwrite the uid/gid
    # mapping
    my $typeUID  = EBox::LDB::IdMapDb::TYPE_UID();
    my $typeGID  = EBox::LDB::IdMapDb::TYPE_GID();
    my $typeBOTH = EBox::LDB::IdMapDb::TYPE_BOTH();
    my $domainAdminSID = "$domainSID-500";
    my $domainAdminsSID = "$domainSID-512";
    my $rootUID = 0;
    my $admGID = 4;

    EBox::info("Mapping domain administrator account");
    my $domainAdmin = new EBox::Samba::User(sid => $domainAdminSID);
    $domainAdmin->addToZentyal() if ($domainAdmin->exists());
    $self->ldb->idmap->setupNameMapping($domainAdminSID, $typeUID, $rootUID);
    EBox::info("Mapping domain administrators group account");
    my $domainAdmins = new EBox::Samba::Group(sid => $domainAdminsSID);
    $domainAdmins->addToZentyal() if ($domainAdmins->exists());
    $self->ldb->idmap->setupNameMapping($domainAdminsSID, $typeBOTH, $admGID);

    # Map domain users group
    # FIXME Why is this not working during first intall???
    #my $usersModule = EBox::Global->modInstance('users');
    #my $usersGID = getpwnam($usersModule->DEFAULTGROUP());
    my $usersGID = 1901;
    my $domainUsersSID = "$domainSID-513";
    $self->ldb->idmap->setupNameMapping($domainUsersSID, $typeGID, $usersGID);

    # Map domain guest account to nobody user
    my $guestSID = "$domainSID-501";
    my $guestGroupSID = "$domainSID-514";
    #my $uid = getpwnam(EBox::Samba::Model::SambaShares::GUEST_DEFAULT_USER());
    #my $gid = getgrnam(EBox::Samba::Model::SambaShares::GUEST_DEFAULT_GROUP());
    my $uid = 65534;
    my $gid = 65534;
    EBox::info("Mapping domain guest account");
    $self->ldb->idmap->setupNameMapping($guestSID, $typeUID, $uid);
    EBox::info("Mapping domain guests group account");
    $self->ldb->idmap->setupNameMapping($guestGroupSID, $typeGID, $gid);
}

sub provisionDC
{
    my ($self, $provisionIP) = @_;

    my $samba = EBox::Global->modInstance('samba');
    $samba->writeSambaConfig();

    my $fs = EBox::Config::configkey('samba_fs');
    my $sysinfo = EBox::Global->modInstance('sysinfo');
    my $usersModule = EBox::Global->modInstance('users');
    my $cmd = 'samba-tool domain provision ' .
        " --domain='" . $samba->workgroup() . "'" .
        " --workgroup='" . $samba->workgroup() . "'" .
        " --realm='" . $usersModule->kerberosRealm() . "'" .
        " --dns-backend=BIND9_DLZ" .
        " --use-xattrs=yes " .
        " --use-rfc2307 " .
        " --server-role='" . $samba->mode() . "'" .
        " --users='" . $usersModule->DEFAULTGROUP() . "'" .
        " --host-name='" . $sysinfo->hostName() . "'" .
        " --host-ip='" . $provisionIP . "'";
    $cmd .= ' --use-ntvfs' if (defined $fs and $fs eq 'ntvfs');

    EBox::info("Provisioning database '$cmd'");
    $cmd .= " --adminpass='" . $samba->administratorPassword() . "'";

    # Use silent root to avoid showing the admin pass in the logs if
    # provision command fails.
    my $output = EBox::Sudo::silentRoot($cmd);
    if ($? == 0) {
        EBox::debug("Provision result: @{$output}");
    } else {
        my @error = ();
        my $stderr = EBox::Config::tmp() . 'stderr';
        if (-r $stderr) {
            @error = read_file($stderr);
        }
        throw EBox::Exceptions::Internal("Error provisioning database. Output: @{$output}, error:@error");
    };

    # Disable password policy
    # NOTE complexity is disabled because when changing password in
    #      zentyal the command may fail if it do not meet requirements,
    #      ending with different passwords
    EBox::info('Setting password policy');
    $cmd = "samba-tool domain passwordsettings set " .
                       " --complexity=off "  .
                       " --min-pwd-length=0" .
                       " --min-pwd-age=0" .
                       " --max-pwd-age=365";
    EBox::Sudo::root($cmd);

    # Set DNS. The domain should have been created by the users
    # module.
    $self->setupDNS(1);

    # Start managed service to let it create the LDAP socket
    $samba->_startService();

    # Load all zentyal users and groups into ldb
    $samba->ldb->ldapUsersToLdb();
    $samba->ldb->ldapGroupsToLdb();
    $samba->ldb->ldapServicePrincipalsToLdb();

    # Map accounts
    $self->mapAccounts();

    # Reset sysvol
    $self->resetSysvolACL();

    # Mark the module as provisioned
    EBox::debug('Setting provisioned flag');
    $self->setProvisioned(1);
}

sub provisionADC
{
    my ($self) = @_;

    my $model = $self->model('GeneralSettings');
    my $domainToJoin = lc ($model->value('realm'));
    my $dcFQDN = $model->value('dcfqdn');
    my $domainDNS = $model->value('dnsip');
    my $adminAccount = $model->value('adminAccount');
    my $adminAccountPwd = $model->value('password');
    my $netbiosDomain = $model->value('workgroup');
    my $site = $model->value('site');

    # If the host domain or the users kerberos realm does not
    # match the domain we are trying to join warn the user and
    # abort
    my $sysinfo = EBox::Global->modInstance('sysinfo');
    my $usersModule = EBox::Global->modInstance('users');
    my $hostName = $sysinfo->hostName();
    my $ucHostName = uc ($hostName);
    my $krbRealm = $usersModule->kerberosRealm();
    my $fqdn = $sysinfo->fqdn();
    if (lc ($sysinfo->hostDomain()) ne lc ($domainToJoin) or
        lc ($sysinfo->hostDomain()  ne lc ($krbRealm))) {
        throw EBox::Exceptions::External(
            __('The server domain and kerberos realm must match the ' .
               'domain you are trying to join.'));
    }

    my $dnsFile = undef;
    my $adminAccountPwdFile = undef;
    try {
        EBox::info("Joining to domain '$domainToJoin' as DC");

        # Set the domain DNS as the primary resolver. This will also let to get
        # the kerberos ticket for the admin account.
        EBox::debug("Setting domain DNS server '$domainDNS' as the primary resolver");
        $dnsFile = new File::Temp(TEMPLATE => 'resolvXXXXXX',
                                  DIR      => EBox::Config::tmp());
        EBox::Sudo::root("cp /etc/resolv.conf $dnsFile");
        my $array = [];
        push (@{$array}, searchDomain => $domainToJoin);
        push (@{$array}, nameservers => [ $domainDNS ]);
        $self->writeConfFile(EBox::Network::RESOLV_FILE(),
                             'network/resolv.conf.mas',
                             $array);

        # Try to contact the DC
        EBox::info("Trying to contact '$dcFQDN'");
        my $pinger = Net::Ping->new('tcp', 2);
        $pinger->port_number(445);
        unless ($pinger->ping($dcFQDN)) {
            throw EBox::Exceptions::External(
                __x('The specified domain controller {x} is unreachable.',
                    x => $dcFQDN));
        }

        # Get a ticket for admin User
        my $principal = "$adminAccount\@$krbRealm";
        (undef, $adminAccountPwdFile) = tempfile(EBox::Config::tmp() . 'XXXXXX', CLEANUP => 1);
        EBox::info("Trying to get a kerberos ticket for principal '$principal'");
        write_file($adminAccountPwdFile, $adminAccountPwd);
        my $cmd = "kinit -e arcfour-hmac-md5 --password-file='$adminAccountPwdFile' $principal";
        EBox::Sudo::root($cmd);

        # Join the domain
        EBox::info("Executing domain join");
        $cmd = "samba-tool domain join $domainToJoin DC " .
            " --username='$adminAccount' " .
            " --workgroup='$netbiosDomain' " .
            " --password='$adminAccountPwd' " .
            " --server='$dcFQDN' " .
            " --dns-backend=BIND9_DLZ " .
            " --realm='$domainToJoin' ";
        if (defined $site and length($site) > 0) {
            $cmd .= " --site='$site' ";
        }

        my $output = EBox::Sudo::silentRoot($cmd);
        if ($? == 0) {
            EBox::debug("Provision result: @{$output}");
        } else {
            my @error = ();
            my $stderr = EBox::Config::tmp() . 'stderr';
            if (-r $stderr) {
                @error = read_file($stderr);
            }
            throw EBox::Exceptions::External("Error joining to domain: @error");
        }

        $self->setupDNS(1);

        # Write smb.conf to grant rw access to zentyal group on the
        # privileged socket
        $self->writeSambaConfig();

        # Start managed service to let it create the LDAP socket
        EBox::debug('Starting service');
        $self->_startService();

        # Wait some time until samba is ready
        sleep (5);

        # Run samba_dnsupdate to add required records to the remote DC
        EBox::info('Running DNS update on remote DC');
        $cmd = 'samba_dnsupdate --no-credentials';
        EBox::Sudo::rootWithoutException($cmd);

        # Run Knowledge Consistency Checker (KCC) on remote DC
        EBox::info('Running KCC on remote DC');
        $cmd = "samba-tool drs kcc $dcFQDN " .
            " --username='$adminAccount' " .
            " --password='$adminAccountPwd' ";
        EBox::Sudo::rootWithoutException($cmd);

        # Purge users and groups
        EBox::info("Purging the Zentyal LDAP to import Samba users");
        my $usersMod = EBox::Global->modInstance('users');
        my $users = $usersMod->users();
        my $groups = $usersMod->groups();
        foreach my $zentyalUser (@{$users}) {
            $zentyalUser->setIgnoredModules(['samba']);
            $zentyalUser->deleteObject();
        }
        foreach my $zentyalGroup (@{$groups}) {
            $zentyalGroup->setIgnoredModules(['samba']);
            $zentyalGroup->deleteObject();
        }

        # Load Zentyal service principals into samba
        $self->ldb->ldapServicePrincipalsToLdb();

        # FIXME This should not be necessary, it is a samba bug.
        #my @cmds = ();
        #push (@cmds, "rm -f " . SAMBA_DNS_KEYTAB);
        #push (@cmds, "samba-tool spn add DNS/$fqdn $ucHostName\$");
        #push (@cmds, "samba-tool domain exportkeytab " . SAMBA_DNS_KEYTAB .
        #    " --principal=$ucHostName\$");
        #push (@cmds, "samba-tool domain exportkeytab " . SAMBA_DNS_KEYTAB .
        #    " --principal=DNS/$fqdn");
        #push (@cmds, "chgrp bind " . SAMBA_DNS_KEYTAB);
        #push (@cmds, "chmod g+r " . SAMBA_DNS_KEYTAB);
        #EBox::Sudo::root(@cmds);

        # Map accounts
        $self->mapAccounts();

        EBox::debug('Setting provisioned flag');
        $self->setProvisioned(1);
    } otherwise {
        my $error = shift;
        $self->setProvisioned(0);
        $self->setupDNS(0);
        throw $error;
    } finally {
        # Revert primary resolver changes
        if (defined $dnsFile and -f $dnsFile) {
            EBox::Sudo::root("cp $dnsFile /etc/resolv.conf");
            unlink $dnsFile;
        }
        # Remote stashed password
        if (defined $adminAccountPwdFile and -f $adminAccountPwdFile) {
            unlink $adminAccountPwdFile;
        }
        # Destroy cached tickets
        EBox::Sudo::rootWithoutException('kdestroy');
    };
}

1;
