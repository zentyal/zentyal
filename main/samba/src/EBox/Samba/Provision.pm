# Copyright (C) 2013-2014 Zentyal S.L.
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

use EBox::Exceptions::External;
use EBox::Exceptions::Internal;
use EBox::Exceptions::InvalidType;
use EBox::Exceptions::InvalidArgument;
use EBox::Exceptions::MissingArgument;
use EBox::Validate qw(:all);
use EBox::Gettext;
use EBox::Global;
use EBox::Util::Random;

use EBox::Samba::User;
use EBox::Samba::Group;

use EBox::Samba::Model::DomainSettings;

use Net::DNS;
use Net::NTP qw(get_ntp_response);
use Net::Ping;
use Net::LDAP;
use Net::LDAP::Constant qw(LDAP_LOCAL_ERROR);
use Net::LDAP::Util qw(ldap_explode_dn canonical_dn);
use File::Temp qw( tempfile tempdir );
use File::Slurp;
use Time::HiRes;
use TryCatch::Lite;

sub new
{
    my ($class, %params) = @_;
    my $self = {};
    bless ($self, $class);
    return $self;
}

sub isProvisioned
{
    my ($self) = @_;

    my $state = EBox::Global->modInstance('samba')->get_state();
    my $flag = $state->{provisioned};
    my $provisioned = (defined $flag and $flag == 1) ? 1 : 0;

    return $provisioned;
}

sub setProvisioned
{
    my ($self, $provisioned) = @_;

    if ($provisioned != 0 and $provisioned != 1) {
        throw EBox::Exceptions::InvalidArgument('provisioned');
    }
    my $users = EBox::Global->modInstance('samba');
    my $state = $users->get_state();
    $state->{provisioned} = $provisioned;
    $users->set_state($state);
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

    # Get the own domain
    my $sysinfo    = EBox::Global->modInstance('sysinfo');
    my $hostDomain = $sysinfo->hostDomain();
    my $hostName   = $sysinfo->hostName();

    # Get the kerberos realm
    my $users = EBox::Global->modInstance('samba');
    my $realm = $users->kerberosRealm();

    # The own domain and the kerberos realm must be equal
    unless (lc $hostDomain eq lc $realm) {
        $users->enableService(0);
        my $err = __x("The host domain '{d}' has to be the same than the " .
                      "kerberos realm '{r}'", d => $hostDomain, r => $realm);
        if ($throwException) {
            throw EBox::Exceptions::External($err);
        } else {
            EBox::warn($err);
        }
    }

    # The host netbios name must be different than the domain netbios name
    my $settings = $users->model('DomainSettings');
    my $domainNetbiosName = $settings->value('workgroup');
    my $hostNetbiosName = $settings->value('netbiosName');
    if (uc ($domainNetbiosName) eq uc ($hostNetbiosName)) {
        $users->enableService(0);
        my $err = __x("The host netbios name '{x}' has to be the different " .
                      "than the domain netbios name '{y}'",
                      x => $hostNetbiosName, y => $domainNetbiosName);
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
        $users->enableService(0);
        my $err = __x("The required domain '{d}' could not be found in the " .
                      "dns module.<br/>" .
                      "You can add it in the {ohref}DNS domains page{chref}",
                      d => $hostDomain,
                      ohref => "<a href='/DNS/Composite/Global'>",
                      chref => '</a>'
                     );
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
        $users->enableService(0);
        my $hostTableUrl = '/DNS/View/HostnameTable?directory=DomainTable/keys/' . $domainRow->id() .
                                                          '/hostnames';
        my $err = __x("The required host record '{h}' could not be found in " .
                      "the domain '{d}'.<br/>" .
                      "You can add it in the {ohref}host names page for domain {d}{chref}.",
                      h => $hostName,
                      d => $hostDomain,
                      ohref => "<a href='$hostTableUrl'>",
                      chref => '</a>'
                       );
        if ($throwException) {
            throw EBox::Exceptions::External($err);
        } else {
            EBox::warn($err);
        }
    }

    # Get the IP addresses for domain
    my %domainsIp = %{ $self->_domainsIP($users, $domainRow, $throwException) };

    my $hostIPsModel = $hostRow->subModel('ipAddresses');
    # Get the IP address to use for provision, and check that this IP is assigned
    # to the domain
    my $provisionIP = undef;
    foreach my $rowId (@{$hostIPsModel->ids()}) {
        my $row = $hostIPsModel->row($rowId);
        my $ip = $row->valueByName('ip');
        if ($domainsIp{$ip}) {
            $provisionIP = $ip;
            last;
        }
    }

    unless (defined $provisionIP) {
        $users->enableService(0);
        my $ipUrl = '/DNS/View/HostIpTable?directory=' .
                    'DomainTable/keys/' . $domainRow->id() .
                    '/hostnames/keys/' .  $hostRow->id() . '/ipAddresses';
        my $err = __x("Samba can't be provisioned if no IP addresses are set for host {host}.<br/>"  .
                      "Ensure that you have at least a IP address assigned to an interface, and this IP has to be " .
                       "assigned to the domain {dom} and to the hostname {host}.<br/>" .
                       "You can add it in the {ohref}IP addresses page for {host}{chref}",
                      host => $hostName,
                      dom  => $hostDomain,
                      ohref => "<a href='$ipUrl'>",
                      chref => '</a>'
                      );
        if ($throwException) {
            throw EBox::Exceptions::External($err);
        } else {
            EBox::warn($err);
        }
    }

    return $provisionIP;
}

sub _domainsIP
{
    my ($self, $samba, $domainRow, $throwException) = @_;

    my $domainIPsModel = $domainRow->subModel('ipAddresses');
    my @ipIds = @{$domainIPsModel->ids()};

    my $network = EBox::Global->modInstance('network');
    my $ifaces = $network->allIfaces();

    my %domainsIp;
    foreach my $iface (@{$ifaces}) {
        next if $iface eq 'lo';
        my $ifaceAddrs = $network->ifaceAddresses($iface);
        foreach my $data (@{$ifaceAddrs}) {
            # Got one candidate address, check that it is assigned to the DNS domain
            foreach my $rowId (@ipIds) {
                my $row = $domainIPsModel->row($rowId);
                my $ip = $row->valueByName('ip');
                if ($ip eq $data->{address}) {
                    $domainsIp{$ip} = 1;
                }
            }
        }
    }

    if ((keys %domainsIp) == 0) {
        $samba->enableService(0);
        my $domain = $domainRow->valueByName('domain');
        my $domainIpUrl = '/DNS/View/DomainIpTable?directory=DomainTable/keys/' .
                          $domainRow->id() . '/ipAddresses';
        my $err = __x("Samba can't be provisioned if no IP addresses are set for domain {dom}.<br/>"  .
                      "Ensure that you have at least a IP address assigned to an interface, and this IP has to be " .
                       "assigned to the domain {dom} and to the local hostname.<br/>" .
                       "You can assign it in the {ohref}IP addresses page for {dom}{chref}",
                       dom => $domain,
                      ohref => "<a href='$domainIpUrl'>",
                      chref => '</a>'
                      );
        if ($throwException) {
            throw EBox::Exceptions::External($err);
        } else {
            EBox::warn($err);
        }
    }

    return \%domainsIp;
}

