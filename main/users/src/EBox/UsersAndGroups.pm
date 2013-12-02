# Copyright (C) 2008-2012 eBox Technologies S.L.
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

package EBox::UsersAndGroups;
use base qw(EBox::Module::Service
            EBox::LdapModule
            EBox::SysInfo::Observer
            EBox::UserCorner::Provider
            EBox::SyncFolders::Provider
            EBox::UsersAndGroups::SyncProvider
            EBox::Report::DiskUsageProvider);

use EBox::Global;
use EBox::Util::Random;
use EBox::Ldap;
use EBox::Gettext;
use EBox::Menu::Folder;
use EBox::Menu::Item;
use EBox::Sudo;
use EBox::FileSystem;
use EBox::LdapUserImplementation;
use EBox::Config;
use EBox::UsersAndGroups::Slave;
use EBox::UsersAndGroups::User;
use EBox::UsersAndGroups::Group;
use EBox::UsersAndGroups::OU;
use EBox::UsersSync::Master;
use EBox::UsersSync::Slave;
use EBox::CloudSync::Slave;
use EBox::Exceptions::UnwillingToPerform;
use EBox::Exceptions::LDAP;
use EBox::SyncFolders::Folder;
use EBox::Util::Version;

use Digest::SHA;
use Digest::MD5;
use Sys::Hostname;

use Error qw(:try);
use File::Copy;
use File::Slurp;
use File::Temp qw/tempfile/;
use Perl6::Junction qw(any);
use String::ShellQuote;
use Time::HiRes;
use Fcntl qw(:flock);

use constant USERSDN        => 'ou=Users';
use constant GROUPSDN       => 'ou=Groups';
use constant COMPUTERSDN    => 'ou=Computers';

use constant LIBNSS_LDAPFILE => '/etc/ldap.conf';
use constant LIBNSS_SECRETFILE => '/etc/ldap.secret';
use constant DEFAULTGROUP   => '__USERS__';
use constant JOURNAL_DIR    => EBox::Config::home() . 'syncjournal/';
use constant AUTHCONFIGTMPL => '/etc/auth-client-config/profile.d/acc-zentyal';
use constant MAX_SB_USERS   => 25;
use constant CRONFILE       => '/etc/cron.d/zentyal-users';

use constant LDAP_CONFDIR    => '/etc/ldap/slapd.d/';
use constant LDAP_DATADIR    => '/var/lib/ldap/';
use constant LDAP_USER     => 'openldap';
use constant LDAP_GROUP    => 'openldap';

# Kerberos constants
use constant KERBEROS_PORT => 8880;
use constant KPASSWD_PORT => 8464;
use constant KRB5_CONF_FILE => '/etc/krb5.conf';
use constant KDC_CONF_FILE  => '/etc/heimdal-kdc/kdc.conf';
use constant KDC_DEFAULT_FILE => '/etc/default/heimdal-kdc';

sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'users',
                                      printableName => __('Users and Groups'),
                                      @_);
    bless($self, $class);
    return $self;
}

# Method: depends
#
#     Users depends on dns only to ensure proper order during
#     save changes when reprovisioning (after host/domain change)
#
# Overrides:
#
#     <EBox::Module::Base::depends>
#
sub depends
{
    my ($self) = @_;

    my @deps;

    if ($self->get('need_reprovision')) {
        push (@deps, 'dns');
    }

    return \@deps;
}

# Method: actions
#
#       Override EBox::ServiceModule::ServiceInterface::actions
#
sub actions
{
    my ($self) = @_;

    my @actions;

    push(@actions,
            {
            'action' => __('Your LDAP database will be populated with some basic organizational units'),
            'reason' => __('Zentyal needs this organizational units to add users and groups into them.'),
            'module' => 'users'
            },
        );

    # FIXME: This probably won't work if PAM is enabled after enabling the module
    if ($self->model('PAM')->enable_pamValue()) {
        push(@actions,
                {
                 'action' => __('Configure PAM.'),
                 'reason' => __('Zentyal will give LDAP users system account.'),
                 'module' => 'users'
                }
        );
    }
    return \@actions;
}

# Method: usedFiles
#
#       Override EBox::Module::Service::files
#
sub usedFiles
{
    my ($self) = @_;
    my @files = ();

    push(@files,
        {
            'file' => '/etc/nsswitch.conf',
            'reason' => __('To make NSS use LDAP resolution for user and '.
                'group accounts. Needed for Samba PDC configuration.'),
            'module' => 'users'
        },
        {
            'file' => LIBNSS_LDAPFILE,
            'reason' => __('To let NSS know how to access LDAP accounts.'),
            'module' => 'users'
        },
        {
            'file' => '/etc/fstab',
            'reason' => __('To add quota support to /home partition.'),
            'module' => 'users'
        },
        {
            'file' => '/etc/default/slapd',
            'reason' => __('To make LDAP listen on TCP and Unix sockets.'),
            'module' => 'users'
        },
        {
            'file' => LIBNSS_SECRETFILE,
            'reason' => __('To copy LDAP admin password generated by ' .
                'Zentyal and allow other modules to access LDAP.'),
            'module' => 'users'
        },
        {
            'file' => KRB5_CONF_FILE,
            'reason' => __('To set up kerberos authentication'),
            'module' => 'users'
        },
        {
            'file' => KDC_CONF_FILE,
            'reason' => __('To set up the kerberos KDC'),
            'module' => 'users'
        },
        {
            'file' => KDC_DEFAULT_FILE,
            'reason' => __('To set the KDC configuration'),
            'module' => 'users',
        },
    );

    return \@files;
}

