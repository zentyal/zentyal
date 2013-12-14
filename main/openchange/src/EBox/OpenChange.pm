# Copyright (C) 2013 Zentyal S.L.
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

package EBox::OpenChange;

use base qw(EBox::Module::Service EBox::LdapModule);

use EBox::Gettext;
use EBox::Config;
use EBox::DBEngineFactory;
use EBox::OpenChange::LdapUser;
use EBox::OpenChange::ExchConfigurationContainer;
use EBox::OpenChange::ExchOrganizationContainer;

use String::Random;

use constant SOGO_PORT => 20000;
use constant SOGO_DEFAULT_PREFORK => 1;

use constant SOGO_DEFAULT_FILE => '/etc/default/sogo';
use constant SOGO_CONF_FILE => '/etc/sogo/sogo.conf';
use constant SOGO_PID_FILE => '/var/run/sogo/sogo.pid';
use constant SOGO_LOG_FILE => '/var/log/sogo/sogo.log';

use constant OCSMANAGER_CONF_FILE => '/etc/ocsmanager/ocsmanager.ini';
use constant OCSMANAGER_INC_FILE  => '/var/lib/zentyal/conf/openchange/ocsmanager.conf';

# Method: _create
#
#   The constructor, instantiate module
#
sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'openchange',
                                      printableName => 'OpenChange',
                                      @_);
    bless ($self, $class);
    return $self;
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

    $self->_migrateFormKeys();
}

# Migration of form keys to better names (between development versions)
#
# * Migrate redis keys from firstorganization to organizationname and firstorganizationunit to administrativegroup
#
sub _migrateFormKeys
{
    my ($self) = @_;
    my $modelName = 'Provision';
    my @keys = ("openchange/conf/$modelName/keys/form", "openchange/ro/$modelName/keys/form");

    my $state = $self->get_state();
    my $keyField = 'organizationname';
    my $redis = $self->redis();
    foreach my $key (@keys) {
        my $value = $redis->get($key);
        if (defined $value->{firstorganization}) {
            $state->{$modelName}->{$keyField} = $value->{firstorganization};
            delete $value->{firstorganization};
        }
        if (defined $value->{organizationname}) {
            $state->{$modelName}->{$keyField} = $value->{organizationname};
            delete $value->{organizationname};
        }
        if (defined $value->{firstorganizationunit}) {
            delete $value->{firstorganizationunit};
        }
        if (defined $value->{administrativegroup}) {
            delete $value->{administrativegroup};
        }
        $redis->set($key, $value);
    }
    if ($self->isProvisioned()) {
        # The organization name is only useful if the server is already provisioned.
        $self->set_state($state);
    }
}

# Method: enableActions
#
# Action to do when openchange module is enabled for first time
#
sub enableActions
{
    my ($self) = @_;
    $self->SUPER::enableActions();
    $self->_setupDNS();
}

# Method: enableService
#
#   Override EBox::Module::Service::enableService to notify samba
#
sub enableService
{
    my ($self, $status) = @_;

    $self->SUPER::enableService($status);
    if ($self->changed()) {
        my $global = $self->global();
        # Mark mail as changed to make dovecot listen IMAP protocol at least
        # on localhost
        my $mail = $global->modInstance('mail');
        $mail->setAsChanged();

        # Mark samba as changed to write smb.conf
        my $samba = $global->modInstance('samba');
        $samba->setAsChanged();

        # Mark webadmin as changed so we are sure nginx configuration is
        # refreshed with the new includes
        $global->modInstance('webadmin')->setAsChanged();
    }
}

sub _daemonsToDisable
{
    my ($self) = @_;

    my $daemons = [
        {
            name => 'openchange-ocsmanager',
            type => 'init.d',
        }
       ];
    return $daemons;
}

# Method: _daemons
#
# Overrides:
#
#      <EBox::Module::Service::_daemons>
#
sub _daemons
{
    my ($self) = @_;
    my $daemons = [
        {
            name         => 'zentyal.ocsmanager',
            type         => 'upstart',
            precondition => sub { return $self->_autodiscoverEnabled() },
        },
        {
            name         => 'zentyal.zoc-migrate',
            type         => 'upstart',
            precondition => sub { return $self->isProvisioned() },
        },
    ];
    return $daemons;
}

