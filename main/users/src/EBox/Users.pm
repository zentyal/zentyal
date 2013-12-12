# Copyright (C) 2008-2013 Zentyal S.L.
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

package EBox::Users;

use base qw(EBox::Module::Service
            EBox::LdapModule
            EBox::SysInfo::Observer
            EBox::UserCorner::Provider
            EBox::SyncFolders::Provider
            EBox::Users::SyncProvider
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
use EBox::Users::Contact;
use EBox::Users::Group;
use EBox::Users::NamingContext;
use EBox::Users::OU;
use EBox::Users::Slave;
use EBox::Users::User;
use EBox::UsersSync::Master;
use EBox::UsersSync::Slave;
use EBox::CloudSync::Slave;
use EBox::Exceptions::UnwillingToPerform;
use EBox::Exceptions::LDAP;
use EBox::Exceptions::External;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::SyncFolders::Folder;
use EBox::Util::Version;
use EBox::Users::NamingContext;

use Digest::SHA;
use Digest::MD5;
use Sys::Hostname;

use TryCatch::Lite;
use File::Copy;
use File::Slurp;
use File::Temp qw/tempfile/;
use Perl6::Junction qw(any);
use String::ShellQuote;
use Time::HiRes;
use Fcntl qw(:flock);


use constant COMPUTERSDN    => 'ou=Computers';
use constant AD_COMPUTERSDN => 'cn=Computers';

use constant STANDALONE_MODE      => 'master';
use constant EXTERNAL_AD_MODE     => 'external-ad';
use constant BACKUP_MODE_FILE     => 'LDAP_MODE.bak';

use constant LIBNSS_LDAPFILE => '/etc/ldap.conf';
use constant LIBNSS_SECRETFILE => '/etc/ldap.secret';
use constant DEFAULTGROUP   => '__USERS__';
use constant JOURNAL_DIR    => EBox::Config::home() . 'syncjournal/';
use constant AUTHCONFIGTMPL => '/etc/auth-client-config/profile.d/acc-zentyal';
use constant CRONFILE       => '/etc/cron.d/zentyal-users';
use constant CRONFILE_EXTERNAL_AD_MODE => '/etc/cron.daily/zentyal-users-external-ad';

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

use constant OBJECT_EXISTS => 1;
use constant OBJECT_EXISTS_AND_HIDDEN_SID => 2;


sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'users',
                                      printableName => __('Users and Computers'),
                                      @_);
    bless($self, $class);
    $self->_setupForMode();

    return $self;
}

# Method: _setupForMode
#
#   setup the internal attributes need for active authentication mode
#
sub _setupForMode
{
    my ($self) = @_;
    my $mode = $self->mode();
    if ($mode ne EXTERNAL_AD_MODE) {
        $self->{ldapClass} = 'EBox::Ldap';
        $self->{ouClass} = 'EBox::Users::OU';
        $self->{userClass} = 'EBox::Users::User';
        $self->{contactClass} = 'EBox::Users::Contact';
        $self->{groupClass} = 'EBox::Users::Group';
        $self->{containerClass} = undef;
    } else {
        $self->{ldapClass} = 'EBox::LDAP::ExternalAD';
        $self->{ouClass} = 'EBox::Users::OU::ExternalAD';
        $self->{userClass} = 'EBox::Users::User::ExternalAD';
        $self->{contactClass} = 'EBox::Users::Contact::ExternalAD';
        $self->{groupClass} = 'EBox::Users::Group::ExternalAD';
        $self->{containerClass} = 'EBox::Users::Container::ExternalAD';
        # load this classes only when needed
        foreach my $pkg ($self->{ldapClass}, $self->{ouClass}, $self->{userClass}, $self->{contactClass}, $self->{groupClass}, $self->{containerClass}) {
            eval "use $pkg";
            $@ and throw EBox::Exceptions::Internal("When loading $pkg: $@");
        }
    }

}