# Method: initialSetup
#
# Overrides:
#
#   EBox::Module::Base::initialSetup
#
sub initialSetup
{
    my ($self, $version) = @_;

    # Create default rules and services
    # only if installing the first time
    unless ($version) {
        my $services = EBox::Global->modInstance('services');
        my $fw = EBox::Global->modInstance('firewall');

        my $serviceName = 'ldap';
        unless ($services->serviceExists(name => $serviceName)) {
            $services->addMultipleService(
                'name' => $serviceName,
                'printableName' => 'LDAP',
                'description' => __('Lightweight Directory Access Protocol'),
                'readOnly' => 1,
                'services' => [ { protocol   => 'tcp',
                                  sourcePort => 'any',
                                  destinationPort => 390 } ],
            );

            $fw->setInternalService($serviceName, 'deny');
        }

        $serviceName = 'kerberos';
        unless ($services->serviceExists(name => $serviceName)) {
            $services->addMultipleService(
                'name' => $serviceName,
                'printableName' => 'Kerberos',
                'description' => __('Kerberos authentication'),
                'readOnly' => 1,
                'services' => [ { protocol   => 'tcp/udp',
                                  sourcePort => 'any',
                                  destinationPort => KERBEROS_PORT },
                                { protocol   => 'tcp/udp',
                                  sourcePort => 'any',
                                  destinationPort => KPASSWD_PORT } ]
            );
            $fw->setInternalService($serviceName, 'accept');
        }
        $fw->saveConfigRecursive();
    }

    if (defined ($version) and (EBox::Util::Version::compare($version, '3.0.14') < 0) and $self->configured()) {
        my %kerberosPrincipals = (
            dns => 1,
            mail => 1,
            proxy => 1,
            zarafa => 1,
        );
        my $hostname = EBox::Global->modInstance('sysinfo')->hostName();
        foreach my $prefix (keys %kerberosPrincipals) {
            my $principalUser = "$prefix-$hostname";
            if ($self->userExists($principalUser)) {
                my $user = EBox::UsersAndGroups::User->new(uid => $principalUser);
                $user->set('title', 'internal');
            }
        }
    }
    if (defined ($version) and (EBox::Util::Version::compare($version, '3.0.17') < 0)) {
        if (not $self->get('need_reprovision')) {
            # previous versions could left a leftover ro/need_reprovision which
            # could force reprovision on reboot
            my $roKey = 'users/ro/need_reprovision';
            $self->redis->unset($roKey);
        }
    }

    # Execute initial-setup script
    $self->SUPER::initialSetup($version);
}

sub setupKerberos
{
    my ($self) = @_;

    my $realm = $self->kerberosRealm();
    EBox::info("Initializing kerberos realm '$realm'");

    my @cmds = ();
    push (@cmds, 'invoke-rc.d heidmal-kdc stop || true');
    push (@cmds, 'stop zentyal.heimdal-kdc || true');
    push (@cmds, 'invoke-rc.d kpasswdd stop || true');
    push (@cmds, 'stop zentyal.heimdal-kpasswd || true');
    push (@cmds, 'sudo sed -e "s/^kerberos-adm/#kerberos-adm/" /etc/inetd.conf -i') if EBox::Sudo::fileTest('-f', '/etc/inetd.conf');
    push (@cmds, "ln -sf /etc/heimdal-kdc/kadmind.acl /var/lib/heimdal-kdc/kadmind.acl");
    push (@cmds, "ln -sf /etc/heimdal-kdc/kdc.conf /var/lib/heimdal-kdc/kdc.conf");
    push (@cmds, "rm -f /var/lib/heimdal-kdc/m-key");
    push (@cmds, "kadmin -l init --realm-max-ticket-life=unlimited --realm-max-renewable-life=unlimited $realm");
    push (@cmds, 'rm -f /etc/kpasswdd.keytab');
    push (@cmds, "kadmin -l ext -k /etc/kpasswdd.keytab kadmin/changepw\@$realm"); #TODO Only if master
    push (@cmds, 'chmod 600 /etc/kpasswdd.keytab'); # TODO Only if master
    EBox::Sudo::root(@cmds);

    $self->setupDNS();
}

sub setupDNS
{
    my ($self) = @_;

    EBox::info("Setting up DNS");

    # Get the host domain
    my $sysinfo = EBox::Global->modInstance('sysinfo');
    my $ownDomain = $sysinfo->hostDomain();
    my $hostName = $sysinfo->hostName();

    # Create the domain in the DNS module if it does not exists
    my $dnsMod = EBox::Global->modInstance('dns');
    my $domainModel = $dnsMod->model('DomainTable');
    my $row = $domainModel->find(domain => $ownDomain);
    if (defined $row) {
        # Set the domain as managed and readonly
        $row->setReadOnly(1);
        $row->elementByName('managed')->setValue(1);
        $row->store();
    } else {
        $domainModel->addRow(domain => $ownDomain, managed => 1, readOnly => 1);
    }

    EBox::debug("Adding DNS records for kerberos");

    # Add the TXT record with the realm name
    my $txtRR = { name => '_kerberos',
                  data => $ownDomain,
                  readOnly => 1 };
    $dnsMod->addText($ownDomain, $txtRR);

    # Add the SRV records to the domain
    my $service = { service => 'kerberos',
                    protocol => 'tcp',
                    port => KERBEROS_PORT,
                    priority => 100,
                    weight => 100,
                    target_type => 'domainHost',
                    target => $hostName,
                    readOnly => 1 };
    $dnsMod->addService($ownDomain, $service);
    $service->{protocol} = 'udp';
    $dnsMod->addService($ownDomain, $service);

    ## TODO Check if the server is a master or slave and adjust the target
    ##      to the master server
    $service = { service => 'kerberos-master',
                 protocol => 'tcp',
                 port => KERBEROS_PORT,
                 priority => 100,
                 weight => 100,
                 target_type => 'domainHost',
                 target => $hostName,
                 readOnly => 1 };
    $dnsMod->addService($ownDomain, $service);
    $service->{protocol} = 'udp';
    $dnsMod->addService($ownDomain, $service);

    $service = { service => 'kpasswd',
                 protocol => 'tcp',
                 port => KPASSWD_PORT,
                 priority => 100,
                 weight => 100,
                 target_type => 'domainHost',
                 target => $hostName,
                 readOnly => 1 };
    $dnsMod->addService($ownDomain, $service);
    $service->{protocol} = 'udp';
    $dnsMod->addService($ownDomain, $service);
}

# Method: enableActions
#
#   Override EBox::Module::Service::enableActions
#
sub enableActions
{
    my ($self) = @_;

    # Stop slapd daemon
    EBox::Sudo::root(
        'invoke-rc.d slapd stop || true',
        'stop ebox.slapd        || true',
        'cp /usr/share/zentyal-users/slapd.default.no /etc/default/slapd'
    );

    my $dn = $self->model('Mode')->dnValue();
    my $password = $self->_genPassword(EBox::Config::conf() . 'ldap.passwd');
    my $password_ro = $self->_genPassword(EBox::Config::conf() . 'ldap_ro.passwd');
    my $opts = [
        'dn' => $dn,
        'password' => $password,
        'password_ro' => $password_ro,
    ];

    # Prepare ldif files
    my $LDIF_CONFIG = EBox::Config::tmp() . "slapd-config.ldif";
    my $LDIF_DB = EBox::Config::tmp() . "slapd-database.ldif";

    EBox::Module::Base::writeConfFileNoCheck($LDIF_CONFIG, "users/config.ldif.mas", $opts);
    EBox::Module::Base::writeConfFileNoCheck($LDIF_DB, "users/database.ldif.mas", $opts);

    # Preload base LDAP data
    $self->_loadLDAP($dn, $LDIF_CONFIG, $LDIF_DB);
    $self->_manageService('start');

    $self->ldap->clearConn();

    # Setup NSS (needed if some user is added before save changes)
    $self->_setConf(1);

    # Create default group
    EBox::UsersAndGroups::Group->create(DEFAULTGROUP, 'All users', 1);

    # Perform LDAP actions (schemas, indexes, etc)
    EBox::info('Performing first LDAP actions');
    try {
        $self->performLDAPActions();
    } otherwise {
        my $error = shift;
        EBox::error("Error performing users initialization: $error");
        throw EBox::Exceptions::External(__('Error performing users initialization'));
    };

    # Setup kerberos realm and DNS
    $self->setupKerberos();

    # Execute enable-module script
    $self->SUPER::enableActions();

    # Configure SOAP to listen for new slaves
    $self->masterConf->confSOAPService();
    $self->masterConf->setupMaster();

    # mark apache as changed to avoid problems with getpwent calls, it needs
    # to be restarted to be aware of the new nsswitch conf
    EBox::Global->modInstance('apache')->setAsChanged();
}

