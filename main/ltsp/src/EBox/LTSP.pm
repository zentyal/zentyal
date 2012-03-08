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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

# Class: EBox::LTSP
#
#   TODO: Documentation

package EBox::LTSP;

use base qw(EBox::Module::Service
            EBox::Model::ModelProvider
            EBox::Model::CompositeProvider);

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;
use EBox::Sudo;

use EBox::Validate qw( :all );
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::DataMissing;
use EBox::Exceptions::DataNotFound;

use constant CONF_FILE => '/var/lib/tftpboot/ltsp/i386/lts.conf'; # FIXME


# Method: _create
#
# Overrides:
#
#       <Ebox::Module::_create>
#
sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'ltsp',
            printableName => __('Thin Clients'),
            @_);
    bless ($self, $class);
    return $self;
}

# Method: modelClasses
#
# Overrides:
#
#       <EBox::Model::ModelProvider::modelClasses>
#
sub modelClasses
{
    return [
        'EBox::LTSP::Model::GeneralOpts',
        'EBox::LTSP::Model::Clients',
        'EBox::LTSP::Model::Profiles',
        'EBox::LTSP::Model::OtherOpts',
        'EBox::LTSP::Model::GeneralClientOpts',
        'EBox::LTSP::Model::AutoLogin',
    ];
}

# Method: compositeClasses
#
# Overrides:
#
#       <EBox::Model::ModelProvider::compositeClasses>
#
sub compositeClasses
{
    return [
        'EBox::LTSP::Composite::Composite',
        'EBox::LTSP::Composite::Configuration',
        'EBox::LTSP::Composite::ClientConfiguration',
    ];
}

# Method: actions
#
# Overrides:
#
#       <EBox::Module::Service::actions>
#
sub actions
{
    return [
#        {
#            'action' => __('Add LTSP LDAP schema'),
#            'reason' => __('Zentyal will need this schema to store LTSP users.'),
#            'module' => 'ebox-ltsp'
#        },
    ];
}

# Method: enableActions
#
# Overrides:
#
#       <EBox::Module::Service::enableActions>
#
sub enableActions
{
    my ($self) = @_;

    # Execute enable-module script
    $self->SUPER::enableActions();
}

# Method: usedFiles
#
# Overrides:
#
#       <EBox::Module::Service::usedFiles>
#
sub usedFiles
{
    return [
        {
             'file' => CONF_FILE,
             'module' => 'ltsp',
             'reason' => __('To configure the Thin Clients.')
        },
    ];
}

# Method: _supportActions
#
#   This method determines if the service will have a button to start/restart
#   it in the module status widget. By default services will have the button
#   unless this method is overriden to return undef
#
# Overrides:
#
#       <EBox::Module::ServiceBase>
#
sub _supportActions
{
    return undef;
}

# Method: menu
#
# Overrides:
#
#       <EBox::Module::menu>
#
sub menu
{
    my ($self, $root) = @_;

    my $settings = new EBox::Menu::Item(
        'url' => 'LTSP/Composite/Composite',
        'text' => $self->printableName(),
        'separator' => 'Infrastructure',
        'order' => 450,
    );

    $root->add($settings);
}

# Method: depends
#
# Overrides:
#
#     <EBox::Module::Base::depends>
#
sub depends
{
    my ($self) = @_;

    my $dependsList = $self->SUPER::depends();

    return $dependsList;

}

# Method: enableModDepends
#
# Overrides:
#
#     <EBox::Module::Base::enableModDepends>
#
sub enableModDepends
{
    my ($self) = @_;

    my $dependsList = $self->SUPER::enableModDepends();
    push(@{$dependsList}, 'network');

    return $dependsList;
}

# Method: _daemons
#
# Overrides:
#
#       <EBox::Module::Service::_daemons>
#
sub _daemons
{
    my $daemons = [
#        {
#            'name' => 'service',
#            'type' => 'init.d',
#            'pidfiles' => ['/var/run/service.pid']
#        },
    ];

    return $daemons;
}

