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

use EBox::Dashboard::Section;
use EBox::Dashboard::List;

use Net::IP;

use constant CONF_DIR  => '/var/lib/tftpboot/ltsp';
use constant CONF_FILE => 'lts.conf';
use constant ARCHITECTURES => ['i386', 'amd64',]; #['i386', 'amd64', 'hppa', 'powerpc'];
use constant IMG_DIR => '/opt/ltsp/images';

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
        'EBox::LTSP::Model::AvailableImages',
        'EBox::LTSP::Model::LocalApps',
        'EBox::LTSP::Model::GeneralOpts',
        'EBox::LTSP::Model::Clients',
        'EBox::LTSP::Model::Profiles',
        'EBox::LTSP::Model::OtherClientOpts',
        'EBox::LTSP::Model::OtherOpts',
        'EBox::LTSP::Model::GeneralClientOpts',
        'EBox::LTSP::Model::ImageCreation',
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
        'EBox::LTSP::Composite::ClientImages',
        'EBox::LTSP::Composite::ClientConfiguration',
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

sub architectures
{
    return ARCHITECTURES;
}

sub images
{
    my ($self) = @_;

    my @images;

    for my $arch (@{$self->architectures}) {
        push( @images, IMG_DIR . "/$arch.img");
    }

    return \@images;
}

sub _confFiles
{
    my ($self) = @_;

    my @conf_files;

    for my $arch (@{$self->architectures}) {
        push( @conf_files, CONF_DIR . "/$arch/" . CONF_FILE);
    }

    return \@conf_files;
}

sub _confDirs
{
    my ($self) = @_;

    my @conf_dirs;

    for my $arch (@{$self->architectures}) {
        push( @conf_dirs, CONF_DIR . "/$arch/");
    }

    return \@conf_dirs;
}

# Method: usedFiles
#
# Overrides:
#
#       <EBox::Module::Service::usedFiles>
#
sub usedFiles
{
    my ($self) = @_;

    my @used_files;

    for my $file (@{$self->_confFiles}) {
        push( @used_files,
              {
                'file' => $file,
                'module' => 'ltsp',
                'reason' => __('To configure the Thin Clients.')
              });
    }

    return \@used_files;
}