# Method: ldapClass
#
#   Return the LDAP class implementation to use.
#
sub ldapClass
{
    my ($self) = @_;

    (defined $self->{ldapClass}) or
        throw EBox::Exceptions::Internal("ldapClass not initialized.");

    return $self->{ldapClass};
}

# Method: ouClass
#
#   Return the OU class implementation to use.
#
sub ouClass
{
    my ($self) = @_;

    (defined $self->{ouClass}) or
        throw EBox::Exceptions::Internal("ouClass not initialized.");

    return $self->{ouClass};
}

# Method: userClass
#
#   Return the User class implementation to use.
#
sub userClass
{
    my ($self) = @_;

    (defined $self->{userClass}) or
        throw EBox::Exceptions::Internal("userClass not initialized.");

    return $self->{userClass};
}

# Method: contactClass
#
#   Return the Contact class implementation to use.
#
sub contactClass
{
    my ($self) = @_;

    (defined $self->{contactClass}) or
        throw EBox::Exceptions::Internal("contactClass not initialized.");

    return $self->{contactClass};
}

# Method: groupClass
#
#   Return the Group class implementation to use.
#
sub groupClass
{
    my ($self) = @_;

    (defined $self->{groupClass}) or
        throw EBox::Exceptions::Internal("groupClass not initialized.") ;

    return $self->{groupClass};
}