# Method: setupDNS
#
#   Modify the domain setup for samba or for users module
#
sub setupDNS
{
    my ($self) = @_;

    EBox::info("Setting up DNS");
    my $users = EBox::Global->modInstance('samba');

    if (EBox::Sudo::fileTest('-f', $users->SAMBA_DNS_KEYTAB())) {
        my @cmds;
        push (@cmds, "chgrp bind " . $users->SAMBA_DNS_KEYTAB());
        push (@cmds, "chmod g+r " . $users->SAMBA_DNS_KEYTAB());
        EBox::Sudo::root(@cmds);
    }

    # Save and restart DNS to load users zones stored in LDB
    my $dnsMod = EBox::Global->modInstance('dns');
    $dnsMod->setAsChanged();
    $dnsMod->save();
}

# Method: setupKerberos
#
#   Link the provision generated kerberos setup to the system
#
sub setupKerberos
{
    my ($self) = @_;
    EBox::info("Setting up kerberos");
    my $systemFile = EBox::Samba::SYSTEM_WIDE_KRB5_CONF_FILE();
    my $systemKeytab = EBox::Samba::SYSTEM_WIDE_KRB5_KEYTAB();
    my $provisionGeneratedKeytab = EBox::Samba::SECRETS_KEYTAB();
    if ($self->isProvisioned()) {
        if (EBox::Sudo::fileTest('-f', $systemKeytab)) {
            EBox::Sudo::root("mv '$systemKeytab' '$systemKeytab.bak'");
        }
        my $samba = EBox::Global->modInstance('samba');
        my $realm = $samba->kerberosRealm();
        my @params = ('realm' => $realm);
        $samba->writeConfFile($systemFile, 'samba/krb5.conf.mas', \@params);
        EBox::Sudo::root("ln -sf '$provisionGeneratedKeytab' '$systemKeytab'");
    }
}

# Method: provision
#
#   This method provision the database
#
sub provision
{
    my ($self) = @_;

    my $global = EBox::Global->getInstance();

    # Stop the service
    my $users = $global->modInstance('samba');
    $users->stopService();
    $users->clearLdapConn();

    # Check environment
    my $provisionIP = $self->checkEnvironment(2);

    # Remove SSS caches
    my @cmds;
    push (@cmds, 'rm -f /var/lib/sss/db/*');

    # Remove extracted keytab
    my $conf = EBox::Config::conf();
    my $keytab = "$conf/samba.keytab";
    push (@cmds, "rm -f '$keytab'");

    # Remove kerberos modules extracted keytabs and stashed passwords
    my $kerberosModules = EBox::Global->modInstancesOfType('EBox::Module::Kerberos');
    foreach my $mod (@{$kerberosModules}) {
        my $keytab = $mod->_kerberosKeytab();
        if (defined $keytab) {
            my $keytabPath = $keytab->{path};
            push (@cmds, "rm -f '$keytabPath'");
        }
        my $account = $mod->_kerberosServiceAccount();
        my $stashedPwdFile = EBox::Config::conf() . $account . ".passwd";
        push (@cmds, "rm -f '$stashedPwdFile'");
        EBox::Sudo::root(@cmds);
    }

    # Delete users config file and private folder
    push (@cmds, 'rm -f ' . $users->SAMBACONFFILE());
    push (@cmds, 'rm -rf ' . $users->PRIVATE_DIR() . '/*');
    push (@cmds, 'rm -rf ' . $users->SYSVOL_DIR() . '/*');
    EBox::Sudo::root(@cmds);

    # Clean redis flags before provision
    foreach my $mod (@{$global->modInstancesOfType('EBox::Module::LDAP')}) {
        my $state = $mod->get_state();
        delete $state->{'_schemasAdded'};
        delete $state->{'_ldapSetup'};
        $mod->set_state($state);
        $mod->setAsChanged();
    }

    my $mode = $users->dcMode();
    if ($mode eq EBox::Samba::Model::DomainSettings::MODE_DC()) {
        $self->provisionDC($provisionIP);
    } elsif ($mode eq EBox::Samba::Model::DomainSettings::MODE_ADC()) {
        $self->provisionADC();
    } else {
        throw EBox::Exceptions::External(__x('The mode {mode} is not supported'), mode => $mode);
    }

    # Disable expiration on administrator account
    EBox::Sudo::root('samba-tool user setexpiry administrator --noexpiry');
    # Clean cache
    EBox::Sudo::root('net cache flush');

    # dns needs to be restarted after save changes to write proper bind conf with the DLZ
    $global->addModuleToPostSave('dns');
}

sub resetSysvolACL
{
    my ($self) = @_;

    # Reset the sysvol permissions
    EBox::info("Reseting sysvol ACLs to defaults");
    my $cmd = "samba-tool ntacl sysvolreset";
    EBox::Sudo::rootWithoutException($cmd);
}