sub _autodiscoverEnabled
{
    my ($self) = @_;
    return $self->isProvisioned();
}

sub usedFiles
{
    my @files = (
        {
            file => SOGO_DEFAULT_FILE,
            reason => __('To configure sogo daemon'),
            module => 'openchange'
       },
       {
           file => SOGO_CONF_FILE,
           reason => __('To configure sogo parameters'),
           module => 'openchange'
       },
       {
           file => OCSMANAGER_CONF_FILE,
           reason => __('To configure autodiscovery service'),
           module => 'openchange'
       }
      );

    return \@files;
}

sub _setConf
{
    my ($self) = @_;

    $self->_writeSOGoDefaultFile();
    $self->_writeSOGoConfFile();
    $self->_setupSOGoDatabase();
    $self->_setAutodiscoverConf();
}

sub _writeSOGoDefaultFile
{
    my ($self) = @_;

    my $array = [];
    my $prefork = EBox::Config::configkey('sogod_prefork');
    unless (length $prefork) {
        $prefork = SOGO_DEFAULT_PREFORK;
    }
    push (@{$array}, prefork => $prefork);
    $self->writeConfFile(SOGO_DEFAULT_FILE,
        'openchange/sogo.mas',
        $array, { uid => 0, gid => 0, mode => '755' });
}

sub _writeSOGoConfFile
{
    my ($self) = @_;

    my $array = [];

    my $sysinfo = $self->global->modInstance('sysinfo');
    my $timezoneModel = $sysinfo->model('TimeZone');
    my $sogoTimeZone = $timezoneModel->row->printableValueByName('timezone');

    my $samba = $self->global->modInstance('samba');
    my $dcHostName = $samba->ldb->rootDse->get_value('dnsHostName');
    my (undef, $sogoMailDomain) = split (/\./, $dcHostName, 2);

    push (@{$array}, sogoPort => SOGO_PORT);
    push (@{$array}, sogoLogFile => SOGO_LOG_FILE);
    push (@{$array}, sogoPidFile => SOGO_PID_FILE);
    push (@{$array}, sogoTimeZone => $sogoTimeZone);
    push (@{$array}, sogoMailDomain => $sogoMailDomain);

    my $mail = $self->global->modInstance('mail');
    my $retrievalServices = $mail->model('RetrievalServices');
    my $sieveEnabled = $retrievalServices->value('managesieve');
    my $sieveServer = ($sieveEnabled ? 'sieve://127.0.0.1:4190' : '');
    my $imapServer = '127.0.0.1:143';
    my $smtpServer = '127.0.0.1:25';
    push (@{$array}, imapServer => $imapServer);
    push (@{$array}, smtpServer => $smtpServer);
    push (@{$array}, sieveServer => $sieveServer);

    my $dbName = $self->_sogoDbName();
    my $dbUser = $self->_sogoDbUser();
    my $dbPass = $self->_sogoDbPass();
    push (@{$array}, dbName => $dbName);
    push (@{$array}, dbUser => $dbUser);
    push (@{$array}, dbPass => $dbPass);
    push (@{$array}, dbHost => '127.0.0.1');
    push (@{$array}, dbPort => 3306);

    my $baseDN = $self->ldap->dn();
    if (EBox::Config::boolean('openchange_disable_multiou')) {
        $baseDN = "ou=Users,$baseDN";
    }

    push (@{$array}, ldapBaseDN => $baseDN);
    push (@{$array}, ldapBindDN => $self->ldap->roRootDn());
    push (@{$array}, ldapBindPwd => $self->ldap->getRoPassword());
    push (@{$array}, ldapHost => $self->ldap->LDAPI());

    my (undef, undef, undef, $gid) = getpwnam('sogo');
    $self->writeConfFile(SOGO_CONF_FILE,
        'openchange/sogo.conf.mas',
        $array, { uid => 0, gid => $gid, mode => '640' });
}