sub enableService
{
    my ($self, $status) = @_;

    $self->SUPER::enableService($status);

    # Set up NSS, modules depending on users may require to retrieve uid/gid
    # numbers from LDAP
    if ($status) {
        $self->_setConf(1);
    }
}

sub _startDaemon
{
    my ($self, $daemon, %params) = @_;

    $self->SUPER::_startDaemon($daemon, %params);

    my $services = $self->_services($daemon->{name});
    foreach my $service (@{$services}) {
        my $port = $service->{destinationPort};
        next unless $port;

        my $proto = $service->{protocol};
        next unless $proto;

        my $desc = $service->{description};
        if ($proto eq 'tcp/udp') {
            $self->_waitService('tcp', $port, $desc);
            $self->_waitService('udp', $port, $desc);
        } elsif (($proto eq 'tcp') or ($proto eq 'udp')) {
            $self->_waitService($proto, $port, $desc);
        }
    }
}

# Method: _waitService
#
#   This function will block until service is listening or timed
#   out (300 * 0.1 = 30 seconds)
#
sub _waitService
{
    my ($self, $proto, $port, $desc) = @_;

    my $maxTries = 300;
    my $sleepSeconds = 0.1;
    my $listening = 0;

    if (length ($desc)) {
        EBox::debug("Wait users task '$desc'");
    } else {
        EBox::debug("Wait unknown users task");
    }
    while (not $listening and $maxTries > 0) {
        my $sock = new IO::Socket::INET(PeerAddr => '127.0.0.1',
                                        PeerPort => $port,
                                        Proto    => $proto);
        if ($sock) {
            $listening = 1;
            last;
        }
        $maxTries--;
        Time::HiRes::sleep($sleepSeconds);
    }

    unless ($listening) {
        EBox::warn("Timeout reached while waiting for users service '$desc' ($proto)");
    }
}

sub _services
{
    my ($self, $daemon) = @_;
    my @services = ();

    if ($daemon eq 'ebox.slapd') {
        # LDAP
        push (@services, {
            'protocol' => 'tcp',
            'sourcePort' => 'any',
            'destinationPort' => '390',
            'description' => 'Lightweight Directory Access Protocol',
        });
    } elsif ($daemon eq 'zentyal.heimdal-kdc') {
        # KDC
        push (@services, {
            'protocol' => 'tcp/udp',
            'sourcePort' => 'any',
            'destinationPort' => KERBEROS_PORT,
            'description' => 'Kerberos Key Distribution Center',
        });
    } elsif ($daemon eq 'zentyal.heimdal-kpasswd') {
        # KPASSWD
        push (@services, {
            'protocol' => 'udp',
            'sourcePort' => 'any',
            'destinationPort' => KPASSWD_PORT,
            'description' => 'Kerberos Password Changing Server',
        });
    }

    return \@services;
}

# Load LDAP from config + data files
sub _loadLDAP
{
    my ($self, $dn, $LDIF_CONFIG, $LDIF_DB) = @_;
    EBox::info('Creating LDAP database...');
    try {
        EBox::Sudo::root(
            # Remove current database (if any)
            'rm -f /var/lib/heimdal-kdc/m-key',
            'rm -rf ' . LDAP_CONFDIR . ' ' . LDAP_DATADIR,
            'mkdir -p ' . LDAP_CONFDIR . ' ' . LDAP_DATADIR,
            'chmod 750 ' . LDAP_CONFDIR . ' ' . LDAP_DATADIR,

            # Create database (config + structure)
            'slapadd -F ' . LDAP_CONFDIR . " -b cn=config -l $LDIF_CONFIG",
            'slapadd -F ' . LDAP_CONFDIR . " -b $dn -l $LDIF_DB",

            # Fix permissions and clean temp files
            'chown -R openldap.openldap ' . LDAP_CONFDIR . ' ' . LDAP_DATADIR,
            "rm -f $LDIF_CONFIG $LDIF_DB",
        );
    } catch EBox::Exceptions::Sudo::Command with {
        my $exception = shift;
        EBox::error('Trying to setup ldap failed, exit value: ' .
                $exception->exitValue());
        throw EBox::Exceptions::External(__('Error while creating users and groups database.'));
    } otherwise {
        my $error = shift;
        EBox::error("Trying to setup ldap failed: $error");
    };
    EBox::debug('done');
}

# Generate, store in the given file and return a password
sub _genPassword
{
    my ($self, $file) = @_;

    my $pass = EBox::Util::Random::generate(20);
    my ($login,$password,$uid,$gid) = getpwnam('ebox');
    EBox::Module::Base::writeFile($file, $pass,
            { mode => '0600', uid => $uid, gid => $gid });

    return $pass;
}


# Method: wizardPages
#
#   Override EBox::Module::Base::wizardPages
#
sub wizardPages
{
    my ($self) = @_;
    return [{ page => '/UsersAndGroups/Wizard/Users', order => 300 }];
}