# Method: mapAccounts
#
#   Set the mapping between the objectSID and uidNumber/gidNumber for the
#   following accounts:
#
#       - Administrator
#       - Guest
#       - Domain Admins
#       - Domain Users
#       - Domain Guests
#       - Builtin\Administrators
#
#    Will made the accounts available to unix after setting up NSS.
#
sub mapAccounts
{
    my ($self) = @_;

    my $samba = EBox::Global->modInstance('samba');
    my $ldap = $samba->ldap();
    my $domainSid = $ldap->domainSID();
    my $dse = $ldap->rootDse();
    my $defaultNC = $dse->get_value('defaultNamingContext');

    # Domain admins is a well known SID (S-1-5-21-<domain sid>-512)
    # Domain users is a well known SID (S-1-5-21-<domain sid>-513)
    # Domain guests is a well knwon SID (S-1-5-21-<domain sid>-514)
    foreach my $rid (qw(512 513 514)) {
        try {
            my $sid = "$domainSid-$rid";
            my $result = $ldap->search({ base   => $defaultNC,
                                         filter => "objectSid=$sid",
                                         scope  => 'sub' });
            if ($result->count() != 1) {
                throw EBox::Exceptions::Internal(
                    __x("Unexpected number of entries. Got {x}, expected 1.",
                        x => $result->count()));
            }
            my $entry = $result->entry(0);
            my $group = new EBox::Samba::Group(entry => $entry);
            unless ($group->get('gidNumber')) {
                my $id = $group->unixId($rid);
                EBox::info("Setting gidNumber $id for SID $sid");
                $group->set('gidNumber', $id);
            }
        } catch ($e) {
            EBox::error($e);
            next;
        }
    }

    # Builtin\Administrators is a well known SID S-1-5-32-544
    try {
        my $sid = "S-1-5-32-544";
        my $result = $ldap->search({ base   => $defaultNC,
                                     filter => "objectSid=$sid",
                                     scope  => 'sub' });
        if ($result->count() != 1) {
            throw EBox::Exceptions::Internal(
                __x("Unexpected number of entries. Got {x}, expected 1.",
                    x => $result->count()));
        }
        my $entry = $result->entry(0);
        my $group = new EBox::Samba::Group(entry => $entry);
        unless ($group->get('gidNumber')) {
            # Map unix group adm, which has fixed gidNumber 4
            my $admGid = 4;
            EBox::info("Setting gidNumber for SID $sid");
            $group->set('gidNumber', $admGid);
        }
    } catch ($e) {
        EBox::error($e);
    }

    # Administrator is a well known SID (S-1-5-21-<domain sid>-500)
    # Guest is a well known SID (S-1-5-21-<domain sid>-501)
    my $userMaps = {
        500 => new EBox::Samba::Group(sid => "$domainSid-512"),
        501 => new EBox::Samba::Group(sid => "$domainSid-514"),
    };
    foreach my $rid (keys %{$userMaps}) {
        try {
            my $sid = "$domainSid-$rid";
            my $result = $ldap->search({ base   => $defaultNC,
                                         filter => "objectSid=$sid",
                                         scope  => 'sub' });
            if ($result->count() != 1) {
                throw EBox::Exceptions::Internal(
                    __x("Unexpected number of entries. Got {x}, expected 1.",
                        x => $result->count()));
            }
            my $entry = $result->entry(0);
            my $user = new EBox::Samba::User(entry => $entry);
            unless ($user->get('uidNumber')) {
                my $id = $user->unixId($rid);
                EBox::info("Setting uidNumber $id for SID $sid");
                $user->set('uidNumber', $id);
            }
            unless ($user->get('gidNumber')) {
                my $id = $userMaps->{$rid}->get('gidNumber');
                EBox::info("Setting gidNumber $id for SID $sid");
                $user->set('gidNumber', $id);
            }
        } catch ($e) {
            EBox::error($e);
            next;
        }
    }
}

sub provisionDC
{
    my ($self, $provisionIP) = @_;

    my $usersModule = EBox::Global->modInstance('samba');
    my $passwdFile;
    try {
        $usersModule->writeSambaConfig();

        my $sysinfo = EBox::Global->modInstance('sysinfo');
        my $cmd = 'samba-tool domain provision ' .
            " --domain='" . $usersModule->workgroup() . "'" .
            " --realm='" . $usersModule->kerberosRealm() . "'" .
            " --dns-backend=BIND9_DLZ" .
            " --use-xattrs=yes " .
            " --use-rfc2307 " .
            " --function-level=2003 " .
            " --server-role='" . $usersModule->dcMode() . "'" .
            " --host-name='" . $sysinfo->hostName() . "'" .
            " --host-ip='" . $provisionIP . "'";

        EBox::info("Provisioning database '$cmd'");
        my $pass;
        while (1) {
            $pass = EBox::Util::Random::generate(20);
            # Check if the password meet the complexity constraints
            last if ($pass =~ /[a-z]+/ and $pass =~ /[A-Z]+/ and
                     $pass =~ /[0-9]+/ and length ($pass) >=8);
        }
        $passwdFile = $self->_createTmpPasswdFile($pass);
        $cmd .= " --adminpass=`cat $passwdFile`";

        EBox::Sudo::root($cmd);
        unlink $passwdFile;

        $self->setProvisioned(1);
        $self->setupKerberos();
        $self->setupDNS();
    } catch ($e) {
        if ($passwdFile) {
            unlink $passwdFile;
        }
        $self->setProvisioned(0);
        $self->setupKerberos();
        $self->setupDNS();
        $e->throw();
    }

    try {
        # Disable password policy
        # NOTE complexity is disabled because when changing password in
        #      zentyal the command may fail if it do not meet requirements,
        #      ending with different passwords
        EBox::info('Setting password policy');
        my $cmd = "samba-tool domain passwordsettings set " .
                  " --complexity=off "  .
                  " --min-pwd-length=0" .
                  " --min-pwd-age=0" .
                  " --max-pwd-age=365";
        EBox::Sudo::root($cmd);

        # Write SSS daemon configuration
        $usersModule->_setupNSSPAM();

        # Start managed service to let it create the LDAP socket
        $usersModule->_startService();

        # Map accounts (SID -> Unix UID/GID numbers)
        $self->mapAccounts();

        EBox::debug('Creating Groups container');
        $self->_createGroupsContainer();

        EBox::debug('Hide internal groups');
        $self->_hideInternalGroups();
        EBox::debug('Hide internal users');
        $self->_hideInternalUsers();

        # Reset sysvol
        EBox::debug('Reset Sysvol');
        $self->resetSysvolACL();

        # Set kerberos modules as changed to force them to extract the keytab
        # and stash new password
        my $kerberosModules = EBox::Global->modInstancesOfType('EBox::Module::Kerberos');
        foreach my $mod (@{$kerberosModules}) {
            $mod->setAsChanged();
        }
    } catch ($error) {
        $self->setProvisioned(0);
        throw EBox::Exceptions::Internal($error);
    }
}

sub rootDseAttributes
{
    my ($self) = @_;

    unless (defined $self->{rootDseAttributes}) {
        my $usersModule = EBox::Global->modInstance('samba');
        my $rootDseAttributes = $usersModule->ldap->ROOT_DSE_ATTRS();
        $self->{rootDseAttributes} = $rootDseAttributes;
    }
    return $self->{rootDseAttributes};
}

sub getADDomain
{
    my ($self, $adServerIp) = @_;

    throw EBox::Exceptions::MissingArgument('adServerIp')
        unless (defined $adServerIp and length $adServerIp);

    my $adLdap = new Net::LDAP($adServerIp);
    my $rootDse = $adLdap->root_dse(attrs => $self->rootDseAttributes());
    my $defaultNC = $rootDse->get_value('defaultNamingContext');

    my $adDomain = $defaultNC;
    $adDomain =~ s/DC=//g;
    $adDomain =~ s/,/./g;

    unless (defined $adDomain) {
        throw EBox::Exceptions::External(
            __x('Could not determine the domain of the specified AD server {x}.',
                x => $adServerIp));
    }
    return $adDomain;
}

