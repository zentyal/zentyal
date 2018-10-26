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

package EBox::SOGo;

use base qw(EBox::Module::Service);

use EBox::Config;
use EBox::DBEngineFactory;
use EBox::SOGo::DBEngine;
use EBox::Exceptions::External;
use EBox::Exceptions::Sudo::Command;
use EBox::Gettext;
use EBox::Service;
use EBox::Sudo;

use TryCatch;

use constant SOGO_DEFAULT_PREFORK => 3;
use constant SOGO_ACTIVESYNC_PREFORK => 15;
use constant SOGO_DEFAULT_FILE => '/etc/default/sogo';
use constant SOGO_CONF_FILE => '/etc/sogo/sogo.conf';
use constant SOGO_APACHE_FILE => '/etc/apache2/conf-available/SOGo.conf';

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

# Method: initialSetup
#
# Overrides:
#
#   EBox::Module::Base::initialSetup
#
sub initialSetup
{
    my ($self, $version) = @_;

    unless ($version) {
        my $firewall = $self->global()->modInstance('firewall');
        $firewall->setInternalService('HTTPS', 'accept');
        $firewall->saveConfigRecursive();
    }

    if ($self->changed()) {
        $self->saveConfigRecursive();
    }
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
        $self->_writeSOGoDefaultFile();
        $self->_writeSOGoConfFile();
        $self->_writeSOGoApacheFile();
        $self->_setupSOGoDatabase();

        try {
            EBox::Sudo::root("a2enconf SOGo");
        } catch (EBox::Exceptions::Sudo::Command $e) {
            # Already enabled?
            if ($e->exitValue() != 1) {
                $e->throw();
            }
        }
    } else {
        try {
            EBox::Sudo::root("a2disconf SOGo");
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

    return \@files;
}

sub _daemons
{
    return [ { 'name' => 'sogo' } ];
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

sub _activeSyncEnabled
{
    my ($self) = @_;

    return $self->model('ActiveSync')->value('activesync');
}

sub _writeSOGoDefaultFile
{
    my ($self) = @_;

    my $array = [];
    my $prefork = EBox::Config::configkey('sogod_prefork');
    unless (length $prefork) {
        $prefork = $self->_activeSyncEnabled() ? SOGO_ACTIVESYNC_PREFORK : SOGO_DEFAULT_PREFORK;
    }
    push (@{$array}, prefork => $prefork);
    $self->writeConfFile(SOGO_DEFAULT_FILE,
        'sogo/sogo.mas',
        $array, { uid => 0, gid => 0, mode => '755' });
}

sub _writeSOGoApacheFile
{
    my ($self) = @_;

    my $array = [];
    push (@{$array}, activesync => $self->_activeSyncEnabled());
    $self->writeConfFile(SOGO_APACHE_FILE,
        'sogo/SOGo.conf-apache.mas',
        $array, { uid => 0, gid => 0, mode => '755' });
}

sub _writeSOGoConfFile
{
    my ($self) = @_;

    my $array = [];

    my $global = $self->global();
    my $sysinfo = $global->modInstance('sysinfo');
    my $timezoneModel = $sysinfo->model('TimeZone');
    my $sogoTimeZone = $timezoneModel->row->printableValueByName('timezone');

    my $ldap = $global->modInstance('samba')->ldap();
    my $dcHostName = $ldap->rootDse->get_value('dnsHostName');
    my (undef, $sogoMailDomain) = split (/\./, $dcHostName, 2);

    push (@{$array}, sogoTimeZone => $sogoTimeZone);
    push (@{$array}, sogoMailDomain => $sogoMailDomain);

    my $mail = $global->modInstance('mail');
    my $retrievalServices = $mail->model('RetrievalServices');
    my $sieveEnabled = $retrievalServices->value('managesieve');
    my $sieveServer = ($sieveEnabled ? 'sieve://127.0.0.1:4190' : '');
    my $imapServer = ($mail->imap() ? '127.0.0.1:143' : 'imaps://127.0.0.1:993');
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

    push (@{$array}, sambaBaseDN => $ldap->dn());
    push (@{$array}, sambaBindDN => $mail->_kerberosServiceAccountDN());
    push (@{$array}, sambaBindPwd => $mail->_kerberosServiceAccountPassword());
    push (@{$array}, sambaHost => "ldap://127.0.0.1");

    push (@{$array}, activesync => $self->_activeSyncEnabled());

    my (undef, undef, undef, $gid) = getpwnam('sogo');
    $self->writeConfFile(SOGO_CONF_FILE,
        'sogo/sogo.conf.mas',
        $array, { uid => 0, gid => $gid, mode => '640' });
}

sub _setupSOGoDatabase
{
    my ($self) = @_;

    my $sogoDB = $self->_sogoDBEngine();
    my $dbUser = $sogoDB->_dbuser();
    my $dbPass = $sogoDB->_dbpass();
    my $dbName = $sogoDB->_dbname();
    my $dbHost = '127.0.0.1';

    my $db = EBox::DBEngineFactory::DBEngine();
    $db->updateMysqlConf();
    $db->sqlAsSuperuser(sql => "CREATE DATABASE IF NOT EXISTS $dbName");
    $db->sqlAsSuperuser(sql => "GRANT ALL ON $dbName.* TO $dbUser\@$dbHost " .
                               "IDENTIFIED BY \"$dbPass\";");
    $db->sqlAsSuperuser(sql => 'flush privileges;');
}

sub _sogoDBEngine
{
    my ($self) = @_;
    if (not $self->{'_sogoDBengine'}) {
        $self->{'_sogoDBengine'} = EBox::SOGo::DBEngine->new();
    }

    return $self->{'_sogoDBengine'};
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

# Method: menu
#
#   Add an entry to the menu with this module.
#
sub menu
{
    my ($self, $root) = @_;

    my $folder = new EBox::Menu::Folder(
        'name' => 'Mail',
        'icon' => 'mail',
        'text' => __('Mail'),
        'tag' => 'main',
        'order' => 4
    );

    $folder->add(new EBox::Menu::Item(
        url => 'Mail/ActiveSync',
        text => __('ActiveSync®'),
        order => 3)
    );

    $root->add($folder);
}

1;