# Method: _setConf
#
#       Override EBox::Module::Service::_setConf
#
sub _setConf
{
    my ($self, $noSlaveSetup) = @_;

    if ($self->get('need_reprovision')) {
        $self->unset('need_reprovision');
        # workaround  a orphan need_reprovision on read-only
        my $roKey = 'users/ro/need_reprovision';
        $self->redis->unset($roKey);
        $self->reprovision();
    }

    my $ldap = $self->ldap;
    EBox::Module::Base::writeFile(LIBNSS_SECRETFILE, $ldap->getPassword(),
        { mode => '0600', uid => 0, gid => 0 });

    my $dn = $ldap->dn;
    my $nsspw = $ldap->getRoPassword();
    my @array = ();
    push (@array, 'ldap' => EBox::Ldap::LDAPI);
    push (@array, 'basedc'    => $dn);
    push (@array, 'binddn'    => $ldap->roRootDn());
    push (@array, 'rootbinddn'=> $ldap->rootDn());
    push (@array, 'bindpw'    => $nsspw);
    push (@array, 'usersdn'   => USERSDN . ',' . $dn);
    push (@array, 'groupsdn'  => GROUPSDN . ',' . $dn);
    push (@array, 'computersdn' => COMPUTERSDN . ',' . $dn);

    $self->writeConfFile(LIBNSS_LDAPFILE, "users/ldap.conf.mas",
            \@array);

    $self->_setupNSSPAM();

    # Slaves cron
    @array = ();
    push(@array, 'slave_time' => EBox::Config::configkey('slave_time'));
    if ($self->master() eq 'cloud') {
        my $rs = new EBox::Global->modInstance('remoteservices');
        my $rest = $rs->REST();
        my $res = $rest->GET("/v1/users/realm/")->data();
        my $realm = $res->{realm};

        # Initial sync, set the realm (definitive) and upload current users
        if (not $realm) {
            $rest->PUT("/v1/users/realm/", query => { realm => $self->kerberosRealm() });

            # Send current users and groups
            $self->initialSlaveSync(new EBox::CloudSync::Slave(), 1);
        }

        push(@array, 'cloudsync_enabled' => 1);
    }
    $self->writeConfFile(CRONFILE, "users/zentyal-users.cron.mas", \@array);

    # Configure as slave if enabled
    $self->masterConf->setupSlave() unless ($noSlaveSetup);

    # Configure soap service
    $self->masterConf->confSOAPService();

    # commit slaves removal
    EBox::UsersAndGroups::Slave->commitRemovals($self->global());

    # Get the FQDN
    my $realm = $self->kerberosRealm();
    @array = ();
    push (@array, 'realm' => $realm);
    $self->writeConfFile(KRB5_CONF_FILE, 'users/krb5.conf.mas', \@array);

    my $ldapBase = $self->ldap->dn();
    @array = ();
    push (@array, 'ldapBase' => $ldapBase);
    push (@array, 'realm' => $realm);
    $self->writeConfFile(KDC_CONF_FILE, 'users/kdc.conf.mas', \@array);

    @array = ();
    $self->writeConfFile(KDC_DEFAULT_FILE, 'users/heimdal-kdc.mas', \@array);
}

# overriden to revoke slave removals
sub revokeConfig
{
   my ($self) = @_;
   $self->SUPER::revokeConfig();
   EBox::UsersAndGroups::Slave->revokeRemovals($self->global());
}

sub kerberosRealm
{
    my ($self) = @_;

    my $sysinfo = EBox::Global->modInstance('sysinfo');
    my $realm = uc ($sysinfo->hostDomain());
    return $realm;
}

sub _setupNSSPAM
{
    my ($self) = @_;

    my @array = ();
    my $umask = EBox::Config::configkey('dir_umask');
    push (@array, 'umask' => $umask);

    $self->writeConfFile(AUTHCONFIGTMPL, 'users/acc-zentyal.mas',
               \@array);

    my $enablePam = $self->model('PAM')->enable_pamValue();
    my $cmd;
    if ($enablePam) {
        $cmd = 'auth-client-config -a -p zentyal-krb';
    } else {
        $cmd = 'auth-client-config -a -p zentyal-nokrb';
    }
    EBox::Sudo::root($cmd);
}

# Method: editableMode
#
#       Check if users and groups can be edited.
#
#       Returns true if mode is master
#
sub editableMode
{
    my ($self) = @_;

    my $global = EBox::Global->modInstance('global');
    my @names = @{$global->modNames};

    my @modules;
    foreach my $name (@names) {
        my $mod = EBox::Global->modInstance($name);

        if ($mod->isa('EBox::UsersAndGroups::SyncProvider')) {
            return 0 unless ($mod->allowUserChanges());
        }
    }

    return 1;
}

# Method: _daemons
#
#       Override EBox::Module::Service::_daemons
#
sub _daemons
{
    my ($self) = @_;

    return [
        { name => 'ebox.slapd' },
        { name => 'zentyal.heimdal-kdc'  },
        { name => 'zentyal.heimdal-kpasswd'  },
    ];
}

# Method: _enforceServiceState
#
#       Override EBox::Module::Service::_enforceServiceState
#
sub _enforceServiceState
{
    my ($self) = @_;
    $self->SUPER::_enforceServiceState();

    # Clear LDAP connection
    $self->ldap->clearConn();
}

# Method: groupsDn
#
#       Returns the dn where the groups are stored in the ldap directory
#       Accepts an optional parameter as base dn instead of getting it
#       from the local LDAP repository
#
# Returns:
#
#       string - dn
#
sub groupsDn
{
    my ($self, $dn) = @_;
    unless(defined($dn)) {
        $dn = $self->ldap->dn();
    }
    return GROUPSDN . "," . $dn;
}


# Method: groupDn
#
#    Returns the dn for a given group. The group doesn't have to exist
#
#   Parameters:
#       group
#
#  Returns:
#     dn for the group
sub groupDn
{
    my ($self, $group) = @_;
    $group or throw EBox::Exceptions::MissingArgument('group');

    my $dn = "cn=$group," .  $self->groupsDn;
    return $dn;
}

# Method: usersDn
#
#       Returns the dn where the users are stored in the ldap directory.
#       Accepts an optional parameter as base dn instead of getting it
#       from the local LDAP repository
#
# Returns:
#
#       string - dn
#
sub usersDn
{
    my ($self, $dn) = @_;
    unless(defined($dn)) {
        $dn = $self->ldap->dn();
    }
    return USERSDN . "," . $dn;
}

# Method: userDn
#
#    Returns the dn for a given user. The user doesn't have to exist
#
#   Parameters:
#       user
#
#  Returns:
#     dn for the user
sub userDn
{
    my ($self, $user) = @_;
    $user or throw EBox::Exceptions::MissingArgument('user');

    my $dn = "uid=$user," .  $self->usersDn;
    return $dn;
}



# Init a new user (home and permissions)
sub initUser
{
    my ($self, $user, $password) = @_;

    my $mk_home = EBox::Config::configkey('mk_home');
    $mk_home = 'yes' unless $mk_home;
    if ($mk_home eq 'yes') {
        my $home = $user->home();
        if ($home and ($home ne '/dev/null') and (not -e $home)) {
            my @cmds;

            my $quser = shell_quote($user->name());
            my $qhome = shell_quote($home);
            my $group = DEFAULTGROUP;
            push(@cmds, "mkdir -p `dirname $qhome`");
            push(@cmds, "cp -dR --preserve=mode /etc/skel $qhome");
            EBox::Sudo::root(@cmds);

            my $chownCmd = "chown -R $quser:$group $qhome";
            EBox::Sudo::root($chownCmd);

            my $dir_umask = oct(EBox::Config::configkey('dir_umask'));
            my $perms = sprintf("%#o", 00777 &~ $dir_umask);
            my $chmod = "chmod $perms $qhome";
            EBox::Sudo::root($chmod);
        }
    }
}