sub getADRealm
{
    my ($self, $adServerIp) = @_;

    throw EBox::Exceptions::MissingArgument('adServerIp')
        unless (defined $adServerIp and length $adServerIp);

    my $adLdap = new Net::LDAP($adServerIp);
    my $rootDse = $adLdap->root_dse(attrs => $self->rootDseAttributes());
    my $ldapPrinc = $rootDse->get_value('ldapServiceName');
    my (undef, $adRealm) = split(/@/, $ldapPrinc);

    unless (defined $adRealm) {
        throw EBox::Exceptions::External(
            __x('Could not determine the realm of the specified AD server {x}.',
                x => $adServerIp));
    }
    return $adRealm;
}

sub bindToADLdap
{
    my ($self, $adServerIp, $adUser, $adPwd) = @_;

    throw EBox::Exceptions::MissingArgument('adServerIp')
        unless (defined $adServerIp and length $adServerIp);
    throw EBox::Exceptions::MissingArgument('adUser')
        unless (defined $adUser and length $adUser);
    throw EBox::Exceptions::MissingArgument('adPwd')
        unless (defined $adPwd and length $adPwd);

    my $adDomain = $self->getADDomain($adServerIp);
    my $adLdap = new Net::LDAP($adServerIp);
    my $ldapMsg = $adLdap->bind("$adUser\@$adDomain", password => $adPwd);
    if ($ldapMsg->is_error()) {
        my $msg = __x('Could not bind to AD LDAP server ({x}).' .
                      'Please check the supplied credentials.',
                      x => $ldapMsg->error());
        throw EBox::Exceptions::External($msg);
    }
    return $adLdap;
}

# Method: checkDnsZonesInMainPartition
#
#   Checks that there aren't DNS zones stored in the main directory
#   partition (CN=MicrosoftDNS,CN=System,DC=...). On W2K the DomainDnsZones
#   and ForestDnsZones partitions didn't exists and zones were stored
#   there. The bind9 DLZ only has access to these partitions for security
#   reasons, so the DNS zones stored there must be moved to the DNS
#   partitions before join the domain. This is a corner case that only
#   affects when joinig to W2K (not supported) or servers upgraded from W2K
#
sub checkDnsZonesInMainPartition
{
    my ($self, $adServerIp, $adUser, $adPwd) = @_;

    throw EBox::Exceptions::MissingArgument('adServerIp')
        unless (defined $adServerIp and length $adServerIp);
    throw EBox::Exceptions::MissingArgument('adUser')
        unless (defined $adUser and length $adUser);
    throw EBox::Exceptions::MissingArgument('adPwd')
        unless (defined $adPwd and length $adPwd);

    EBox::info("Checking for old DNS zones stored in main domain partition...");
    my $adLdap = $self->bindToADLdap($adServerIp, $adUser, $adPwd);
    my $rootDse = $adLdap->root_dse(attrs => $self->rootDseAttributes());
    my $defaultNC = $rootDse->get_value('defaultNamingContext');

    my $ldapMsg = $adLdap->search(base => "CN=MicrosoftDNS,CN=System,$defaultNC",
                                  scope => 'sub',
                                  filter => '(objectClass=dnsZone)',
                                  attrs => ['name']);
    my @zoneNames;
    foreach my $entry ($ldapMsg->entries) {
        my $zoneName = $entry->get_value('name');
        next if (lc ($zoneName) eq lc ('RootDNSServers') or
                 lc ($zoneName) eq lc ('..TrustAnchors'));
        push (@zoneNames, $zoneName);
    }

    if (scalar @zoneNames > 0) {
        my $zoneNames = join (', ', @zoneNames);
        my $link = 'http://technet.microsoft.com/en-us/library/cc730964';
        my $msg = __x('Could not join to domain. The following DNS zones are ' .
                      'stored in the main domain partition: {zones}. ' .
                      'This normally happen when the server is upgraded from ' .
                      'Windows Server 2000, and Samba4 will not be able to read ' .
                      'these zones. Please, move the zones to the ' .
                      '"DomainDnsZones" or "ForestDnsZones" and try again. ' .
                      'Check {link} for help on how to do that.',
                      zones => $zoneNames, link => $link);
        throw EBox::Exceptions::External($msg);
    }
}

# Method: checkForestDomains
#
#   Check that the forest only contains one domain
#
sub checkForestDomains
{
    my ($self, $adServerIp, $adUser, $adPwd) = @_;

    throw EBox::Exceptions::MissingArgument('adServerIp')
        unless (defined $adServerIp and length $adServerIp);
    throw EBox::Exceptions::MissingArgument('adUser')
        unless (defined $adUser and length $adUser);
    throw EBox::Exceptions::MissingArgument('adPwd')
        unless (defined $adPwd and length $adPwd);

    EBox::info("Checking number of domains inside forest...");
    my $adLdap = $self->bindToADLdap($adServerIp, $adUser, $adPwd);
    my $rootDse = $adLdap->root_dse(attrs => $self->rootDseAttributes());
    my $configurationNC = $rootDse->get_value('configurationNamingContext');

    my $result = $adLdap->search(base => "CN=Partitions,$configurationNC",
                               scope => 'sub',
                               filter => '(objectClass=crossRef)',
                               attrs => ['systemFlags']);
    if ($result->code()) {
        throw EBox::Exceptions::External(
            __('Could not retrieve the domain information.'));
    }
    my $domainCount = 0;
    foreach my $entry ($result->entries()) {
        my $flags = $entry->get_value('systemFlags');
        $domainCount++ if ($flags & 0x00000002);
    }
    if ($domainCount > 1) {
        throw EBox::Exceptions::External(
        __('The AD forest contains more than one domain. Samba ' .
           'only support one domain per forest.'));
    }
    $adLdap->unbind();
}

# Method: checkServerReachable
#
#   Check that the AD server is alive and is reachable
#
sub checkServerReachable
{
    my ($self, $adServerIp) = @_;

    EBox::info("Checking if AD server '$adServerIp' is online...");
    my $pinger = new Net::Ping('tcp');
    $pinger->port_number(389);
    $pinger->service_check(1);
    unless ($pinger->ping($adServerIp)) {
        throw EBox::Exceptions::External(
            __x('The specified domain controller {x} is unreachable.',
                x => $adServerIp));
    }
    $pinger->close();
}