# Method: container
#
#   Return the Container class implementation to use.
#
#  Warning:
#    this can be undefined since standalone server does not use it
sub containerClass
{
    my ($self) = @_;
    return $self->{containerClass};
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

sub enableModDepends
{
    my ($self) = @_;
    my @depends = ('ntp');
    my $mode = $self->mode();
    if ($mode eq STANDALONE_MODE) {
        push @depends, 'dns';
    }
    return \@depends;
}

# Method: actions
#
#       Override EBox::ServiceModule::ServiceInterface::actions
#
sub actions
{
    my ($self) = @_;

    my @actions;

    if ($self->mode() eq STANDALONE_MODE) {
        push@actions,{
                 'action' => __('Your LDAP database will be populated with some basic organizational units'),
                 'reason' => __('Zentyal needs this organizational units to add users and groups into them.'),
                 'module' => 'users'
                };

        # FIXME: This probably won't work if PAM is enabled after enabling the module
        if ($self->model('PAM')->enable_pamValue()) {
            push @actions, {
                    'action' => __('Configure PAM.'),
                    'reason' => __('Zentyal will give LDAP users system account.'),
                    'module' => 'users'
                };
        }
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
    push @files, {
            'file' => KRB5_CONF_FILE,
            'reason' => __('To set up kerberos authentication'),
            'module' => 'users'
        };

    if ($self->mode() eq STANDALONE_MODE) {
        push @files, (
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
    }

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
    my $mode = $self->mode();
    $self->_setupForMode();
    if ($mode eq STANDALONE_MODE) {
        $self->_internalServerEnableActions();
    } elsif ($mode eq EXTERNAL_AD_MODE) {
        $self->_externalADEnableActions();
    } else {
        throw EBox::Exceptions::Internal("Unknown mode $mode");
    }
}

sub _internalServerEnableActions
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

    $self->clearLdapConn();

    # Setup NSS (needed if some user is added before save changes)
    $self->_setConf(1);

    # Create default group
    my $groupClass = $self->groupClass();
    my %args = (
        name => DEFAULTGROUP,
        parent => $groupClass->defaultContainer(),
        description => 'All users',
        isSystemGroup => 1,
        ignoreMods  => ['samba'],
    );
    $groupClass->create(%args);

    # Perform LDAP actions (schemas, indexes, etc)
    EBox::info('Performing first LDAP actions');
    try {
        $self->performLDAPActions();
    } catch ($e) {
        EBox::error("Error performing users initialization: $e");
        throw EBox::Exceptions::External(__('Error performing users initialization'));
    }

    # Setup kerberos realm and DNS
    $self->setupKerberos();

    # Execute enable-module script
    $self->SUPER::enableActions();

    # Configure SOAP to listen for new slaves
    $self->masterConf->confSOAPService();
    $self->masterConf->setupMaster();

    # mark webAdmin as changed to avoid problems with getpwent calls, it needs
    # to be restarted to be aware of the new nsswitch conf
    EBox::Global->modInstance('webadmin')->setAsChanged();
}

sub _externalADEnableActions
{
    my ($self) = @_;
    my $global = $self->global();
    # we need to restart network to force the regeneration of DNS resolvers
    $global->modInstance('network')->setAsChanged();
    # we need to webadmin to clear DNs cache daa
    $global->modInstance('webadmin')->setAsChanged();
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
    } catch (EBox::Exceptions::Sudo::Command $e) {
        EBox::error('Trying to setup ldap failed, exit value: ' .  $e->exitValue());
        throw EBox::Exceptions::External(__('Error while creating users and groups database.'));
    } catch ($e) {
        EBox::error("Trying to setup ldap failed: $e");
    }
    EBox::debug('Setup LDAP done');
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
    return [{ page => '/Users/Wizard/Users', order => 300 }];
}

# Method: _setConf
#
#       Override EBox::Module::Service::_setConf
#
#  Parameters:
#    noSlaveSetup - don't setup slaves in standalone serve mode
#
sub _setConf
{
    my ($self, $noSlaveSetup) = @_;
    $self->_setupForMode();

    # Setup kerberos config file
    my $realm = $self->kerberosRealm();
    my @params = ('realm' => $realm);
    $self->writeConfFile(KRB5_CONF_FILE, 'users/krb5.conf.mas', \@params);

    if ($self->mode() eq EXTERNAL_AD_MODE) {
        $self->_setConfExternalAD();
    } else {
        $self->_setConfInternal($realm, $noSlaveSetup);
    }
}

sub _setConfExternalAD
{
    my ($self) = @_;

    # Install cron file to update the squid keytab in the case keys change
    $self->writeConfFile(CRONFILE_EXTERNAL_AD_MODE, "users/zentyal-users-external-ad.cron.mas", []);
    EBox::Sudo::root('chmod a+x ' . CRONFILE_EXTERNAL_AD_MODE);
}

sub _setConfInternal
{
    my ($self, $realm, $noSlaveSetup) = @_;
    if ($self->get('need_reprovision')) {
        $self->unset('need_reprovision');
        # workaround  a orphan need_reprovision on read-only
        my $roKey = 'users/ro/need_reprovision';
        $self->redis->unset($roKey);

        try {
            $self->reprovision();
        } catch ($e) {
            $self->set('need_reprovision', 1);
            throw EBox::Exceptions::External(__x(
'Error on reprovision: {err}. {pbeg}Until the reprovision is done the user module and it is dependencies will be unusable. In the next saving of changes reprovision will be attempted again.{pend}',
               err => "$e",
               pbeg => '<p>',
               pend => '</p>'
            ));
        }
    }

    my $ldap = $self->ldap;
    EBox::Module::Base::writeFile(LIBNSS_SECRETFILE, $ldap->getPassword(),
        { mode => '0600', uid => 0, gid => 0 });

    my $dn = $ldap->dn;
    my $nsspw = $ldap->getRoPassword();
    my @params;
    push (@params, 'ldap' => EBox::Ldap::LDAPI);
    push (@params, 'basedc'    => $dn);
    push (@params, 'binddn'    => $ldap->roRootDn());
    push (@params, 'rootbinddn'=> $ldap->rootDn());
    push (@params, 'bindpw'    => $nsspw);
    push (@params, 'computersdn' => COMPUTERSDN . ',' . $dn);

    $self->writeConfFile(LIBNSS_LDAPFILE, "users/ldap.conf.mas",
            \@params);

    $self->_setupNSSPAM();

    # Slaves cron
    @params = ();
    push(@params, 'slave_time' => EBox::Config::configkey('slave_time'));
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

        push(@params, 'cloudsync_enabled' => 1);
    }
    $self->writeConfFile(CRONFILE, "users/zentyal-users.cron.mas", \@params);

    # Configure as slave if enabled
    $self->masterConf->setupSlave() unless ($noSlaveSetup);

    # Configure soap service
    $self->masterConf->confSOAPService();

    # commit slaves removal
    EBox::Users::Slave->commitRemovals($self->global());

    my $ldapBase = $self->ldap->dn();
    @params = ();
    push (@params, 'ldapBase' => $ldapBase);
    push (@params, 'realm' => $realm);
    $self->writeConfFile(KDC_CONF_FILE, 'users/kdc.conf.mas', \@params);

    @params = ();
    $self->writeConfFile(KDC_DEFAULT_FILE, 'users/heimdal-kdc.mas', \@params);
}

