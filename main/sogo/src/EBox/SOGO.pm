# Copyright (C) 2013-2016 Zentyal S.L.
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

package EBox::SOGO;

use base qw(EBox::Module::Service);

use EBox::Config;
use EBox::Exceptions::External;
use EBox::Exceptions::Sudo::Command;
use EBox::Gettext;
use EBox::Service;
use EBox::Sudo;

use TryCatch;

use constant SOGO_PORT => 20000;
use constant SOGO_DEFAULT_PREFORK => 3;
use constant SOGO_APACHE_CONF => '/etc/apache2/conf-available/sogo.conf';

use constant SOGO_DEFAULT_FILE => '/etc/default/sogo';
use constant SOGO_CONF_FILE => '/etc/sogo/sogo.conf';
use constant SOGO_PID_FILE => '/var/run/sogo/sogo.pid';
use constant SOGO_LOG_FILE => '/var/log/sogo/sogo.log';

use constant APACHE_PORTS_FILE => '/etc/apache2/ports.conf';

# Group: Protected methods

# Constructor: _create
#
#        Create an module
#
# Overrides:
#
#        <EBox::Module::Service::_create>
#
# Returns:
#
#        <EBox::WebMail> - the recently created module
#
sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'sogo',
                                      printableName => __('SOGo Webmail'),
                                      @_);
    bless($self, $class);
    return $self;
}

# Method: _setConf
#
#        Regenerate the configuration
#
# Overrides:
#
#       <EBox::Module::Service::_setConf>
#
sub _setConf
{
    my ($self) = @_;

    if ($self->isEnabled()) {
        my $global = $self->global();
        my $sysinfoMod = $global->modInstance('sysinfo');

        my @params = ();
        push (@params, hostname => $sysinfoMod->fqdn());
        # FIXME: customize port via sogo.conf or modify apache conf directly and not even set this
        push (@params, sslPort  => 443);
        $self->writeConfFile(SOGO_APACHE_CONF, "sogo/zentyal-sogo.mas", \@params);

        $self->_writeSOGoDefaultFile();
        $self->_writeSOGoConfFile();
        $self->_setupSOGoDatabase();

#FIXME        $self->_setApachePortsConf();

        $self->_setupActiveSync();

        try {
            EBox::Sudo::root("a2enconf zentyal-sogo");
        } catch (EBox::Exceptions::Sudo::Command $e) {
            # Already enabled?
            if ($e->exitValue() != 1) {
                $e->throw();
            }
        }
    } else {
        try {
            EBox::Sudo::root("a2disconf zentyal-sogo");
        } catch (EBox::Exceptions::Sudo::Command $e) {
            # Already disabled?
            if ($e->exitValue() != 1) {
                $e->throw();
            }
        }
    }
}

# Group: Public methods

# Method: actions
#
#        Explain the actions the module must make to configure the
#        system. Check overriden method for details
#
# Overrides:
#
#        <EBox::Module::Service::actions>
sub actions
{
    return [
            {
             'action' => __('Enable proxy, proxy_http and headers Apache 2 modules.'),
             'reason' => __('To make SOGo Webmail be accesible at http://ip/SOGo/.'),
             'module' => 'sogo'
            },
    ];
}

# Method: enableActions
#
#        Run those actions explain by <actions> to enable the module
#
# Overrides:
#
#        <EBox::Module::Service::enableActions>
#
sub enableActions
{
    my ($self) = @_;

    my $mail = EBox::Global->modInstance('mail');
    unless ($mail->imap() or $mail->imaps()) {
        throw EBox::Exceptions::External(__x('SOGo Webmail module needs IMAP or IMAPS service enabled if ' .
                                             'using Zentyal mail service. You can enable it at ' .
                                             '{openurl}Mail -> General{closeurl}.',
                                             openurl => q{<a href='/Mail/Composite/General'>},
                                             closeurl => q{</a>}));
    }

    # Execute enable-module script
    $self->SUPER::enableActions();
}

# Method: usedFiles
#
# Overrides:
#
# <EBox::Module::Service::usedFiles>
#
sub usedFiles
{
    my @files = ();
    push (@files, {
        file => SOGO_DEFAULT_FILE,
        reason => __('To configure sogo daemon'),
        module => 'sogo'
    });
    push (@files, {
        file => SOGO_CONF_FILE,
        reason => __('To configure sogo parameters'),
        module => 'sogo'
    });
    push (@files, {
        file => SOGO_APACHE_CONF,
        reason => __('To make SOGo webmail available'),
        module => 'sogo'
    });

    return \@files;
}