# Reload nscd daemon if it's installed
sub reloadNSCD
{
    if ( -f '/etc/init.d/nscd' ) {
        try {
            EBox::Sudo::root('/etc/init.d/nscd force-reload');
        } otherwise {};
   }
}

# Method: user
#
# Returns the object which represents a give user. Raises a exception if
# the user does not exists
#
#  Parameters:
#      username
#
#  Returns:
#    the instance of EBox::UsersAndGroups::User for the given user
sub user
{
    my ($self, $username) = @_;
    my $dn = $self->userDn($username);
    my $user = new EBox::UsersAndGroups::User(dn => $dn);
    if (not $user->exists()) {
        throw EBox::Exceptions::DataNotFound(data => __('user'), value => $username);
    }
    return $user;
}

# Method: userExists
#
# Returns:
#
#   bool - whether the user exists or not
#
sub userExists
{
    my ($self, $username) = @_;
    my $dn = $self->userDn($username);
    my $user = new EBox::UsersAndGroups::User(dn => $dn);
    return $user->exists();
}

# Method: users
#
#       Returns an array containing all the users (not system users)
#
# Parameters:
#       system - show system users also (default: false)
#
# Returns:
#
#       array ref - holding the users. Each user is represented by a
#       EBox::UsersAndGroups::User object
#
sub users
{
    my ($self, $system) = @_;

    return [] if (not $self->isEnabled());

    my %args = (
        base => $self->ldap->dn(),
        filter => 'objectclass=posixAccount',
        scope => 'sub',
    );

    my $result = $self->ldap->search(\%args);

    my @users = ();
    foreach my $entry ($result->entries)
    {
        my $user = new EBox::UsersAndGroups::User(entry => $entry);

        # Include system users?
        next if (not $system and $user->system());

        push (@users, $user);
    }

    # sort by name
    @users = sort {
            my $aValue = $a->name();
            my $bValue = $b->name();
            (lc $aValue cmp lc $bValue) or
                ($aValue cmp $bValue)
    } @users;

    return \@users;
}

# Method: realUsers
#
#       Returns an array containing all the non-internal users
#
# Parameters:
#
#       withoutAdmin - filter Samba 'Administrator' user (default: false)
#
# Returns:
#
#       array ref - holding the users. Each user is represented by a
#       EBox::UsersAndGroups::User object
#
sub realUsers
{
    my ($self, $withoutAdmin) = @_;

    my @users = grep { not $_->internal() } @{$self->users()};

    if ($withoutAdmin) {
        @users = grep { $_->name() ne 'Administrator' } @users;
    }

    return \@users;
}

# Method: group
#
# Returns the object which represents a give group. Raises a exception if
# the group does not exists
#
#  Parameters:
#      groupname
#
#  Returns:
#    the instance of EBox::UsersAndGroups::Group for the group
sub group
{
    my ($self, $groupname) = @_;
    my $dn = $self->groupDn($groupname);
    my $group = new EBox::UsersAndGroups::Group(dn => $dn);
    if (not $group->exists()) {
        throw EBox::Exceptions::DataNotFound(data => __('group'), value => $groupname);
    }
    return $group;
}

# Method: groupExists
#
#  Returns:
#
#      bool - whether the group exists or not
#
sub groupExists
{
    my ($self, $groupname) = @_;
    my $dn = $self->groupDn($groupname);
    my $group = new EBox::UsersAndGroups::Group(dn => $dn);
    return $group->exists();
}

# Method: groups
#
#       Returns an array containing all the groups
#
#   Parameters:
#       system - show system groups (default: false)
#
# Returns:
#
#       array - holding the groups as EBox::UsersAndGroups::Group objects
#
sub groups
{
    my ($self, $system) = @_;

    return [] if (not $self->isEnabled());

    my %args = (
        base => $self->ldap->dn(),
        filter => 'objectclass=zentyalGroup',
        scope => 'sub',
    );

    my $result = $self->ldap->search(\%args);

    my @groups = ();
    foreach my $entry ($result->entries())
    {
        my $group = new EBox::UsersAndGroups::Group(entry => $entry);

        # Include system users?
        next if (not $system and $group->system());

        push (@groups, $group);
    }
    # sort grups by name
    @groups = sort {
        my $aValue = $a->name();
        my $bValue = $b->name();
        (lc $aValue cmp lc $bValue) or
            ($aValue cmp $bValue)
    } @groups;

    return \@groups;
}


sub multipleOusEnabled
{
    return EBox::Config::configkey('multiple_ous');
}

# Method: ous
#
#       Returns an array containing all the OUs
#
# Returns:
#
#       array ref - holding the OUs
#
sub ous
{
    my ($self) = @_;

    return [] if (not $self->isEnabled());

    my %args = (
        base => $self->ldap->dn(),
        filter => 'objectclass=organizationalUnit',
        scope => 'sub',
    );

    my $result = $self->ldap->search(\%args);

    my @ous = ();
    foreach my $entry ($result->entries())
    {
        my $ou = new EBox::UsersAndGroups::OU(entry => $entry);
        push (@ous, $ou);
    }

    return \@ous;
}


# Method: _modsLdapUserbase
#
# Returns modules implementing LDAP user base interface
#
# Parameters:
#   ignored_modules (Optional) - array ref to a list of module names to ignore
#
sub _modsLdapUserBase
{
    my ($self, $ignored_modules) = @_;

    my $global = EBox::Global->modInstance('global');
    my @names = @{$global->modNames};

    $ignored_modules or $ignored_modules = [];

    my @modules;
    foreach my $name (@names) {
        next if ($name eq any @{$ignored_modules});

        my $mod = EBox::Global->modInstance($name);

        if ($mod->isa('EBox::LdapModule')) {
            if ($mod->isa('EBox::Module::Service')) {
                if ($name ne $self->name()) {
                    $mod->configured() or
                        next;
                }
            }
            push (@modules, $mod->_ldapModImplementation);
        }
    }

    return \@modules;
}


# Method: allSlaves
#
# Returns all slaves from LDAP Sync Provider
#
sub allSlaves
{
    my ($self) = @_;

    my $global = EBox::Global->modInstance('global');
    my @names = @{$global->modNames};

    my @modules;
    foreach my $name (@names) {
        my $mod = EBox::Global->modInstance($name);

        if ($mod->isa('EBox::UsersAndGroups::SyncProvider')) {
            push (@modules, @{$mod->slaves()});
        }
    }

    return \@modules;
}


