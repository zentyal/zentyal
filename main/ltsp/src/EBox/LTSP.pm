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
            printableName => __('LTSP'),
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
        'EBox::LTSP::Model::Clients',
        'EBox::LTSP::Model::Profiles',
        'EBox::LTSP::Model::GeneralOpts',
        'EBox::LTSP::Model::OtherOpts',
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
             'reason' => __('To configure LTSP clients.')
        },
    ];
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
        'text' => __('Thin Clients'),
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
    my ($self) = @_;

    my $sound       = $self->row()->valueByName('sound');
    my $one_session = $self->row()->valueByName('one_session');
    my $local_apps  = $self->row()->valueByName('local_apps');
    my $local_dev   = $self->row()->valueByName('local_dev');
    my $server      = $self->row()->valueByName('server');

    my %opts;

    if ( $sound ne 'default' ) {
        $opts{'SOUND'} = $sound;
    }

    if ( $one_session ne 'default' ) {
        $opts{'LDM_LIMIT_ONE_SESSION'} = $one_session;
    }

    if ( $local_apps ne 'default' ) {
        $opts{'LOCAL_APPS'} = $local_apps;
    }

    if ( $local_dev ne 'default' ) {
        $opts{'LOCALDEV'} = $local_dev;
    }

    if ( defined $server ) {
        $opts{'SERVER'} = $server;
    }

    return \%opts;
}

sub _getOtherOptions
{
    my ($self) = @_;

    my %otherOpt;

    for my $id (@{$self->ids()}) {
        my $row = $self->row($id);

        my $option = $row->valueByName('option');
        my $value  = $row->valueByName('value');

        $otherOpt{$option} = $value;
    }

    return \%otherOpt;
}

sub _getGlobalOptions()
{
    my $mgr = EBox::Model::ModelManager->instance();
    my $model_general = $mgr->model('ltsp/GeneralOpts');
    my $model_other   = $mgr->model('ltsp/OtherOpts');

    my $general = _getGeneralOptions($model_general);
    my $other   = _getOtherOptions($model_other);

    return { %{$general}, %{$other} };
}

sub _getProfilesOptions
{
    my @profiles;

    my $mgr = EBox::Model::ModelManager->instance();
    my $profile_list = $mgr->model('ltsp/Profiles');

    for my $id (@{$profile_list->ids()}) {
        my $row = $profile_list->row($id);

        my $name = $row->valueByName('name');
        my %options;

        my $submodel = $row->subModel('configuration');

        my $model_general = $submodel->componentByName('GeneralOpts');
        my $model_other   = $submodel->componentByName('OtherOpts');

        my $general = _getGeneralOptions($model_general);
        my $other   = _getOtherOptions($model_other);

        push(@profiles, { name => $name, options => { %{$general}, %{$other} }, } );
    }

    return \@profiles;
}

sub _getClientsOptions
{
    return [];
}

# Method: _writeConfiguration
#
#   This method uses a mason template to generate and write the configuration
#   for /var/lib/tftpboot/ltsp/i386/lts.conf # FIXME
#
sub _writeConfiguration
{
    my ($self) = @_;

    my $global   = _getGlobalOptions();
    my $profiles = _getProfilesOptions();
    my $clients  = _getClientsOptions();

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