sub _setAutodiscoverConf
{
    my ($self) = @_;
    my $global  = $self->global();
    my $sysinfo = $global->modInstance('sysinfo');
    my $samba   = $global->modInstance('samba');
    my $mail    = $global->modInstance('mail');

    my $server    = $sysinfo->hostDomain();
    my $adminMail = $mail->model('SMTPOptions')->value('postmasterAddress');
    if ($adminMail eq 'postmasterRoot') {
        $adminMail = 'postmaster@' . $server;
    }
    my $confFileParams = [
        bindDn    => 'cn=Administrator',
        bindPwd   => $samba->administratorPassword(),
        baseDn    => 'CN=Users,' . $samba->ldb()->dn(),
        port      => 389,
        adminMail => $adminMail,
    ];

    $self->writeConfFile(OCSMANAGER_CONF_FILE,
                         'openchange/ocsmanager.ini.mas',
                         $confFileParams,
                         { uid => 0, gid => 0, mode => '640' }
                        );

    # manage the nginx include file
    my $webadmin = $global->modInstance('webadmin');
    if ($self->isEnabled()) {
        my $confDir = EBox::Config::conf() . 'openchange';
        EBox::Sudo::root("mkdir -p '$confDir'");
        my $incParams = [
            server => $server
           ];
        $self->writeConfFile(OCSMANAGER_INC_FILE,
                             "openchange/ocsmanager.nginx.mas",
                             $incParams,
                             { uid => 0, gid => 0, mode => '644' }
                        );
        $webadmin->addNginxInclude(OCSMANAGER_INC_FILE);
    } else {
        $webadmin->removeNginxInclude(OCSMANAGER_INC_FILE);
    }
}

# Method: menu
#
#   Add an entry to the menu with this module.
#
sub menu
{
    my ($self, $root) = @_;

    my $separator = 'Communications';
    my $order = 900;

    my $folder = new EBox::Menu::Folder(
        name => 'OpenChange',
        icon => 'openchange',
        text => $self->printableName(),
        separator => $separator,
        order => $order);
    $folder->add(new EBox::Menu::Item(
        url       => 'OpenChange/View/Provision',
        text      => __('Setup'),
        order     => 0));
    if ($self->isProvisioned()) {
        $folder->add(new EBox::Menu::Item(
            url       => 'OpenChange/Migration/Connect',
            text      => __('MailBox Migration'),
            order     => 1));
    }
    $root->add($folder);
}

sub _ldapModImplementation
{
    return new EBox::OpenChange::LdapUser();
}

sub isProvisioned
{
    my ($self) = @_;

    my $state = $self->get_state();
    my $provisioned = $state->{isProvisioned};
    if (defined $provisioned and $provisioned) {
        return 1;
    }
    return 0;
}

sub setProvisioned
{
    my ($self, $provisioned) = @_;

    my $state = $self->get_state();
    $state->{isProvisioned} = $provisioned;
    $self->set_state($state);
}

sub _setupSOGoDatabase
{
    my ($self) = @_;

    my $dbUser = $self->_sogoDbUser();
    my $dbPass = $self->_sogoDbPass();
    my $dbName = $self->_sogoDbName();
    my $dbHost = '127.0.0.1';

    my $db = EBox::DBEngineFactory::DBEngine();
    $db->enableInnoDBIfNeeded();
    $db->sqlAsSuperuser(sql => "CREATE DATABASE IF NOT EXISTS $dbName");
    $db->sqlAsSuperuser(sql => "GRANT ALL ON $dbName.* TO $dbUser\@$dbHost " .
                               "IDENTIFIED BY \"$dbPass\";");
    $db->sqlAsSuperuser(sql => 'flush privileges;');
}

sub _sogoDbName
{
    my ($self) = @_;

    return 'sogo';
}

sub _sogoDbUser
{
    my ($self) = @_;

    my $dbUser = EBox::Config::configkey('sogo_dbuser');
    return (length $dbUser > 0 ? $dbUser : 'sogo');
}