# Method: notifyModsPreLdapUserBase
#
#   Notify all modules implementing LDAP user base interface about
#   a change in users or groups before it happen.
#
# Parameters:
#
#   signal - Signal name to notify the modules (addUser, delUser, modifyGroup, ...)
#   args - single value or array ref containing signal parameters
#   ignored_modules - array ref of modnames to ignore (won't be notified)
#
sub notifyModsPreLdapUserBase
{
    my ($self, $signal, $args, $ignored_modules) = @_;

    # convert signal to method name
    my $method = '_' . $signal;

    # convert args to array if it is a single value
    unless (ref ($args) eq 'ARRAY') {
        $args = [ $args ];
    }

    foreach my $mod (@{$self->_modsLdapUserBase($ignored_modules)}) {
        $mod->$method(@{$args});
    }
}


# Method: notifyModsLdapUserBase
#
#   Notify all modules implementing LDAP user base interface about
#   a change in users or groups
#
# Parameters:
#
#   signal - Signal name to notify the modules (addUser, delUser, modifyGroup, ...)
#   args - single value or array ref containing signal parameters
#   ignored_modules - array ref of modnames to ignore (won't be notified)
#
sub notifyModsLdapUserBase
{
    my ($self, $signal, $args, $ignored_modules, $ignored_slaves) = @_;

    # convert signal to method name
    my $method = '_' . $signal;

    # convert args to array if it is a single value
    unless (ref($args) eq 'ARRAY') {
        $args = [ $args ];
    }

    my $basedn = $args->[0]->baseDn();
    my $defaultOU = ($basedn eq $self->usersDn() or $basedn eq $self->groupsDn());
    foreach my $mod (@{$self->_modsLdapUserBase($ignored_modules)}) {

        # Skip modules not supporting multiple OU if not default OU
        next unless ($mod->multipleOUSupport or $defaultOU);

        # TODO catch errors here? Not a good idea. The way to go is
        # to implement full transaction support and rollback if a notified
        # module throw an exception
        $mod->$method(@{$args});
    }

    # Save user corner operations for slave-sync daemon
    if ($self->isUserCorner) {

        my $dir = '/var/lib/zentyal-usercorner/syncjournal/';
        mkdir ($dir) unless (-d $dir);

        my $time = time();
        my ($fh, $filename) = tempfile("$time-$signal-XXXX", DIR => $dir);
        EBox::UsersAndGroups::Slave->writeActionInfo($fh, $signal, $args);
        $fh->close();
        return;
    }

    # Notify slaves
    $ignored_slaves or $ignored_slaves = [];
    foreach my $slave (@{$self->allSlaves}) {
        my $name = $slave->name();
        next if ($name eq any @{$ignored_slaves});

        $slave->sync($signal, $args);
    }
}


# Method: initialSlaveSync
#
#   This method will send a sync signal for each
#   stored user and group.
#   It should be called on a slave registering
#
#   If sync parameter is given, the operation will
#   be sent instantly, if not, it will be saved for
#   slave-sync daemon
#
sub initialSlaveSync
{
    my ($self, $slave, $sync) = @_;

    foreach my $user (@{$self->users()}) {
        if ($sync) {
            $slave->sync('addUser', [ $user ]);
        } else {
            $slave->savePendingSync('addUser', [ $user ]);
        }
    }

    foreach my $group (@{$self->groups()}) {
        if ($sync) {
            $slave->sync('addGroup', [ $group ]);
            $slave->sync('modifyGroup', [ $group ]);
        } else {
            $slave->savePendingSync('addGroup', [ $group ]);
            $slave->savePendingSync('modifyGroup', [ $group ]);
        }
    }
}

sub isUserCorner
{
    my ($self) = @_;

    my $auth_type = undef;
    try {
        my $r = Apache2::RequestUtil->request();
        $auth_type = $r->auth_type;
    } catch Error with {};

    return (defined $auth_type and
            $auth_type eq 'EBox::UserCorner::Auth');
}

# Method: defaultUserModels
#
#   Returns all the defaultUserModels from modules implementing
#   <EBox::LdapUserBase>
sub defaultUserModels
{
    my ($self) = @_;
    my @models;
    for my $module  (@{$self->_modsLdapUserBase()}) {
        my $model = $module->defaultUserModel();
        push (@models, $model) if (defined($model));
    }
    return \@models;
}

# Method: allUserAddOns
#
#       Returns all the mason components from those modules implementing
#       the function _userAddOns from EBox::LdapUserBase
#
# Parameters:
#
#       user - username
#
# Returns:
#
#       array ref - holding all the components and parameters
#
sub allUserAddOns
{
    my ($self, $user) = @_;

    my $global = EBox::Global->modInstance('global');
    my @names = @{$global->modNames};

    my $defaultOU = ($user->baseDn() eq $self->usersDn());

    my @modsFunc = @{$self->_modsLdapUserBase()};
    my @components;
    foreach my $mod (@modsFunc) {
        # Skip modules not support multiple OU, if not default OU
        next unless ($mod->multipleOUSupport or $defaultOU);

        my $comp = $mod->_userAddOns($user);
        if ($comp) {
            push (@components, $comp);
        }
    }

    return \@components;
}

# Method: allGroupAddOns
#
#       Returns all the mason components from those modules implementing
#       the function _groupAddOns from EBox::LdapUserBase
#
# Parameters:
#
#       group  - group name
#
# Returns:
#
#       array ref - holding all the components and parameters
#
sub allGroupAddOns
{
    my ($self, $group) = @_;

    my $global = EBox::Global->modInstance('global');
    my @names = @{$global->modNames};

    my @modsFunc = @{$self->_modsLdapUserBase()};
    my @components;
    foreach my $mod (@modsFunc) {
        my $comp = $mod->_groupAddOns($group);
        push (@components, $comp) if ($comp);
    }

    return \@components;
}

# Method: allWarning
#
#       Returns all the the warnings provided by the modules when a certain
#       user or group is going to be deleted. Function _delUserWarning or
#       _delGroupWarning is called in all module implementing them.
#
# Parameters:
#
#       object - Sort of object: 'user' or 'group'
#       name - name of the user or group
#
# Returns:
#
#       array ref - holding all the warnings
#
sub allWarnings
{
    my ($self, $object, $name) = @_;

    # Check for maximum users
    if (EBox::Global->edition() eq 'sb') {
        if (length(@{$self->users()}) >= MAX_SB_USERS) {
            throw EBox::Exceptions::External(
                __s('Please note that you have reached the maximum of users for this server edition. If you need to run Zentyal with more users please upgrade.'));

        }
    }

    my @modsFunc = @{$self->_modsLdapUserBase()};
    my @allWarns;
    foreach my $mod (@modsFunc) {
        my $warn = undef;
        if ($object eq 'user') {
            $warn = $mod->_delUserWarning($name);
        } else {
            $warn = $mod->_delGroupWarning($name);
        }
        push (@allWarns, $warn) if ($warn);
    }

    return \@allWarns;
}