# If the host domain or the users kerberos realm does not
# match the domain we are trying to join warn the user and
# abort
sub checkLocalRealmAndDomain
{
    my ($self, $adServerIp) = @_;

    EBox::info("Checking local domain and realm...");
    my $usersModule = EBox::Global->modInstance('samba');
    my $krbRealm = $usersModule->kerberosRealm();
    my $adRealm = $self->getADRealm($adServerIp);
    unless (uc ($krbRealm) eq uc ($krbRealm)) {
        throw EBox::Exceptions::External(
            __x('The local kerberos realm {x} must match the ' .
                'AD server realm {y}.', x => $krbRealm, y => $adRealm));
    }

    my $sysinfo = EBox::Global->modInstance('sysinfo');
    my $hostDomain = $sysinfo->hostDomain();
    my $adDomain = $self->getADDomain($adServerIp);
    unless (lc ($hostDomain) eq lc ($adDomain)) {
        throw EBox::Exceptions::External(
            __x('The local domain {x} must match the AD server ' .
               'domain {y}.', x => $hostDomain, y => $adDomain));
    }
}

sub checkAddress
{
    my ($self, $adDnsServerIp, $adServerFQDN) = @_;

    throw EBox::Exceptions::MissingArgument('adDnsServerIp')
        unless (defined $adDnsServerIp and length $adDnsServerIp);
    throw EBox::Exceptions::MissingArgument('adServerFQDN')
        unless (defined $adServerFQDN and length $adServerFQDN);
    throw EBox::Exceptions::InvalidType('adDnsServerIp', 'IP Address')
        unless (EBox::Validate::checkIP($adDnsServerIp));

    my $adServerIp = undef;
    if (EBox::Validate::checkIP($adServerFQDN)) {
        $adServerIp = $adServerFQDN;
    } else {
        EBox::info("Resolving $adServerFQDN to an IP address");
        my $resolver = new Net::DNS::Resolver(nameservers => [$adDnsServerIp]);
        $resolver->tcp_timeout(5);
        $resolver->udp_timeout(5);
        my $answer = '';
        my $query = $resolver->query($adServerFQDN, 'A');
        if ($query) {
            foreach my $rr ($query->answer()) {
                next unless $rr->type() eq 'A';
                $answer = $rr->address();
                last;
            }
        }
        unless (defined $answer and length $answer) {
            throw EBox::Exceptions::External(
                __x('The DC {x} could not be resolved to its IP address. Please ' .
                    'check the specified server name and DNS server.',
                    x => $adServerFQDN));
        }
        $adServerIp = $answer;
        EBox::info("The DC $adServerFQDN has been resolved to $adServerIp");
    }

    EBox::info("Checking reverse DNS resolution of '$adServerIp'...");
    my $answer = '';
    my $resolver = new Net::DNS::Resolver(nameservers => ['127.0.0.1']);
    $resolver->tcp_timeout(5);
    $resolver->udp_timeout(5);
    my $target = join('.', reverse split(/\./, $adServerIp)).".in-addr.arpa";
    my $query = $resolver->query($target, 'PTR');
    if ($query) {
        foreach my $rr ($query->answer()) {
            next unless $rr->type() eq 'PTR';
            $answer = $rr->ptrdname();
            last;
        }
    }

    my $sysinfo = EBox::Global->modInstance('sysinfo');
    if (lc ($answer) eq lc ($sysinfo->fqdn())) {
        throw EBox::Exceptions::External(
            __x('The specified AD server is registered on the local DNS as ' .
                '{x}, which matches local host name.', x => $answer));
    }
    if (defined $answer and length $answer) {
        EBox::info("The IP address $adServerIp has been resolved to $answer");
    } else {
        EBox::info("The IP address $adServerIp does not have associated PTR record");
    }
    return $adServerIp;
}

sub checkFunctionalLevels
{
    my ($self, $adServerIp) = @_;

    EBox::info("Checking forest and domain functional levels...");
    my $adLdap = new Net::LDAP($adServerIp);
    my $rootDse = $adLdap->root_dse(attrs => $self->rootDseAttributes());
    my $forestLevel = $rootDse->get_value('forestFunctionality');
    unless ($forestLevel >= 2) {
        throw EBox::Exceptions::External(
            __('The forest functional level must be Windows Server 2003 ' .
               'or higher. Please raise your forest functional level.'));
    }
    my $domainLevel = $rootDse->get_value('domainFunctionality');
    unless ($domainLevel >= 2) {
        throw EBox::Exceptions::External(
            __('The domain functional level must be Windows Server 2003 ' .
               'or higher. Please raise your domain functional level.'));
    }
}

sub checkRfc2307
{
    my ($self, $adServerIp, $adUser, $adPwd) = @_;

    throw EBox::Exceptions::MissingArgument('adServerIp')
        unless (defined $adServerIp and length $adServerIp);
    throw EBox::Exceptions::MissingArgument('adUser')
        unless (defined $adUser and length $adUser);
    throw EBox::Exceptions::MissingArgument('adPwd')
        unless (defined $adPwd and length $adPwd);

    EBox::info("Checking RFC2307 compliant schema...");
    my $adLdap = $self->bindToADLdap($adServerIp, $adUser, $adPwd);
    my $rootDse = $adLdap->root_dse(attrs => $self->rootDseAttributes());
    my $schemaNC = $rootDse->get_value('schemaNamingContext');

    my $ldapMsg = $adLdap->search(base => $schemaNC,
                                  scope => 'one',
                                  filter => '(&(cn=PosixAccount)(objectClass=classSchema))',
                                  attrs => ['cn']);
    if ($ldapMsg->is_error()) {
        throw EBox::Exceptions::LDAP(
            message => __('Error querying AD schema:'),
            result  => $ldapMsg,
        );
    }
    if ($ldapMsg->count() <= 0) {
        # FIXME Tune the exception message.
        throw EBox::Exceptions::External(
            __('The domain schema does not meet RFC 2307. You will need to ' .
               'upgrade to Windows Server 2003 R2 or greater.'));
    }
}

sub checkTrustDomainObjects
{
    my ($self, $adServerIp, $adUser, $adPwd) = @_;

    throw EBox::Exceptions::MissingArgument('adServerIp')
        unless (defined $adServerIp and length $adServerIp);
    throw EBox::Exceptions::MissingArgument('adUser')
        unless (defined $adUser and length $adUser);
    throw EBox::Exceptions::MissingArgument('adPwd')
        unless (defined $adPwd and length $adPwd);

    EBox::info("Checking for domain trust relationships...");
    my $adLdap = $self->bindToADLdap($adServerIp, $adUser, $adPwd);
    my $rootDse = $adLdap->root_dse(attrs => $self->rootDseAttributes());
    my $defaultNC = $rootDse->get_value('defaultNamingContext');

    my $ldapMsg = $adLdap->search(base => "CN=System,$defaultNC",
                                  scope => 'sub',
                                  filter => '(objectClass=trustedDomain)',
                                  attrs => ['*']);
    if ($ldapMsg->count() > 0) {
        throw EBox::Exceptions::External(
            __('The domain you are trying to join has trust relationships defined. ' .
               'At the moment this is not supported by samba.'));
    }
}