sub _getGeneralOptions
{
    my ($self,$model) = @_;

    my $disable_screen_lock = $model->row()->valueByName('disable_screen_lock');
    unless ( $disable_screen_lock eq 'default' ) {
        EBox::Sudo::root('gconftool-2 --direct --config-source ' .
                         'xml:readwrite:/etc/gconf/gconf.xml.mandatory ' .
                         '--set --type boolean ' .
                         "/desktop/gnome/lockdown/disable_lock_screen $disable_screen_lock " .
                         "/apps/panel/global/disable_lock_screen $disable_screen_lock");
    }

    my $one_session = $model->row()->valueByName('one_session');
    my $sound       = $model->row()->valueByName('sound');
    my $local_apps  = $model->row()->valueByName('local_apps');
    my $local_dev   = $model->row()->valueByName('local_dev');
    my $autologin   = $model->row()->valueByName('autologin');
    my $guestlogin  = $model->row()->valueByName('guestlogin');

    my $server      = $model->row()->elementByName('server')->ip();
    my $time_server = $model->row()->elementByName('time_server')->ip();

    my $shutdown_time;
    if ( $model->row()->elementByName('shutdown')->selectedType() eq 'shutdown_time') {
        $shutdown_time = $model->row()->printableValueByName('shutdown_time');
    } else {
        $shutdown_time = undef;
    }

    my %opts;

    if ( $one_session ne 'default' ) {
        $opts{'LDM_LIMIT_ONE_SESSION'} = $one_session;
    }

    if ( $sound ne 'default' ) {
        $opts{'SOUND'} = $sound;
    }

    if ( $local_apps ne 'default' ) {
        $opts{'LOCAL_APPS'} = $local_apps;
    }

    if ( $local_dev ne 'default' ) {
        $opts{'LOCALDEV'} = $local_dev;
    }

    if ( $autologin ne 'default' ) {
        $opts{'LDM_AUTOLOGIN'} = $autologin;
    }

    if ( $guestlogin ne 'default' ) {
        $opts{'LDM_ALLOW_GUEST'} = $guestlogin;
    }

    if ( defined $server ) {
        $opts{'SERVER'} = $server;
    }

    if ( defined $time_server ) {
        $opts{'TIMESERVER'} = $time_server;
    }

    if ( defined $shutdown_time ) {
        $opts{'SHUTDOWN_TIME'} = $shutdown_time;
    }

    return \%opts;
}

sub _getOtherOptions
{
    my ($self,$model) = @_;

    my %otherOpt;

    for my $id (@{$model->ids()}) {
        my $row = $model->row($id);

        if ( $row->valueByName('enabled') ) {
            my $option = $row->valueByName('option');
            my $value  = $row->valueByName('value');

            $otherOpt{$option} = $value;
        }
    }

    return \%otherOpt;
}

sub _getGlobalOptions()
{
    my ($self) = @_;

    my $model_general = $self->model('ltsp/GeneralOpts');
    my $model_other   = $self->model('ltsp/OtherOpts');

    my $general = $self->_getGeneralOptions($model_general);
    my $other   = $self->_getOtherOptions($model_other);

    return { %{$general}, %{$other} };
}