# Method: _supportActions
#
#       Overrides EBox::ServiceModule::ServiceInterface method.
#
sub _supportActions
{
    return undef;
}

# Method: menu
#
#       Overrides EBox::Module method.
#
sub menu
{
    my ($self, $root) = @_;

    my $separator = 'Office';
    my $order = 510;

    my $folder = new EBox::Menu::Folder('name' => 'UsersAndGroups',
                                        'text' => $self->printableName(),
                                        'separator' => $separator,
                                        'order' => $order);

    if ($self->configured()) {
        if ($self->editableMode()) {
            $folder->add(new EBox::Menu::Item('url' => 'UsersAndGroups/Users',
                                              'text' => __('Users'), order => 10));
            $folder->add(new EBox::Menu::Item('url' => 'UsersAndGroups/Groups',
                                              'text' => __('Groups'), order => 20));
            $folder->add(new EBox::Menu::Item('url' => 'Users/Composite/UserTemplate',
                                              'text' => __('User Template'), order => 30));

        } else {
            $folder->add(new EBox::Menu::Item(
                        'url' => 'Users/View/Users',
                        'text' => __('Users'), order => 10));
            $folder->add(new EBox::Menu::Item(
                        'url' => 'Users/View/Groups',
                        'text' => __('Groups'), order => 20));
            $folder->add(new EBox::Menu::Item('url' => 'Users/Composite/UserTemplate',
                                              'text' => __('User Template'), order => 30));
        }

        if (EBox::Config::configkey('multiple_ous')) {
            $folder->add(new EBox::Menu::Item(
                        'url' => 'Users/View/OUs',
                        'text' => __('Organizational Units'), order => 25));
        }

        $folder->add(new EBox::Menu::Item(
                    'url' => 'Users/Composite/Sync',
                    'text' => __('Synchronization'), order => 40));

        $folder->add(new EBox::Menu::Item(
                    'url' => 'Users/Composite/Settings',
                    'text' => __('LDAP Settings'), order => 50));

    } else {
        $folder->add(new EBox::Menu::Item('url' => 'Users/View/Mode',
                                          'text' => __('Configure mode'),
                                          'separator' => $separator,
                                          'order' => 0));
    }

    $root->add($folder);
}

# EBox::UserCorner::Provider implementation

# Method: userMenu
#
sub userMenu
{
    my ($self, $root) = @_;

    $root->add(new EBox::Menu::Item('url' => 'Users/View/Password',
                                    'text' => __('Password')));
}


# Method: syncJournalDir
#
#   Returns the path holding sync pending actions for
#   the given slave.
#   If the directory does not exists, it will be created;
#
sub syncJournalDir
{
    my ($self, $slave, $notCreate) = @_;

    my $dir = JOURNAL_DIR . $slave->name();
    my $journalsDir = JOURNAL_DIR;

    unless ($notCreate) {
        # Create if the dir does not exists
        unless (-d $dir) {
            EBox::Sudo::root(
                "mkdir -p $dir",
                "chown -R ebox:ebox $journalsDir",
                "chmod 0700 $journalsDir",
               );
        }
    }

    return $dir;
}


# LdapModule implementation
sub _ldapModImplementation
{
    return new EBox::LdapUserImplementation();
}

# SyncProvider implementation

# Method: slaves
#
#    Get the slaves for this server
#
# Returns:
#
#    array ref - containing the slaves for this server. Zentyal server slaves are
#                <EBox::UsersSync::Slave> instances and Zentyal Cloud slave is
#                a <EBox::CloudSync::Slave> instance.
#
sub slaves
{
    my ($self) = @_;

    my $model = $self->model('Slaves');

    my @slaves;
    foreach my $id (@{$model->ids()}) {
        my $row = $model->row($id);
        my $host = $row->valueByName('host');
        my $port = $row->valueByName('port');

        push (@slaves, new EBox::UsersSync::Slave($host, $port, $id));
    }

    my $g = EBox::Global->getInstance(1);
    my $u = $g->modInstance('users');
    if ($u->master() eq 'cloud') {
        push (@slaves, new EBox::CloudSync::Slave());
    }

    return \@slaves;
}


# Method: master
#
#   Return configured master as string, undef in none
#
#   Options: 'zentyal', 'cloud' or None
#
sub master
{
    my ($self) = @_;
    my $row = $self->model('Master')->row();
    return $row->elementByName('master')->value();
}


# SyncProvider implementation
sub allowUserChanges
{
    my ($self) = @_;

    return (not $self->masterConf->isSlave());
}



# Master-Slave UsersSync object
sub masterConf
{
    my ($self) = @_;

    unless ($self->{ms}) {
        $self->{ms} = new EBox::UsersSync::Master();
    }
    return $self->{ms};
}

sub dumpConfig
{
    my ($self, $dir, %options) = @_;

    $self->ldap->dumpLdapConfig($dir);
    $self->ldap->dumpLdapData($dir);
    if ($options{bug}) {
        my $file = $self->ldap->ldifFile($dir, 'data');
        $self->_removePasswds($file);
    }
    else {
        # Save rootdn passwords
        copy(EBox::Config::conf() . 'ldap.passwd', $dir);
        copy(EBox::Config::conf() . 'ldap_ro.passwd', $dir);
    }
}

sub _usersInEtcPasswd
{
    my ($self) = @_;
    my @users;

    my @lines = File::Slurp::read_file('/etc/passwd');
    foreach my $line (@lines) {
        my ($user) = split ':', $line, 2;
        push @users, $user;
    }

    return \@users;
}

sub backupDomains
{
    my $name = 'homes';
    my %attrs  = (
                  printableName => __('Home directories'),
                  description   => __(q{User and groups home directoreies; anything under /home}),
                  order         => 300,
                 );

    return ($name, \%attrs);
}

sub backupDomainsFileSelection
{
    return { includes => ['/home']   };
}

sub restoreDependencies
{
    return ['dns'];
}

sub restoreBackupPreCheck
{
    my ($self, $dir) = @_;

    my %etcPasswdUsers = map { $_ => 1 } @{ $self->_usersInEtcPasswd() };

    my @usersToRestore = @{ $self->ldap->usersInBackup($dir) };
    foreach my $user (@usersToRestore) {
        if (exists $etcPasswdUsers{$user}) {
            throw EBox::Exceptions::External(__x('Cannot restore because LDAP user {user} already exists as /etc/passwd user. Delete or rename this user and try again', user => $user));
        }
    }
}