# Method: checkClockSkew
#
#   Checks the clock skew with the remote AD server and throw exception
#   if the offset is above two minutes.
#
#   Maths:
#       Originate Timestamp     T1 - time request sent by client
#       Receive Timestamp       T2 - time request received by server
#       Transmit Timestamp      T3 - time reply sent by server
#       Destination Timestamp   T4 - time reply received by client
#
#       The roundtrip delay d and local clock offset t are defined as:
#       d = (T4 - T1) - (T2 - T3)
#       t = ((T2 - T1) + (T3 - T4)) / 2
#
sub checkClockSkew
{
    my ($self, $adServerIp) = @_;

    throw EBox::Exceptions::MissingArgument('adServerIp')
        unless (defined $adServerIp and length $adServerIp);

    my %h;
    try {
        EBox::info("Checking clock skew with AD server...");
        %h = get_ntp_response($adServerIp);
    } catch {
        throw EBox::Exceptions::External(
            __x('Could not retrieve time from AD server {x} via NTP.',
                x => $adServerIp));
    }

    my $t0 = time;
    my $T1 = $t0; # $h{'Originate Timestamp'};
    my $T2 = $h{'Receive Timestamp'};
    my $T3 = $h{'Transmit Timestamp'};
    my $T4 = time; # From Time::HiRes
    my $d = ($T4 - $T1) - ($T2 - $T3);
    my $t = (($T2 - $T1) + ($T3 - $T4)) / 2;
    unless (abs($t) < 120) {
        throw EBox::Exceptions::External(
            __('The clock skew with the AD server is higher than two minutes. ' .
               'This can cause problems with kerberos authentication, please ' .
               'sync both clocks with an external NTP source and try again.'));
    }
    EBox::info("Clock skew below two minutes, should be enough.");
}

sub checkADServerSite
{
    my ($self, $adServerIp, $adUser, $adPwd, $site) = @_;

    throw EBox::Exceptions::MissingArgument('adServerIp')
        unless (defined $adServerIp and length $adServerIp);
    throw EBox::Exceptions::MissingArgument('adUser')
        unless (defined $adUser and length $adUser);
    throw EBox::Exceptions::MissingArgument('adPwd')
        unless (defined $adPwd and length $adPwd);

    my $adLdap = $self->bindToADLdap($adServerIp, $adUser, $adPwd);
    my $rootDse = $adLdap->root_dse(attrs => $self->rootDseAttributes());
    my $adServerSite = undef;

    if (defined $site and length $site) {
        # If the user has specified a site, check it exists
        EBox::info("Checking if the specified site $site exists in the domain");
        my $configurationNC = $rootDse->get_value('configurationNamingContext');
        my $ldapMsg = $adLdap->search(base => "CN=Sites,$configurationNC",
                                      scope => 'sub',
                                      filter => '(objectClass=site)',
                                      attrs => ['name']);
        foreach my $entry ($ldapMsg->entries()) {
            my $name = $entry->get_value('name');
            if (lc ($name) eq lc ($site)) {
                $adServerSite = $name;
                last;
            }
        }
        unless (defined $adServerSite) {
            throw EBox::Exceptions::External(
                __x("The specified site {x} does not exists on the domain.",
                    x => $site));
        }
        EBox::info("The site $site has been found in the domain");
    } else {
        # Search the site of the given server
        EBox::info("Checking the site where the specified server is located");
        my $serverNameDn = $rootDse->get_value('serverName');
        my $dnParts = ldap_explode_dn($serverNameDn, reverse => 0);
        $adServerSite = @{$dnParts}[2]->{CN};
        unless (defined $adServerSite) {
            throw EBox::Exceptions::External(
                __("Could not determine the site of the specified server"));
        }
        EBox::info("The specified server has been located at site named $adServerSite");
    }

    return $adServerSite;
}

sub checkADNebiosName
{
    my ($self, $adServerIp, $adUser, $adPwd, $netbios) = @_;

    throw EBox::Exceptions::MissingArgument('adServerIp')
        unless (defined $adServerIp and length $adServerIp);
    throw EBox::Exceptions::MissingArgument('adUser')
        unless (defined $adUser and length $adUser);
    throw EBox::Exceptions::MissingArgument('adPwd')
        unless (defined $adPwd and length $adPwd);

    EBox::info("Checking domain netbios name...");
    my $adLdap = $self->bindToADLdap($adServerIp, $adUser, $adPwd);
    my $rootDse = $adLdap->root_dse(attrs => $self->rootDseAttributes());
    my $configurationNC = $rootDse->get_value('configurationNamingContext');
    my $result = $adLdap->search(base => "CN=Partitions,$configurationNC",
                                 scope => 'sub',
                                 filter => '(nETBIOSName=*)',
                                 attrs => ['nETBIOSName']);
    my $adNetbiosDomain = undef;
    if ($result->count() == 1) {
        my $entry = $result->entry(0);
        $adNetbiosDomain = $entry->get_value('nETBIOSName');
    }
    unless (defined $adNetbiosDomain) {
        throw EBox::Exceptions::External(
            __("Could not determine the netbios domain name."));
    }
    unless (uc ($adNetbiosDomain) eq uc ($netbios)) {
        throw EBox::Exceptions::External(
            __x('The netBIOS name {x} could not be found. Please check ' .
                'the specified value.', x => $netbios));
    }
    return $adNetbiosDomain;
}

# FIXME Workaround for samba bug #9200
sub _addForestDnsZonesReplica
{
    my ($self) = @_;

    EBox::info("Adding Forest Dns replica");
    my $usersModule = EBox::Global->modInstance('samba');
    my $ldap = $usersModule->ldap();
    my $basedn = $ldap->dn();
    my $dsServiceName = $ldap->rootDse->get_value('dsServiceName');

    my $params = {
        base => "CN=Partitions,CN=Configuration,$basedn",
        scope => 'one',
        filter => "(nCName=DC=ForestDnsZones,$basedn)",
        attrs => ['*'],
    };
    my $result = $ldap->search($params);
    unless ($result->count() == 1) {
        EBox::error("Could not found ForestDnsZones partition.");
        return;
    }
    my $entry = $result->entry(0);
    my @replicas = $entry->get_value('msDS-NC-Replica-Locations');
    foreach my $replica (@replicas) {
        return if (lc $replica eq lc $dsServiceName);
    }
    $entry->add('msDS-NC-Replica-Locations' => [ $dsServiceName ]);
    $entry->update($ldap->connection());
}

