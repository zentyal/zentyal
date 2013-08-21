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
use EBox::OpenChange::LdapUser;
use EBox::DBEngineFactory;

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

    unless ($version) {
        # TODO mkdir /root/GNUstep/Defaults/
        # TODO mkdir /var/lib/sogo/GNUstep/Defaults

#        my $firewall = EBox::Global->modInstance('firewall');
#        $firewall or
#            return;
#        $firewall->addServiceRules($self->_serviceRules());
#        $firewall->saveConfigRecursive();
    }
}

# Method: enableActions
#
#       Override EBox::Module::Service::enableService to notify mail
#
sub enableService
{
    my ($self, $status) = @_;

    $self->SUPER::enableService($status);
#    if ($self->changed()) {
#        my $mail = EBox::Global->modInstance('mail');
#        $mail->setAsChanged();
#    }
}

sub _daemons
{
    my $daemons = [];
    push (@{$daemons}, {
        name => 'sogo',
        type => 'init.d',
        pidfiles => ['/var/run/sogo/sogo.pid']});

    return $daemons;
}

sub _setConf
{
    my ($self) = @_;

    my $sysinfo = $self->global->modInstance('sysinfo');
    my $timezoneModel = $sysinfo->model('TimeZone');
    my $tz = $timezoneModel->row->printableValueByName('timezone');

    my $array = [];
    push (@{$array}, SOGoTimeZone => $tz);
    push (@{$array}, SOGoProfileURL => 'mysql://sogo:sogo@localhost:3306/sogo/sogo_user_profile');
    push (@{$array}, OCSFolderInfoURL => 'mysql://sogo:sogo@localhost:3306/sogo/sogo_folder_info');
    push (@{$array}, OCSSessionsFolderURL => 'mysql://sogo:sogo@localhost:3306/sogo/sogo_sessions_folder');
    push (@{$array}, WONoDetach => 'YES');
    push (@{$array}, WOLogFile => '/var/log/sogo/sogo.log');
    push (@{$array}, WOPidFile => '/var/run/sogo/sogo.pid');
    my $SOGoUserSources = {
        CNFieldName => 'cn',
        IDFieldName => 'uid',
        UIDFieldName => 'uid',
        IMAPHostFieldName => '',
        baseDN => 'ou=users,dc=oc,dc=local',
        bindDN => 'uid=Administrator,ou=users,dc=oc,dc=local',
        bindPassword => 'Administrator',
        canAuthenticate => 'YES',
        displayName => 'Shared Addresses',
        hostname => 'localhost',
        id => 'public',
        isAddressBook => 'YES',
        port => '3389',
    };
    push (@{$array}, SOGoUserSources => $SOGoUserSources);

    my @sogoUserInfo = getpwnam('sogo');
    $self->writeConfFile('/var/lib/sogo/GNUstep/Defaults/.GNUstepDefaults',
        'openchange/GNUstepDefaults.mas',
        $array, { uid => $sogoUserInfo[2], gid => $sogoUserInfo[3], mode => '600' });
    $self->writeConfFile('/root/GNUstep/Defaults/.GNUstepDefaults',
        'openchange/GNUstepDefaults.mas',
        $array, { uid => 0, gid => 0, mode => '600' });

    $self->_setupSOGoDatabase();
}

sub _setupSOGoDatabase
{
    my ($self) = @_;

    my $db = EBox::DBEngineFactory::DBEngine();
    $db->sqlAsSuperuser(sql => 'CREATE DATABASE IF NOT EXISTS sogo');
    $db->sqlAsSuperuser(sql => 'GRANT ALL ON sogo.* TO sogo@localhost IDENTIFIED BY "sogo";');
    $db->sqlAsSuperuser(sql => 'flush privileges;');
}

# Method: _postServiceHook
#
#     Override this method to setup shared folders.
#
# Overrides:
#
#     <EBox::Module::Service::_postServiceHook>
#
sub _postServiceHook
{
    my ($self, $enabled) = @_;

#    if ($enabled and -f FIRST_RUN_FILE) {
#        my $cmd = 'zarafa-admin -s';
#        EBox::Sudo::rootWithoutException($cmd);
#        unlink FIRST_RUN_FILE;
#    }

    return $self->SUPER::_postServiceHook($enabled);
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
        text      => __('Provision'),
        order     => 0));
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

1;