sub _daemons
{
    return [ { 'name' => 'sogo', 'type' => 'init.d' } ];
}

# Method: initialSetup
#
# Overrides:
#
#        <EBox::Module::Base::initialSetup>
#
sub initialSetup
{
    my ($self, $version) = @_;

    if ((defined ($version)) and (EBox::Util::Version::compare($version, '3.4.1') < 0)) {
        try {
            EBox::Sudo::root("a2dissite zentyal-sogo");
        } catch (EBox::Exceptions::Sudo::Command $e) {
            # Already disabled?
            if ($e->exitValue() != 1) {
                $e->throw();
            }
        }
        EBox::Sudo::silentRoot("rm -f /etc/apache2/sites-available/zentyal-sogo.conf");

        # Force a configuration dump
        $self->save();
    }
}

sub _postServiceHook
{
    my ($self, $enabled) = @_;

    if ($enabled) {
        EBox::Sudo::root('systemctl restart sogo');
        # FIXME: common way to restart apache for sogo and
        #        activesync only if there are changes?
        #        currently we are doing more than necessary
        EBox::Sudo::root('systemctl restart apache2');
    }
}

# FIXME: is this needed?
#sub _setApachePortsConf
#{
#    my ($self) = @_;
#
#    my $params = [];
#    push (@{$params}, bindAddress => '0.0.0.0');
#    push (@{$params}, port        => APACHE_PORT_HTTP);
#    push (@{$params}, sslPort     => APACHE_PORT_HTTPS);
#    $self->writeConfFile(APACHE_PORTS_FILE,
#                         'openchange/apache-ports.conf.mas',
#                         $params);
#}

sub _setupActiveSync
{
    my ($self) = @_;

    my $enabled = (-f '/etc/apache2/conf-enabled/zentyal-activesync.conf');
    my $enable = $self->model('ActiveSync')->value('activesync');
    if ($enabled xor $enable) {
        if ($enable) {
            EBox::Sudo::root('a2enconf zentyal-activesync');
        } else {
            EBox::Sudo::silentRoot('a2disconf zentyal-activesync');
        }
        my $global = $self->global();
        if ($global->modExists('sogo')) {
            $global->addModuleToPostSave('sogo');
        }
    }
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

    my $users = $self->global->modInstance('samba');
    my $dcHostName = $users->ldap()->rootDse->get_value('dnsHostName');
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

    my $sogoDbEngine = $self->_sogoDBEngine();
    my $dbName = $sogoDbEngine->_dbname();
    my $dbUser = $sogoDbEngine->_dbuser();
    my $dbPass = $sogoDbEngine->_dbpass();
    push (@{$array}, dbName => $dbName);
    push (@{$array}, dbUser => $dbUser);
    push (@{$array}, dbPass => $dbPass);
    push (@{$array}, dbHost => '127.0.0.1');
    push (@{$array}, dbPort => 3306);

    my $baseDN = $self->ldap->dn();
    if (EBox::Config::boolean('openchange_disable_multiou')) {
        $baseDN = "ou=Users,$baseDN";
    }

    push (@{$array}, sambaBaseDN => $users->ldap()->dn());
    push (@{$array}, sambaBindDN => $self->_kerberosServiceAccountDN());
    push (@{$array}, sambaBindPwd => $self->_kerberosServiceAccountPassword());
    push (@{$array}, sambaHost => "ldap://127.0.0.1"); #FIXME? not working using $users->ldap()->url()

    my (undef, undef, undef, $gid) = getpwnam('sogo');
    $self->writeConfFile(SOGO_CONF_FILE,
        'openchange/sogo.conf.mas',
        $array, { uid => 0, gid => $gid, mode => '640' });
}

sub _sogoDumpFile
{
    my ($self, $dir) = @_;
    return $dir . '/sogo.dump';
}

sub dumpConfig
{
    my ($self, $dir) = @_;

    if (not $self->configured()) {
        return;
    }

    # backup now sogo database
    my $dumpFile = $self->_sogoDumpFile($dir);
    my $dbengine = $self->_sogoDBEngine();
    $dbengine->dumpDB($dumpFile);
}

sub restoreConfig
{
    my ($self, $dir, @params) = @_;

    $self->stopService();

    $self->SUPER::restoreConfig($dir, @params);

    if ($self->configured()) {
        # load sogo database data
        my $dumpFile = $self->_sogoDumpFile($dir);
        if (-r $dumpFile) {
            my $dbengine = $self->_sogoDBEngine();
            $dbengine->restoreDBDump($dumpFile);
        }
    }

    $self->_startService();
}

1;