sub restoreConfig
{
    my ($self, $dir) = @_;
    my $mode = $self->mode();

    $self->_manageService('stop');

    my $LDIF_CONFIG = $self->ldap->ldifFile($dir, 'config');
    my $LDIF_DB = $self->ldap->ldifFile($dir, 'data');

    # retrieve base dn from backup
    my $fd;
    open($fd, $LDIF_DB);
    my $line = <$fd>;
    chomp($line);
    my @parts = split(/ /, $line);
    my $base = $parts[1];

    $self->_loadLDAP($base, $LDIF_CONFIG, $LDIF_DB);

    # Restore passwords
    copy($dir . '/ldap.passwd', EBox::Config::conf());
    copy($dir . '/ldap_ro.passwd', EBox::Config::conf());
    EBox::debug("Copying $dir/ldap.passwd to " . EBox::Config::conf());
    chmod(0600, "$dir/ldap.passwd", "$dir/ldap_ro.passwd");

    $self->_manageService('start');
    $self->ldap->clearConn();

    # Save conf to enable NSS (and/or) PAM
    $self->_setConf();

    for my $user (@{$self->users()}) {

        # Init local users
        if ($user->baseDn eq $self->usersDn) {
            $self->initUser($user);
        }

        # Notify modules except samba because its users will be
        # restored from its own LDB backup
        $self->notifyModsLdapUserBase('addUser', $user, ['samba']);
    }
}

sub _removePasswds
{
  my ($self, $file) = @_;

  my $anyPasswdAttr = any(qw(
              userPassword
              sambaLMPassword
              sambaNTPassword
              )
          );
  my $passwordSubstitution = "password";

  my $FH_IN;
  open $FH_IN, "<$file" or
      throw EBox::Exceptions::Internal ("Cannot open $file: $!");

  my ($FH_OUT, $tmpFile) = tempfile(DIR => EBox::Config::tmp());

  foreach my $line (<$FH_IN>) {
      my ($attr, $value) = split ':', $line;
      if ($attr eq $anyPasswdAttr) {
          $line = $attr . ': ' . $passwordSubstitution . "\n";
      }

      print $FH_OUT $line;
  }

  close $FH_IN  or
      throw EBox::Exceptions::Internal ("Cannot close $file: $!");
  close $FH_OUT or
      throw EBox::Exceptions::Internal ("Cannot close $tmpFile: $!");

  File::Copy::move($tmpFile, $file);
  unlink $tmpFile;
}


# Method: authUser
#
#   try to authenticate the given user with the given password
#
sub authUser
{
    my ($self, $user, $password) = @_;

    my $authorized = 0;
    my $ldap = EBox::Ldap::safeConnect(EBox::Ldap::LDAPI);
    try {
        EBox::Ldap::safeBind($ldap, $self->userDn($user), $password);
        $authorized = 1; # auth ok
    } otherwise {
        $authorized = 0; # auth failed
    };
    return $authorized;
}


sub listSchemas
{
    my ($self, $ldap) = @_;

    my %args = (
        'base' => 'cn=schema,cn=config',
        'scope' => 'one',
        'filter' => "(objectClass=olcSchemaConfig)"
    );
    my $result = $ldap->search(%args);

    my @schemas = map { $_->get_value('cn') } $result->entries();
    return \@schemas;
}


sub mode
{
    my ($self) = @_;

    return 'master';
}

# common check for user names and group names
sub checkNameLimitations
{
    my ($name) = @_;

    # combination of unix limitations + windows limitation characters are
    # limited to unix portable file character + space for windows compability
    # slash not valid as first character (unix limitation)
    # see http://technet.microsoft.com/en-us/library/cc776019%28WS.10%29.aspx
    if ($name =~ /^[a-zA-Z0-9\._-][a-zA-Z0-9\._[:space:]-]*$/) {
         return 1;
     } else {
         return undef;
     }
}

#  Nethod: newUserUidNumber
#
#  return the uid for a new user
#
#   Parameters:
#     system - true if we want the uid for a system user, defualt false
#
sub newUserUidNumber
{
    my ($self, $system) = @_;

    return EBox::UsersAndGroups::User->_newUserUidNumber($system);
}


######################################
##  SysInfo observer implementation ##
######################################

# Method: hostDomainChanged
#
#   This method disallow the change of the host domain if the module is
#   configured (implies that the kerberos realm has been initialized)
#
sub hostDomainChanged
{
    my ($self, $oldDomainName, $newDomainName) = @_;

    if ($self->configured()) {
        $self->set('need_reprovision', 1);
        $self->setAsChanged(1); # for compability with machines with phantom
                                # need_reprovision in read-only tree
        EBox::Global->modInstance('apache')->setAsChanged();
    }
}

# Method: hostDomainChangedDone
#
#   This method updates the base DN for LDAP if the module has not
#   been configured yet
#
sub hostDomainChangedDone
{
    my ($self, $oldDomainName, $newDomainName) = @_;

    unless ($self->configured()) {
        my $mode = $self->model('Mode');
        my $newDN = $mode->getDnFromDomainName($newDomainName);
        $mode->setValue('dn', $newDN);
    }
}

# Method: reprovision
#
#   Destroys all LDAP/Kerberos configuration and creates a new
#   empty one. Useful after a host/domain change.
#
sub reprovision
{
    my ($self) = @_;

    return unless $self->configured();
    EBox::info("Reprovisioning LDAP");

    my @removeHomeCmds;
    foreach my $home (map { $_->home() } @{$self->users()}) {
        push (@removeHomeCmds, "rm -rf $home");
    }
    EBox::Sudo::root(@removeHomeCmds);

    $self->_manageService('stop');
    EBox::Sudo::root('rm -rf /var/lib/ldap/*');
    $self->_manageService('start');

    $self->enableActions();

    # LDAP module has lost its schemas and LDAP config after the reprovision
    my $global = $self->global();
    my @mods = @{ $global->sortModulesByDependencies($global->modInstances(), 'depends' ) };
    foreach my $mod (@mods) {
        if (not $mod->isa('EBox::LdapModule')) {
            next;
        } elsif ($mod->name() eq $self->name()) {
            # dont reconfigure itself
            next;
        } elsif (not $mod->configured()) {
            next;
        }
        $mod->reprovisionLDAP();
    }
}

sub reprovisionLDAP
{
    throw EBox::Exceptions::Internal("This method should not be called in user module");
}

# Implement EBox::SyncFolders::Provider interface
sub syncFolders
{
    my ($self) = @_;

    my @folders;

    if ($self->recoveryEnabled()) {
        push (@folders, new EBox::SyncFolders::Folder('/home', 'recovery'));
    }

    return \@folders;
}

sub recoveryDomainName
{
    return __('Users data');
}

# Overrides:
#   EBox::Report::DiskUsageProvider::_facilitiesForDiskUsage
sub _facilitiesForDiskUsage
{
    my ($self) = @_;

    my $usersPrintableName  = __(q{Users data});
    my $usersPath           = '/home';

    return {
        $usersPrintableName   => [ $usersPath ],
    };
}


1;