sub _sogoDbPass
{
    my ($self) = @_;

    # Return value if cached
    if (defined $self->{sogo_db_password}) {
        return $self->{sogo_db_password};
    }

    # Cache and return value if user configured
    my $dbPass = EBox::Config::configkey('sogo_dbpass');
    if (length $dbPass) {
        $self->{sogo_db_password} = $dbPass;
        return $dbPass;
    }

    # Otherwise, read from file
    my $path = EBox::Config::conf() . "sogo_db.passwd";

    # If file does not exists, generate random password and stash to file
    if (not -f $path) {
        my $generator = new String::Random();
        my $pass = $generator->randregex('\w\w\w\w\w\w\w\w');

        my ($login, $password, $uid, $gid) = getpwnam(EBox::Config::user());
        EBox::Module::Base::writeFile($path, $pass,
            { mode => '0600', uid => $uid, gid => $gid });
        $self->{sogo_db_password} = $pass;
        return $pass;
    }

    unless (defined ($self->{sogo_db_password})) {
        open (PASSWD, $path) or
            throw EBox::Exceptions::External('Could not get SOGo DB password');
        my $pwd = <PASSWD>;
        close (PASSWD);

        $pwd =~ s/[\n\r]//g;
        $self->{sogo_db_password} = $pwd;
    }

    return $self->{sogo_db_password};
}

# setup the dns to add autodiscover host
sub _setupDNS
{
    my ($self) = @_;
    my $sysinfo    = $self->global()->modInstance('sysinfo');
    my $hostDomain = $sysinfo->hostDomain();
    my $hostName   = $sysinfo->hostName();
    my $autodiscoverAlias = 'autodiscover';
    if ("$autodiscoverAlias.$hostName"  eq $hostDomain) {
        # strangely the hostname is already the autodiscover name
        return;
    }

    my $dns = $self->global()->modInstance('dns');

    my $domainRow = $dns->model('DomainTable')->find(domain => $hostDomain);
    if (not $domainRow) {
        throw EBox::Exceptions::External(
            __x("The expected domain '{d}' could not be found in the dns module",
                d => $hostDomain
               )
           );
    }

    my $hostRow = $domainRow->subModel('hostnames')->find(hostname => $hostName);
    if (not $hostRow) {
        throw EBox::Exceptions::External(
          __x("The required host record '{h}' could not be found in " .
              "the domain '{d}'.<br/>",
              h => $hostName,
              d => $hostDomain
             )
         );
    }

    my $aliasModel = $hostRow->subModel('alias');
    if ($aliasModel->find(alias => $autodiscoverAlias)) {
        # already added, nothing to do
        return;
    }
    # add the autodiscover alias
    $aliasModel->addRow(alias => $autodiscoverAlias);
}


# Method: configurationContainer
#
#   Return the ExchConfigurationContainer object that models the msExchConfigurationConainer entry for this
#   installation.
#
# Returns:
#
#   EBox::OpenChange::ExchConfigurationContainer object.
#
sub configurationContainer
{
    my ($self) = @_;

    my $sambaMod = $self->global->modInstance('samba');
    unless ($sambaMod->isEnabled() and $sambaMod->isProvisioned()) {
        return undef;
    }
    my $defaultNC = $sambaMod->ldb()->dn();
    my $dn = "CN=Microsoft Exchange,CN=Services,CN=Configuration,$defaultNC";

    my $object = new EBox::OpenChange::ExchConfigurationContainer(dn => $dn);
    if ($object->exists) {
        return $object;
    } else {
        return undef;
    }
}

# Method: organizations
#
#   Return a list of ExchOrganizationContainer objects that belong to this installation.
#
# Returns:
#
#   An array reference of ExchOrganizationContainer objects.
#
sub organizations
{
    my ($self) = @_;

    my $list = [];
    my $sambaMod = $self->global->modInstance('samba');
    my $configurationContainer = $self->configurationContainer();

    return $list unless ($configurationContainer);

    my $params = {
        base => $configurationContainer->dn(),
        scope => 'one',
        filter => '(objectclass=msExchOrganizationContainer)',
        attrs => ['*'],
    };
    my $result = $sambaMod->ldb()->search($params);
    foreach my $entry ($result->sorted('cn')) {
        my $organization = new EBox::OpenChange::ExchOrganizationContainer(entry => $entry);
        push (@{$list}, $organization);
    }

    return $list;
}

1;