sub _getGeneralProfileOptions
{
    my ($self,$model) = @_;

    my $sound       = $model->row()->valueByName('sound');
    my $local_apps  = $model->row()->valueByName('local_apps');
    my $local_dev   = $model->row()->valueByName('local_dev');
    my $autologin   = $model->row()->valueByName('autologin');
    my $guestlogin  = $model->row()->valueByName('guestlogin');

    my $server      = $model->row()->elementByName('server')->ip();
    my $time_server = $model->row()->elementByName('time_server')->ip();

    my $shutdown_time;
    if ( $model->row()->elementByName('shutdown')->selectedType() eq 'shutdown_time') {
        $shutdown_time = $model->row()->printableValueByName('shutdown_time');
    } else {
        $shutdown_time = undef;
    }

    my %opts;

    if ( $sound ne 'default' ) {
        $opts{'SOUND'} = $sound;
    }

    if ( $local_apps ne 'default' ) {
        $opts{'LOCAL_APPS'} = $local_apps;
    }

    if ( $local_dev ne 'default' ) {
        $opts{'LOCALDEV'} = $local_dev;
    }

    if ( $autologin ne 'default' ) {
        $opts{'LDM_AUTOLOGIN'} = $autologin;
    }

    if ( $guestlogin ne 'default' ) {
        $opts{'LDM_ALLOW_GUEST'} = $guestlogin;
    }

    if ( defined $server ) {
        $opts{'SERVER'} = $server;
    }

    if ( defined $time_server ) {
        $opts{'TIMESERVER'} = $time_server;
    }

    if ( defined $shutdown_time ) {
        $opts{'SHUTDOWN_TIME'} = $shutdown_time;
    }

    return \%opts;
}

sub _getProfilesOptions
{
    my ($self) = @_;

    my @profiles;

    my $profile_list = $self->model('ltsp/Profiles');

    for my $id (@{$profile_list->ids()}) {
        my $row = $profile_list->row($id);

        my $name = $row->valueByName('name');

        my $submodel = $row->subModel('configuration');

        my $model_general = $submodel->componentByName('GeneralClientOpts');
        my $model_other   = $submodel->componentByName('OtherOpts');

        my $general = $self->_getGeneralProfileOptions($model_general);
        my $other   = $self->_getOtherOptions($model_other);

        push(@profiles, { name => $name, options => { %{$general}, %{$other} }, } );
    }

    return \@profiles;
}

sub _getClientsOptions
{
    my ($self) = @_;

    my %clients;

    my $client_list = $self->model('ltsp/Clients');

    my $global  = EBox::Global->getInstance();
    my $objMod = $global->modInstance('objects');

    my $profile_list = $self->model('ltsp/Profiles');

    for my $id (@{$client_list->ids()}) {
        my $row = $client_list->row($id);

        my $enabled = $row->valueByName('enabled');
        if ($enabled) {
            my $profile_id = $row->valueByName('profile');
            my $row_prof   = $profile_list->row($profile_id);
            my $profile    = $row_prof->valueByName('name');

            my $object_id = $row->valueByName('object');
            my $object    = $objMod->objectMembers($object_id);

            foreach my $member (@{$object}) {

                if ( defined $member->{'macaddr'} ) {
                    $clients{$member->{'macaddr'}}->{profile} = $profile;
                }
            }
        }
    }

    return \%clients;
}

sub _addAutoLoginConf
{
    my ($self,$clients) = @_;

    my $autologin_list = $self->model('ltsp/AutoLogin');

    for my $id (@{$autologin_list->ids()}) {
        my $row = $autologin_list->row($id);

        my $enabled = $row->valueByName('enabled');
        if ($enabled) {
            my $mac  = $row->valueByName('mac');
            my $user = $row->valueByName('user');
            my $pass = $row->valueByName('password');

            $clients->{$mac}->{user} = $user;
            $clients->{$mac}->{pass} = $pass;
        }
    }
}

# Method: _writeConfiguration
#
#   This method uses a mason template to generate and write the configuration
#   for /var/lib/tftpboot/ltsp/i386/lts.conf # FIXME
#
sub _writeConfiguration
{
    my ($self) = @_;

    my $global   = $self->_getGlobalOptions();
    my $profiles = $self->_getProfilesOptions();
    my $clients  = $self->_getClientsOptions();

    $self->_addAutoLoginConf($clients);

    my @params = (
        global  => $global,
        profiles => $profiles,
        clients  => $clients,
    );
    $self->writeConfFile(CONF_FILE, "ltsp/lts.conf.mas", \@params);
}

# Method: _setConf
#
#       Overrides base method. It writes the LTSP configuration
#
sub _setConf
{
    my ($self) = @_;
    $self->_writeConfiguration();
}


1;