# Method: _supportActions
#
#   This method determines if the service will have a button to start/restart
#   it in the module status widget. By default services will have the button
#   unless this method is overriden to return undef
#
# Overrides:
#
#       <EBox::Module::Service>
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

    my $one_session         = $model->row()->valueByName('one_session');
    my $network_compression = $model->row()->valueByName('network_compression');
    my $sound               = $model->row()->valueByName('sound');
    my $local_apps          = $model->row()->valueByName('local_apps');
    my $local_dev           = $model->row()->valueByName('local_dev');
    my $autologin           = $model->row()->valueByName('autologin');
    my $guestlogin          = $model->row()->valueByName('guestlogin');
    my $kb_layout           = $model->row()->valueByName('kb_layout');
    my $server              = $model->row()->elementByName('server')->ip();
    my $time_server         = $model->row()->elementByName('time_server')->ip();

    my $shutdown_time;
    if ( $model->row()->elementByName('shutdown')->selectedType() eq 'shutdown_time') {
        $shutdown_time = $model->row()->printableValueByName('shutdown_time');
    } else {
        $shutdown_time = undef;
    }

    my %opts;

    $opts{'LDM_LIMIT_ONE_SESSION'} = ($one_session ? 'True' : 'False');

    if ( $network_compression ) {
        $opts{'LDM_DIRECTX'}         = 'False';
        $opts{'NETWORK_COMPRESSION'} = 'True';
    } else {
        $opts{'LDM_DIRECTX'}         = 'True';
        $opts{'NETWORK_COMPRESSION'} = 'False';
    }

    if ( $local_apps ) {
        $opts{'LOCAL_APPS'}      = 'True';
        $opts{'LOCAL_APPS_MENU'} = 'True';
    } else {
        $opts{'LOCAL_APPS'}      = 'False';
        $opts{'LOCAL_APPS_MENU'} = 'False';
    }

    $opts{'LOCALDEV'} = ($local_dev ? 'True' : 'False');
    $opts{'LDM_AUTOLOGIN'} = ($autologin ? 'True' : 'False');
    $opts{'LDM_ALLOW_GUEST'} = ($guestlogin ? 'True' : 'False');
    $opts{'SOUND'} = ($sound ? 'True' : 'False');

    if ( defined $kb_layout ) {
        $opts{'XKBLAYOUT'}      = $kb_layout;
        $opts{'CONSOLE_KEYMAP'} = $kb_layout;
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

    if ( $local_apps  eq 'True' ) {
        $opts{'LOCAL_APPS'}      = 'True';
        $opts{'LOCAL_APPS_MENU'} = 'True';
    } elsif ( $local_apps  eq 'False' ) {
        $opts{'LOCAL_APPS'}      = 'False';
        $opts{'LOCAL_APPS_MENU'} = 'False';
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

    if ( $sound ne 'default' ) {
        $opts{'SOUND'} = $sound;
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

sub _getClientsOptions
{
    my ($self,$model,$profile) = @_;

    my %clients;

    my $client_list = $self->model('ltsp/Clients');

    my $global  = EBox::Global->getInstance();
    my $objMod = $global->modInstance('objects');

    for my $id (@{$model->ids()}) {
        my $row = $model->row($id);

        if ($row->valueByName('enabled')) {
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

sub _getProfilesOptions
{
    my ($self) = @_;

    my @profiles;
    my %clients;

    my $profile_list = $self->model('ltsp/Profiles');

    for my $id (@{$profile_list->ids()}) {
        my $row = $profile_list->row($id);

        if ( $row->valueByName('enabled') ) {
            my $name = $row->valueByName('name');

            my $submodel = $row->subModel('configuration');

            my $model_general = $submodel->componentByName('GeneralClientOpts');
            my $model_other   = $submodel->componentByName('OtherClientOpts');

            my $general = $self->_getGeneralProfileOptions($model_general);
            my $other   = $self->_getOtherOptions($model_other);

            # If empty profile, ignore the profile and its clients
            if (%$general or %$other) {
                push(@profiles, {
                                    name => $name,
                                    options => { %{$general}, %{$other} },
                                } );

                my $client_submodel = $row->subModel('clients');
                my $profile_clients = $self->_getClientsOptions($client_submodel, $name);
                @clients{keys %{$profile_clients}} = values %{$profile_clients};
            }
        }
    }

    return (\@profiles, \%clients);
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
#
sub _writeConfiguration
{
    my ($self) = @_;

    my $global              = $self->_getGlobalOptions();
    my ($profiles,$clients) = $self->_getProfilesOptions();

    $self->_addAutoLoginConf($clients);

    my @params = (
        global  => $global,
        profiles => $profiles,
        clients  => $clients,
    );

    for my $dir (@{$self->_confDirs}) {
        if (-d $dir) {
            $self->writeConfFile($dir . CONF_FILE, "ltsp/lts.conf.mas", \@params);
        }
    }
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


sub _who
{
    return `who`;
}

sub _leaseIDFromIP
{
    my ($ip) = @_;
    my $id = 'a';
    #force every byte to use 3 digits to make sorting trivial
    my @bytes = split('\.', $ip);
    for my $byte (@bytes) {
        $id .= sprintf("%03d", $byte);
    }
    return $id;
}

sub _ipInRange      # ($ip, $from, $to)
{
    my ($ip, $from, $to) = @_;

    my $ip_client = new Net::IP ($ip)            or return 0;
    my $ip_from   = new Net::IP ($from) or return 0;
    my $ip_to     = new Net::IP ($to)   or return 0;

    # $ip_from <= $ip_client <= $ip_to
    return ( ($ip_from->bincomp('le',$ip_client)) and
             ($ip_to->bincomp('ge',$ip_client)  ) );
}

sub _ipInObject     # ($ip, \@members)
{
    my ($ip,$members) = @_;

    my $ip_client = new Net::IP ($ip) or return 0;
    for my $member (@{$members}) {
        my $ip_member = new Net::IP ($member->{ip}) or return 0;

        if ($ip_client->ip() eq $ip_member->ip()) {
            return 1;
        }
    }

    return 0;
}

sub _ipIsLtspClient
{
    my ($self,$ip) = @_;

    my $gl = EBox::Global->getInstance();
    if ($gl->modEnabled('dhcp')) {
        my $dhcp = $gl->modInstance('dhcp');
        my $net  = $gl->modInstance('network');
        my $staticRoutes_r = $dhcp->staticRoutes();
        my $ifacesInfo = $dhcp->_ifacesInfo($staticRoutes_r);

        foreach my $ifaceInfo (values %{$ifacesInfo}) {
            foreach my $range (@{$ifaceInfo->{ranges}}) {
                if ( ( values %{$range->{options}} > 0 ) and  # Has thin clients
                     (_ipInRange($ip, $range->{from}, $range->{to})) ) {
                        return 1;
                }
            }
            foreach my $objFixed (values %{$ifaceInfo->{fixed}}) {
                if ( (values %{$objFixed->{options}} > 0) and # Has thin clients
                     (_ipInObject($ip, $objFixed->{members})) ) {
                    return 1;
                }
            }
        }
        return 0;
    }

    # Cannot check -> True
    return 1;
}

sub _lstpClients
{
    my ($self) = @_;

    my @client_list = $self->_who();
    @client_list or return {};

    my %clients;
    foreach my $client (@client_list) {
        if ($client =~ m/\((.*)\)/) {
            my $ip = $1;
            if ($self->_ipIsLtspClient($ip)) {
                my $id = _leaseIDFromIP($ip);
                my $user = (split(/ +/, $client))[0];
                $clients{$id} = {
                    ip   => $ip,
                    user => $user,
                };
            }
        }
     }

    return \%clients;
}

sub _ltspWidgetStatus   # ($self, $num_clients)
{
    my ($self, $num_clients) = @_;

    my $work = $self->st_get_string('work');
    if ( (defined $work) and ($work ne 'none')) {
        if ($work eq 'build') {
            return new EBox::Dashboard::Value( __('Status'), __("Building image") );
        } elsif ($work eq 'update') {
            return new EBox::Dashboard::Value( __('Status'), __("Updating image") );
        } elsif ($work eq 'install') {
            return new EBox::Dashboard::Value( __('Status'), __("Installing applications into an image") );
        } else {
            return new EBox::Dashboard::Value( __('Status'), __("Doing some into an image") );
        }
    } else {
        return new EBox::Dashboard::Value( __('Status'), __("$num_clients users connected to thin clients") );
    }
}

sub ltspClientsWidget
{
    my ($self, $widget) = @_;


    my $section = new EBox::Dashboard::Section('ltspclients');
    my $section_status = new EBox::Dashboard::Section('ltspstatus');

    my $titles = [__('Username'),__('IP address'),];

    my $clients = $self->_lstpClients();

    my $ids = [];
    my $rows = {};
    foreach my $id (sort keys %{$clients}) {
        my $client = $clients->{$id};
        push(@{$ids}, $id);
        $rows->{$id} = [$client->{user},$client->{ip},];
    }


    $section_status->add($self->_ltspWidgetStatus(scalar(keys %{$clients})));
    $widget->add($section_status);

    $section->add(new EBox::Dashboard::List(undef, $titles, $ids, $rows, 'No user connected in any thin client.'));
    $widget->add($section);
}

### Method: widgets
#
#   Overrides <EBox::Module::Base::widgets>
#
sub widgets
{
    my ($self) = @_;

    return {
        'ltspclients' => {
            'title' => $self->printableName(),
            'widget' => \&ltspClientsWidget,
            'order' => 15,
            'default' => 1
        }
    };
}

1;