sub _postServiceHook
{
    my ($self, $enabled) = @_;

    if ($enabled and $self->mode() eq EXTERNAL_AD_MODE) {
        # Update services keytabs
        my $ldap = $self->ldap();
        my @principals = @{ $ldap->externalServicesPrincipals() };
        if (scalar @principals) {
            $ldap->initKeyTabs();
        }
    }
}

# overriden to revoke slave removals
sub revokeConfig
{
   my ($self) = @_;
   $self->SUPER::revokeConfig();
   EBox::Users::Slave->revokeRemovals($self->global());
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
#       They could not be edited ither mode is external-ad or the syncprovider
#       does not allows it
#
sub editableMode
{
    my ($self) = @_;
    if ($self->mode() ne STANDALONE_MODE) {
        return 0;
    }

    my $global = EBox::Global->modInstance('global');
    my @names = @{$global->modNames};

    my @modules;
    foreach my $name (@names) {
        my $mod = EBox::Global->modInstance($name);

        if ($mod->isa('EBox::Users::SyncProvider')) {
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

    my $usingInternalServer = sub {
        return $self->mode() eq STANDALONE_MODE;
    };

    return [
        {
            name => 'ebox.slapd',
            precondition => $usingInternalServer
        },
        {
            name => 'zentyal.heimdal-kdc',
            precondition => $usingInternalServer
        },
        {
            name => 'zentyal.heimdal-kpasswd',
            precondition => $usingInternalServer
        },
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
    $self->clearLdapConn();
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
#
# FIXME: This should not be used anymore...
sub groupDn
{
    my ($self, $group) = @_;
    $group or throw EBox::Exceptions::MissingArgument('group');

    my $dn = "cn=$group," . EBox::Users::Group->defaultContainer()->dn();
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
        } catch {
        }
   }
}

# Method: ous
#
#   Returns an array containing all the OUs. The array ir ordered in a
#   hierarquical way. Parents before childs.
#
# Returns:
#
#   array ref - holding the OUs. Each user is represented by a
#   EBox::Users::OU object
#
sub ous
{
    my ($self, $baseDN) = @_;

    return [] if (not $self->isEnabled());

    unless (defined $baseDN) {
        $baseDN = $self->ldap->dn();
    }

    my $objectClass = $self->{ouClass}->mainObjectClass();
    my $searchArgs = {
        base => $baseDN,
        filter => "objectclass=$objectClass",
        scope => 'one',
    };

    my $ous = [];
    my $result = $self->ldap->search($searchArgs);
    foreach my $entry ($result->entries()) {
        my $ou = EBox::Users::OU->new(entry => $entry);
        push (@{$ous}, $ou);
        my $nested = $self->ous($ou->dn());
        push (@{$ous}, @{$nested});
    }

    return $ous;
}

# Method: userByUID
#
# Return the instance of EBox::Users::User object which represents a given uid or undef if it's not found.
#
#  Parameters:
#      uid
#
sub userByUID
{
    my ($self, $uid) = @_;

    my $userClass = $self->userClass();
    my $objectClass = $userClass->mainObjectClass();
    my $uidTag = $userClass->uidTag();
    my $args = {
        base => $self->ldap->dn(),
        filter => "(&(objectclass=$objectClass)($uidTag=$uid))",
        scope => 'sub',
    };

    my $result = $self->ldap->search($args);
    my $count = $result->count();
    if ($count > 1) {
        throw EBox::Exceptions::Internal(
            __x('Found {count} results for \'{uid}\' user, expected only one.',
                count => $count,
                name  => $uid
            )
        );
    } elsif ($count == 0) {
        return undef;
    } else {
        return $self->entryModeledObject($result->entry(0));
    }
}

# Method: userExists
#
#  Returns:
#
#      bool - whether the user exists or not
#
sub userExists
{
    my ($self, $uid) = @_;
    my $user = $self->userByUID($uid);
    if (not $user) {
        return undef;
    }
    if ($self->global()->modExists('samba')) {
        # check if it is a reserved user
        my $samba = $self->global()->modInstance('samba');
        if (not $samba->isProvisioned()) {
            return OBJECT_EXISTS;
        }
        my $ldbUser = $samba->ldbObjectByObjectGUID($user->get('msdsObjectGUID'));
        if ($samba->hiddenSid($ldbUser)) {
            return OBJECT_EXISTS_AND_HIDDEN_SID;
        }
    }

    return OBJECT_EXISTS;
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
#       EBox::Users::User object
#
sub users
{
    my ($self, $system) = @_;

    return [] if (not $self->isEnabled());

    my $objectClass = $self->{userClass}->mainObjectClass();
    my %args = (
        base => $self->ldap->dn(),
        filter => "objectclass=$objectClass",
        scope => 'sub',
    );

    my $result = $self->ldap->search(\%args);

    my @users = ();
    foreach my $entry ($result->entries)
    {
        my $user = $self->{userClass}->new(entry => $entry);
        # Include system users?
        next if (not $system and $user->isSystem());

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
# Returns:
#
#       array ref - holding the users. Each user is represented by a
#       EBox::Users::User object
#
sub realUsers
{
    my ($self) = @_;

    my @users = grep { not $_->isInternal() } @{$self->users()};

    return \@users;
}

# Method: realGroups
#
#       Returns an array containing all the non-internal groups
#
# Returns:
#
#       array ref - holding the groups. Each user is represented by a
#       EBox::Users::Group object
#
sub realGroups
{
    my ($self) = @_;

    my @groups = grep { not $_->isInternal() } @{$self->securityGroups()};

    return \@groups;
}

# Method: contactsByName
#
# Return a reference to a list of instances of EBox::Users::Contact objects which represents a given name.
#
#  Parameters:
#      name
#
sub contactsByName
{
    my ($self, $name) = @_;

    my $contactClass = $self->contactClass();
    my $objectClass = $contactClass->mainObjectClass();
    my $args = {
        base => $self->ldap->dn(),
        filter => "(&(objectclass=$objectClass)(cn=$name))",
        scope => 'sub',
    };

    my $result = $self->ldap->search($args);
    my $count = $result->count();
    return [] if ($count == 0);

    my @contacts = ();

    foreach my $entry (@{$result->entries}) {
        my $contact = $self->entryModeledObject($entry);
        push (@contacts, $contact) if ($contact);
    }

    return \@contacts;
}

# Method: contactExists
#
#  Returns:
#
#      bool - whether the contact exists or not
#
sub contactExists
{
    my ($self, $name) = @_;
    return undef unless ($self->contactsByName($name));
    return 1;
}

# Method: contacts
#
#       Returns an array containing all the contacts
#
# Returns:
#
#       array ref - holding the contacts. Each contact is represented by a
#       EBox::Users::Contact object
#
sub contacts
{
    my ($self) = @_;

    return [] if (not $self->isEnabled());

    my %args = (
        base => $self->ldap->dn(),
        filter => '(&(objectclass=inetOrgPerson)(!(objectclass=posixAccount)))',
        scope => 'sub',
    );

    my $result = $self->ldap->search(\%args);

    my @contacts = ();
    foreach my $entry ($result->entries) {
        my $contact = new EBox::Users::Contact(entry => $entry);

        push (@contacts, $contact);
    }

    # sort by name
    @contacts = sort {
        my $aValue = $a->fullname();
        my $bValue = $b->fullname();
        (lc $aValue cmp lc $bValue) or ($aValue cmp $bValue)
    } @contacts;

    return \@contacts;
}

# Method: groupByName
#
# Return the instance of EBox::Users::Group object which represents a give group name or undef if it's not found.
#
#  Parameters:
#      name
#
sub groupByName
{
    my ($self, $name) = @_;

    my $groupClass = $self->groupClass();
    my $objectClass = $groupClass->mainObjectClass();
    my $args = {
        base => $self->ldap->dn(),
        filter => "(&(objectclass=$objectClass)(cn=$name))",
        scope => 'sub',
    };

    my $result = $self->ldap->search($args);
    my $count = $result->count();
    if ($count > 1) {
        throw EBox::Exceptions::Internal(
            __x('Found {count} results for \'{name}\' group, expected only one.',
                count => $count,
                name  => $name
            )
        );
    } elsif ($count == 0) {
        return undef;
    } else {
        return $self->entryModeledObject($result->entry(0));
    }
}

# Method: groupExists
#
#  Returns:
#
#      bool - whether the group exists or not
#
sub groupExists
{
    my ($self, $name) = @_;
    my $group = $self->groupByName($name);
    if (not $group) {
        return undef;
    }

    if ($self->global()->modExists('samba')) {
        # check if it is a reserved user
        my $samba = $self->global()->modInstance('samba');
        if (not $samba->isProvisioned()) {
            return OBJECT_EXISTS;
        }
        my $ldbGroup = $samba->ldbObjectByObjectGUID($group->get('msdsObjectGUID'));
        if ($samba->hiddenSid($ldbGroup)) {
            return OBJECT_EXISTS_AND_HIDDEN_SID;
        }
    }

    return OBJECT_EXISTS;
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
#       array - holding the groups as EBox::Users::Group objects
#
sub groups
{
    my ($self, $system) = @_;

    return [] if (not $self->isEnabled());

    my $groupClass  = $self->groupClass();
    my $objectClass = $groupClass->mainObjectClass();
    my %args = (
        base => $self->ldap->dn(),
        filter => "objectclass=$objectClass",
        scope => 'sub',
    );

    my $result = $self->ldap->search(\%args);

    my @groups = ();
    foreach my $entry ($result->entries())  {
        my $group = $groupClass->new(entry => $entry);

        # Include system users?
        next if (not $system and $group->isSystem());

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

# Method: securityGroups
#
#       Returns an array containing all the security groups
#
#   Parameters:
#       system - show system groups (default: false)
#
# Returns:
#
#       array - holding the groups as EBox::Users::Group objects
#
sub securityGroups
{
    my ($self, $system) = @_;

    return [] if (not $self->isEnabled());

    my %args = (
        base => $self->ldap->dn(),
        filter => '(&(objectclass=zentyalDistributionGroup)(objectclass=posixGroup))',
        scope => 'sub',
    );

    my $result = $self->ldap->search(\%args);

    my @groups = ();
    foreach my $entry ($result->entries())
    {
        my $group = new EBox::Users::Group(entry => $entry);

        # Include system users?
        next if (not $system and $group->isSystem());

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

        if ($mod->isa('EBox::Users::SyncProvider')) {
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

    my $defaultOU = $args->[0]->isInDefaultContainer();
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
        EBox::Users::Slave->writeActionInfo($fh, $signal, $args);
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

# Method: isUserCorner
#
#  Returns:
#    true if we are running inside the user corner web server, false otherwise
sub isUserCorner
{
    my ($self) = @_;

    my $auth_type = undef;
    try {
        my $r = Apache2::RequestUtil->request();
        $auth_type = $r->auth_type;
    } catch {
    }

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
#       user - user object
#
# Returns:
#
#       array ref - holding all the components and parameters
#
sub allUserAddOns
{
    my ($self, $user) = @_;
    my $defaultOU = ($user->baseDn() eq $user->defaultContainer()->dn());

    my @modsFunc = @{$self->_modsLdapUserBase()};
    my @components;
    foreach my $mod (@modsFunc) {
        # Skip modules not support multiple OU, if not default OU
        next unless ($mod->multipleOUSupport or $defaultOU);

        my $comp = $mod->_userAddOns($user);
        if ($comp) {
            $comp->{id} = ref $mod;
            $comp->{id} =~ s/:/_/g;
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
        if ($comp) {
            $comp->{id} = ref $mod;
            $comp->{id} =~ s/:/_/g;
            push (@components, $comp) if ($comp);
        }
    }

    return \@components;
}

# Method: allWarnings
#
#       Returns all the the warnings provided by the modules when a certain
#       user, group is going to be deleted. Function _delUserWarning or
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

    # TODO: Extend it for ous and contacts.
    return [] unless (($object eq 'user') or ($object eq 'group'));

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

    my $folder = new EBox::Menu::Folder('name' => 'Users',
                                        'icon' => 'users',
                                        'text' => $self->printableName(),
                                        'separator' => $separator,
                                        'order' => $order);
    if ($self->configured()) {
        $folder->add(new EBox::Menu::Item(
            'url'  => 'Users/Tree/Manage',
            'text' => __('Manage'), order => 10));
        $folder->add(new EBox::Menu::Item(
            'url'  => 'Users/Composite/UserTemplate',
            'text' => __('User Template'), order => 30));
        if ($self->mode() eq STANDALONE_MODE) {
            $folder->add(new EBox::Menu::Item(
                'url'  => 'Users/Composite/Sync',
                'text' => __('Synchronization'), order => 40));
        }
        $folder->add(new EBox::Menu::Item(
            'url'  => 'Users/Composite/Settings',
            'text' => __('LDAP Settings'), order => 50));
    } else {
        $folder->add(new EBox::Menu::Item(
            'url'       => 'Users/View/Mode',
            'text'      => __('Configure mode'),
            'separator' => $separator,
            'order'     => 0));
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
    return $self->model('Master')->master();
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
    my $mode = $self->mode();
    File::Slurp::write_file($dir . '/' . BACKUP_MODE_FILE, $mode);
    if ($mode ne STANDALONE_MODE) {
        # the dump of the LDAP is only availabe in standalone server mode
        return;
    }

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

sub restoreDependencies
{
    my ($self) = @_;
    if ($self->mode() eq STANDALONE_MODE) {
            return ['dns'];
    }
    return [];
}

# Method: restoreBackupPreCheck
#
# Check that the backup to be restored mode is compatible.
# Also, in case we are using standalone mode, checks if we have clonflicts between
# users in the LDAP data to be loaded and the users in /etc/passwd
sub restoreBackupPreCheck
{
    my ($self, $dir) = @_;
    my $mode = $self->mode();
    my $backupModeFile = $dir . '/' . BACKUP_MODE_FILE;
    my $backupMode;
    if (-r $backupModeFile) {
        $backupMode =  File::Slurp::read_file($backupModeFile);
    } else {
        # standalone mode by default
        $backupMode = STANDALONE_MODE;
    }


    if ($mode ne $backupMode) {
        my $modeModel = $self->model('Mode');
        throw EBox::Exceptions::External(
            __x('Cannot restore users module bacuse is running in mode {mode} and the backup was made in mode {bpMode}',
                mode => $modeModel->modePrintableName($mode),
                bpMode => $modeModel->modePrintableName($backupMode),
               )
           );
    }

    if ($mode ne STANDALONE_MODE) {
        # nothing more to check
        return;
    }

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

    File::Slurp::write_file($dir . '/' . BACKUP_MODE_FILE, $mode);
    if ($mode ne STANDALONE_MODE) {
        # only standalone mode needs to do this operations to restore the LDAP
        # directory
        return;
    }

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
    $self->clearLdapConn();

    # Save conf to enable NSS (and/or) PAM
    $self->_setConf();

    for my $user (@{$self->users()}) {

        # Init local users
        $self->initUser($user);

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
    my $mode = $self->model('Mode')->value('mode');
    if (not $mode) {
        return STANDALONE_MODE;
    }
    return $mode;
}

# Method: newLDAP
#
#  Return a new LDAP object instance of the class requiered by the active mode
#
sub newLDAP
{
    my ($self) = @_;
    my $mode = $self->mode();
    if ($mode eq EXTERNAL_AD_MODE) {
        return EBox::LDAP::ExternalAD->instance(
            @{ $self->model('Mode')->adModeOptions() }
           );
    }

    return  EBox::Ldap->instance();
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

# Method: checkCnLimitations
#
#   Return whether the given string is valid for its usage as a cn field.
#
# Parameters:
#
#   string - The string to check.
#
sub checkCnLimitations
{
    my ($self, $string) = @_;

    if ($string =~ /^([a-zA-Z\d\s_-]+\.)*[a-zA-Z\d\s_-]+$/) {
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

    return EBox::Users::User->_newUserUidNumber($system);
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
        EBox::Global->modInstance('webadmin')->setAsChanged();
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

# Method: entryModeledObject
#
#   Return the Perl Object that handles the given LDAP entry.
#
#   Throw EBox::Exceptions::Internal on error.
#
# Parameters:
#
#   entry - A Net::LDAP::Entry object.
#
sub entryModeledObject
{
    my ($self, $entry) = @_;

    my $anyObjectClasses = any(@{[$entry->get_value('objectClass')]});
    # IMPORTANT: The order matters, a contactClass would match users too, so we must check first if it's a user.
    foreach my $type ( qw(ouClass userClass contactClass groupClass containerClass)) {
        my $class = $self->$type();
        # containerClass may not exist.
        next unless ($class);
        my $mainLDAPClass = $class->mainObjectClass();
        if ((defined $mainLDAPClass) and ($mainLDAPClass eq $anyObjectClasses)) {
            return $class->new(entry => $entry);
        }
    }

    my $ldap = $self->ldap();
    if ($entry->dn() eq $ldap->dn()) {
        return $self->defaultNamingContext();
    }

    EBox::debug("Ignored unknown perl object for DN: " . $entry->dn());
    return undef;
}

# Method: relativeDN
#
#   Return the given dn without the naming Context part.
#
sub relativeDN
{
    my ($self, $dn) = @_;

    throw EBox::Exceptions::MissingArgument("dn") unless ($dn);

    my $baseDN = $self->ldap()->dn();

    return '' if ($dn eq $baseDN);

    if (not $dn =~ s/,$baseDN$//) {
        throw EBox::Exceptions::Internal("$dn is not contained in $baseDN");
    }

    return $dn;
}

# Method: objectFromDN
#
#   Return the perl object modeling the given dn or undef if not found.
#
# Parameters:
#
#   dn - An LDAP DN string identifying the object to retrieve.
#
sub objectFromDN
{
    my ($self, $dn) = @_;
    my $ldap = $self->ldap();
    if ($dn eq $ldap->dn()) {
        return $self->defaultNamingContext();
    }

    my $baseObject = new EBox::Users::LdapObject(dn => $dn);

    if ($baseObject->exists()) {
        return $self->entryModeledObject($baseObject->_entry());
    } else {
        return undef;
    }
}

# Method: defaultNamingContext
#
#   Return the Perl Object that holds the default Naming Context for this LDAP server.
#
#
sub defaultNamingContext
{
    my ($self) = @_;

    my $ldap = $self->ldap;
    return new EBox::Users::NamingContext(dn => $ldap->dn());
}

sub ousToHide
{
    my ($self) = @_;

    my @ous;

    foreach my $mod (@{EBox::Global->modInstancesOfType('EBox::LdapModule')}) {
        push (@ous, @{$mod->_ldapModImplementation()->hiddenOUs()});
    }

    return \@ous;
}

1;