# FIXME Workaround for samba bug #9200
sub _addDomainDnsZonesReplica
{
    my ($self) = @_;

    EBox::info("Adding Domain Dns replica");
    my $usersModule = EBox::Global->modInstance('samba');
    my $ldap = $usersModule->ldap();
    my $basedn = $ldap->dn();
    my $dsServiceName = $ldap->rootDse->get_value('dsServiceName');

    my $params = {
        base => "CN=Partitions,CN=Configuration,$basedn",
        scope => 'one',
        filter => "(nCName=DC=DomainDnsZones,$basedn)",
        attrs => ['*'],
    };
    my $result = $ldap->search($params);
    unless ($result->count() == 1) {
        EBox::error("Could not found DomainDnsZones partition.");
        return;
    }
    my $entry = $result->entry(0);
    my @replicas = $entry->get_value('msDS-NC-Replica-Locations');
    foreach my $replica (@replicas) {
        return if (lc $replica eq lc $dsServiceName);
    }
    $entry->add('msDS-NC-Replica-Locations' => [ $dsServiceName ]);
    $entry->update($ldap->connection());
}

# Method: _waitForRidSetAllocation
#
#   After joining the domain, samba contact the RID manager FSMO role owner
#   to request a new RID pool. We have to wait for the response before
#   creating security objects in the LDB or the server will deny with
#   'unwilling to perform' error code until RID pool is allocated.
#
#   This function will block until a RID pool is allocated or timed
#   out.
#
sub _waitForRidPoolAllocation
{
    my ($self) = @_;

    my $allocated = 0;
    my $maxTries = 300;
    my $sleepSeconds = 0.1;

    my $usersModule = EBox::Global->modInstance('samba');
    my $ldap = $usersModule->ldap();

    # Get the server object, contained in the config NC, that represents
    # this DC
    my $serverNameDN = $ldap->rootDse->get_value('serverName');
    my $result = $ldap->search({
        base => $serverNameDN,
        scope => 'base',
        filter => '(objectClass=*)',
        attrs => ['serverReference']});
    unless ($result->count() == 1) {
        my $foundEntries = $result->count();
        my $errorStr = "Error getting the DN of the server object from root " .
                       "DSE. Expected one entry but got $foundEntries";
        throw EBox::Exceptions::Internal($errorStr);
    }
    my $serverObject = $result->entry(0);

    # Get the domain controller object representing this DC
    my $serverReferenceDN = $serverObject->get_value('serverReference');
    while (not $allocated and $maxTries > 0) {
        $result = $ldap->search({
            base => $serverReferenceDN,
            scope => 'base',
            filter => '(objectClass=*)',
            attrs => ['rIDSetReferences']});
        unless ($result->count() == 1) {
            my $foundEntries = $result->count();
            my $errorStr = "Error getting the DN of the domain controller " .
                           "object. Expected one entry but got $foundEntries";
            throw EBox::Exceptions::Internal($errorStr);
        }
        my $dcObject = $result->entry(0);

        # Get the list of references to RID set objects managing RID allocation
        my @ridSetReferencesDNs = $dcObject->get_value('rIDSetReferences');
        foreach my $ridSetReferenceDN (@ridSetReferencesDNs) {
            $result = $ldap->search({
                base => $ridSetReferenceDN,
                scope => 'base',
                filter => '(objectClass=*)',
                attrs => ['rIDAllocationPool']});
            unless ($result->count() == 1) {
                my $foundEntries = $result->count();
                my $errorStr = "Error getting the RID set object. Expected " .
                               "one entry but got $foundEntries";
                throw EBox::Exceptions::Internal($errorStr);
            }
            my $ridSetObject = $result->entry(0);

            # The rIDAllocationPool attribute is the pool that the DC will
            # switch to next, managed by RID Manager
            my $pool = $ridSetObject->get_value('ridAllocationPool');
            if (defined $pool) {
                $allocated = 1;
                last;
            }
        }

        $maxTries--;
        Time::HiRes::sleep($sleepSeconds);
    }
}

sub provisionADC
{
    my ($self) = @_;

    my $usersModule = EBox::Global->modInstance('samba');
    my $model = $usersModule->model('DomainSettings');
    my $domainToJoin = lc ($model->value('realm'));
    my $dcFQDN = $model->value('dcfqdn');
    my $adDnsServer = $model->value('dnsip');
    my $adUser = $model->value('adminAccount');
    my $adPwd = $model->value('password');
    my $netbiosDomain = $model->value('workgroup');
    my $site = $model->value('site');

    my $realm = $usersModule->kerberosRealm();

    # Resolve DC FQDN to an IP if needed
    my $adServerIp = $self->checkAddress($adDnsServer, $dcFQDN);

    # Check DC is reachable
    $self->checkServerReachable($adServerIp);

    # Check DC functional levels > 2000
    $self->checkFunctionalLevels($adServerIp);

    # Check RFC2307 compliant schema
    $self->checkRfc2307($adServerIp, $adUser, $adPwd);

    # Check local realm matchs remote one
    $self->checkLocalRealmAndDomain($adServerIp);

    # Check clock skew
    $self->checkClockSkew($adServerIp);

    # Check no DNS zones in main domain partition
    $self->checkDnsZonesInMainPartition($adServerIp, $adUser, $adPwd);

    # Check forest only contains one domain
    $self->checkForestDomains($adServerIp, $adUser, $adPwd);

    # Check there are not trust relationships between domains or forests
    $self->checkTrustDomainObjects($adServerIp, $adUser, $adPwd);

    # Check the AD site
    my $adServerSite = $self->checkADServerSite($adServerIp, $adUser, $adPwd, $site);

    # Check the netbios domain name
    my $adNetbiosDomain = $self->checkADNebiosName($adServerIp, $adUser, $adPwd, $netbiosDomain);

    my $dnsFile = undef;
    my $adminAccountPwdFile = undef;
    my $passwdFile;
    try {
        EBox::info("Joining to domain '$domainToJoin' as DC");
        # Set the domain DNS as the primary resolver. This will also let to get
        # the kerberos ticket for the admin account.
        EBox::debug("Setting domain DNS server '$adDnsServer' as the primary resolver");
        $dnsFile = new File::Temp(TEMPLATE => 'resolvXXXXXX',
                                  DIR      => EBox::Config::tmp());
        EBox::Sudo::root("cp /etc/resolvconf/interface-order $dnsFile",
                         'echo zentyal.temp > /etc/resolvconf/interface-order',
                         "echo 'search $domainToJoin\nnameserver $adDnsServer' | resolvconf -a zentyal.temp");

        # Get a ticket for admin User
        my $principal = "$adUser\@$realm";
        (undef, $adminAccountPwdFile) = tempfile(EBox::Config::tmp() . 'XXXXXX', CLEANUP => 1);
        EBox::info("Trying to get a kerberos ticket for principal '$principal'");
        write_file($adminAccountPwdFile, $adPwd);
        my $cmd = "kinit -e arcfour-hmac-md5 --password-file='$adminAccountPwdFile' '$principal'";
        EBox::Sudo::root($cmd);

        # Write config
        $usersModule->writeSambaConfig();

        # Join the domain
        EBox::info("Executing domain join");
        $passwdFile = $self->_createTmpPasswdFile($adPwd);
        my $cmd2 = "samba-tool domain join $domainToJoin DC " .
                   " --username='$adUser' " .
                   " --workgroup='$netbiosDomain' " .
                   " --password=`cat $passwdFile` " .
                   " --server='$adServerIp' " .
                   " --dns-backend=BIND9_DLZ " .
                   " --realm='$realm' " .
                   " --site='$adServerSite' ";

        EBox::Sudo::root($cmd2);
        unlink $passwdFile;

        $self->setProvisioned(1);
        $self->setupKerberos();
        $self->setupDNS();

        # Write SSS daemon configuration and force a restart
        $usersModule->_setupNSSPAM();

        # Start managed service to let it create the LDAP socket
        $usersModule->_startService();

        $self->_addForestDnsZonesReplica();
        $self->_addDomainDnsZonesReplica();

        # Wait for RID pool allocation
        EBox::info("Waiting RID pool allocation");
        $self->_waitForRidPoolAllocation();

        # Run Knowledge Consistency Checker (KCC) on remote DC
        EBox::info('Running KCC on remote DC');
        $cmd = "samba-tool drs kcc $dcFQDN " .
            " --username='$adUser' " .
            " --password='$adPwd' ";
        EBox::Sudo::rootWithoutException($cmd);

        # FIXME Load Zentyal service principals into samba
        #$usersModule->ldap->ldapServicePrincipalsToLdb();

        # Map accounts (SID -> Unix UID/GID numbers)
        $self->mapAccounts();

        EBox::debug('Hide internal groups');
        $self->_hideInternalGroups();
        EBox::debug('Hide internal users');
        $self->_hideInternalUsers();

        # Set kerberos modules as changed to force them to extract the keytab
        # and stash new password
        my $kerberosModules = EBox::Global->modInstancesOfType('EBox::Module::Kerberos');
        foreach my $mod (@{$kerberosModules}) {
            $mod->setAsChanged();
        }
    } catch ($e) {
        if ($passwdFile) {
            unlink $passwdFile;
        }
        $self->setProvisioned(0);
        $self->setupKerberos();
        $self->setupDNS();

        if (defined $dnsFile and -f $dnsFile) {
            EBox::Sudo::root("cp $dnsFile /etc/resolvconf/interface-order",
                             'resolvconf -d zentyal.temp');
            unlink $dnsFile;
        }
        if (defined $adminAccountPwdFile and -f $adminAccountPwdFile) {
            unlink $adminAccountPwdFile;
        }
        EBox::Sudo::rootWithoutException('kdestroy');

        $e->throw();
    }
    # Revert primary resolver changes
    if (defined $dnsFile and -f $dnsFile) {
        EBox::Sudo::root("cp $dnsFile /etc/resolvconf/interface-order",
                         'resolvconf -d zentyal.temp');
        unlink $dnsFile;
    }
    # Remove stashed password
    if (defined $adminAccountPwdFile and -f $adminAccountPwdFile) {
        unlink $adminAccountPwdFile;
    }
    # Destroy cached tickets
    EBox::Sudo::rootWithoutException('kdestroy');
}

# Method: _createGroupsContainer
#
#   Create the Groups Container at top level to improve usability
#   of the module if it does not exists
#
sub _createGroupsContainer
{
    my ($self) = @_;

    EBox::info("Creating default groups container");

    my $usersMod = EBox::Global->getInstance()->modInstance('samba');
    my $ldap = $usersMod->ldap();
    my $containerName = 'Groups';
    my $dn = "CN=$containerName," . $ldap->dn();

    my $param = {
        base => $dn,
        scope => 'one',
        filter => '(objectClass=container)',
    };
    my $result = $ldap->search($param);
    if ($result->count() > 0) {
        EBox::info("Groups container already exists, skip creation");
        return;
    }

    my %attr = (objectClass  => ['top', 'container'],
                cn           => $containerName,
                name         => $containerName,
                description  => 'Container to put the user groups',
                instanceType => 4);

    my $entry = new Net::LDAP::Entry($dn, %attr);
    $result = $entry->update($ldap->connection());
    if ($result->is_error()) {
        unless ($result->code() == LDAP_LOCAL_ERROR and $result->error() eq 'No attributes to update') {
            my @changes = $entry->changes();
            throw EBox::Exceptions::LDAP(
                message => __('Error on group container LDAP entry creation:'),
                result  => $result,
                opArgs  => "@changes",
               );
        };
    }
}

sub _hideInternalGroups
{
    my ($self) = @_;

    foreach my $group (qw(DnsAdmins DnsUpdateProxy)) {
        my $gr = new EBox::Samba::Group(samAccountName => $group);
        if ($gr->exists()) {
            $gr->set('showInAdvancedViewOnly', 'TRUE');
        }
    }
}

sub _hideInternalUsers
{
    my ($self) = @_;

    # Samba does not set the dns-<hostname> user as system critical when
    # joining a domain
    my $sysinfo = EBox::Global->modInstance('sysinfo');
    my $hostname = $sysinfo->hostName();
    my $dnsUser = "dns-$hostname";
    my $user = new EBox::Samba::User(samAccountName => $dnsUser);
    if ($user->exists()) {
        $user->setCritical(1);
    }
}

sub _createTmpPasswdFile
{
    my ($self, $pass) = @_;
    my ($FH, $passwdFile) = tempfile(EBox::Config::tmp() . 'XXXXXX', CLEANUP => 1);
    (print $FH $pass) or EBox::Exceptions::Internal->throw("Error closing temporal password file $!");
    close($FH) or EBox::Exceptions::Internal->throw("Error closing temporal password file $!");
    return $passwdFile;
}

1;
