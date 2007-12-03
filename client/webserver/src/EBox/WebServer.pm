# Copyright (C) 2007 Warp Networks S.L.
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

# Class: EBox::WebServer
#
#      This eBox module is responsible for handling the web service
#      within the local network manage by eBox.
#

package EBox::WebServer;

use strict;
use warnings;

use base qw(EBox::GConfModule EBox::Model::ModelProvider EBox::Model::CompositeProvider);

# eBox uses
use EBox::Common::Model::EnableForm;
use EBox::Exceptions::External;
use EBox::Gettext;
use EBox::Service;
use EBox::Sudo;
use EBox::Summary::Module;
use EBox::WebServer::Composite::General;
use EBox::WebServer::Model::GeneralSettings;
use EBox::WebServer::Model::VHostTable;
use EBox::WebServer::PlatformPath;

# Constants
use constant VHOST_PREFIX => 'ebox-';
use constant WEB_SERVICE  => 'apache2';
use constant CONF_DIR     => EBox::WebServer::PlatformPath::ConfDirPath();
use constant PORTS_FILE   => CONF_DIR . '/ports.conf';
use constant ENABLED_MODS_DIR   => CONF_DIR . '/mods-enabled/';
use constant AVAILABLE_MODS_DIR   => CONF_DIR . '/mods-available/';

use constant USERDIR_CONF_FILES => ('userdir.conf', 'userdir.load');
use constant SITES_AVAILABLE_DIR   => CONF_DIR . '/sites-available/';
use constant SITES_ENABLED_DIR   => CONF_DIR . '/sites-enabled/';

# Constructor: _create
#
#        Create the web server module
#
# Overrides:
#
#        <EBox::GConfModule::_create>
#
# Returns:
#
#        <EBox::WebServer> - the recently created module
#
sub _create
{
	my $class = shift;
	my $self = $class->SUPER::_create(
                                          name => 'webserver',
                                          domain => 'ebox-webserver',
                                          @_,
                                         );
	bless($self, $class);
	return $self;
}

# Method: _regenConfig
#
#        Regenerate the configuration
#
# Overrides:
#
#       <EBox::Module::_regenConfig>
#
sub _regenConfig
{

    my ($self) = @_;

    $self->_setWebServerConf();
    $self->_doDaemon();

}


# Method: _stopService
#
#        Stop the event service
# Overrides:
#
#       <EBox::Module::_stopService>
#
sub _stopService
  {

      EBox::Service::manage(WEB_SERVICE, 'stop');

  }


# Method: menu
#
#        Show the web server menu entry
#
# Overrides:
#
#        <EBox::Module::menu>
#
sub menu
  {

      my ($self, $root) = @_;

      my $item = new EBox::Menu::Item(name  => 'WebServer',
                                      text  => __('Web'),
                                      url   => 'WebServer/Composite/General',
                                     );

      $root->add($item);

  }


# Method: statusSummary
#
#       Show the module status summary
#
# Overrides:
#
#       <EBox::Module::statusSummary>
#
sub statusSummary
{

    my ($self) = @_;

    return new EBox::Summary::Status(
                                     'webserver',
                                     __('Web'),
                                     $self->running(),
                                     $self->service(),
                                    );

}

# Method: modelClasses
#
# Overrides:
#
#    <EBox::Model::ModelProvider::modelClasses>
#
sub modelClasses
{
    return [
            {
             class => 'EBox::Common::Model::EnableForm',
             parameters => [
                            enableTitle => __('Web service status'),
                            domain => 'ebox-webserver',
                            modelDomain => 'WebServer',
                           ],
            },
            'EBox::WebServer::Model::GeneralSettings',

            'EBox::WebServer::Model::VHostTable',
           ];
}


# Method: compositeClasses
#
# Overrides:
#
#    <EBox::Model::CompositeProvider::compositeClasses>
#
sub compositeClasses
{
    return ['EBox::WebServer::Composite::General'];
}

################
# API exposed
################

# Method: _exposedMethods
#
# Overrides:
#
#      <EBox::Model::ModelProvider::_exposedMethods>
#
sub _exposedMethods
{
    my ($self) = @_;

    my %exposedMethods =
      (
       'addVHost'    => { action  => 'add',
                          path    => [ 'VHostTable' ],
                        },
       'removeVHost' => { action  => 'del',
                          path    => [ 'VHostTable' ],
                          indexes => [ 'name' ],
                        },
       'updateVHost' => { action  => 'set',
                          path    => [ 'VHostTable' ],
                          indexes => [ 'name' ],
                        },
       'vHost'       => { action  => 'get',
                          path    => [ 'VHostTable' ],
                          indexes => [ 'name' ],
                        },
       );

    return \%exposedMethods;
}

# Method: running
#
#      Check whether the web server Apache2 is running or not
#
# Returns:
#
#      boolean - indicating whether the server is running or not
#
sub running
{

    my ($self) = @_;

    return EBox::Service::running(WEB_SERVICE);

}

# Method: service
#
#       Convenient method to check whether the web service is enabled
#       or not
#
# Returns:
#
#       boolean - indicating whether the service is enabled or not
#
sub service
{

    my ($self) = @_;

    return $self->model('EnableForm')->enabledValue();

}

# Method: virtualHosts
#
#       Return a list of current virtual hosts
#
# Returns:
#
#       array ref - containing each element a hash ref with these two
#       components
#
#       - name -  String the virtual's host name
#       - enabled - Boolean if it is currently enabled or not
#
sub virtualHosts
{

    my ($self) = @_;

    my $vHostModel = $self->model('VHostTable');
    my @vHosts;
    foreach my $rowVHost (@{$vHostModel->rows()}) {
        my $values = $rowVHost->{plainValueHash};
        push ( @vHosts, {
                         name => $values->{name},
                         enabled => $values->{enabled},
                        });
    }

    return \@vHosts;

}

# Group: Static public methods

# Method: VHostPrefix
#
#     Get the virtual host prefix used by all virtual host created by
#     eBox
#
# Returns:
#
#     String - the prefix
#
sub VHostPrefix
{
    return VHOST_PREFIX;
}

# Group: Private methods

######################################
# Setting web server configuration
######################################
sub _setWebServerConf
{

    my ($self) = @_;

    $self->_setPort();
    $self->_setUserDir();
    $self->_setVHosts();

}

# Set up the listening port
sub _setPort
{

    my ($self) = @_;

    # We can assume the listening port is ready available
    my $generalConf = $self->model('GeneralSettings');

    # Overwrite the listening port conf file
    $self->writeConfFile(PORTS_FILE,
                         "webserver/ports.conf.mas",
                         [ portNumber => $generalConf->portValue() ],
                        )

}

# Set up the user directory by enable/disable the feature
sub _setUserDir
{

    my ($self) = @_;

    my $generalConf = $self->model('GeneralSettings');

    if ( $generalConf->enableDirValue() ) {
        # User dir enabled
        foreach my $confFile (USERDIR_CONF_FILES) {
            unless ( -e AVAILABLE_MODS_DIR . $confFile ) {
                throw EBox::Exceptions::External(__x('The {userDirConfFile} ' .
                                                     'is missing! Please recover it',
                                                     userDirConfFile => AVAILABLE_MODS_DIR . $confFile));
            }
        }
        # Dump the configuration file
        $self->writeConfFile( AVAILABLE_MODS_DIR . (USERDIR_CONF_FILES)[0],
                              'webserver/userdir.conf.mas',
                              []);
        # Enable the module
        EBox::Sudo::root('a2enmod userdir');
    } else {
        # Disable the module
        EBox::Sudo::root('a2dismod userdir');
    }
}

# Set up the virtual hosts
sub _setVHosts
{

    my ($self) = @_;

    my $vHostModel = $self->model('VHostTable');

    my $vHosts = $vHostModel->rows();

    # Remove every available site using our vhost pattern ebox-*
    my $vHostPattern = VHOST_PREFIX . '*';
    EBox::Sudo::root('rm -f ' . SITES_AVAILABLE_DIR . "$vHostPattern");
    EBox::Sudo::root('rm -f ' . SITES_ENABLED_DIR . "$vHostPattern");

    foreach my $vHost (@{$vHostModel->rows()}) {
        # Access to the field values for every virtual host
        my $vHostValues = $vHost->{plainValueHash};

        my $destFile = SITES_AVAILABLE_DIR . VHOST_PREFIX . $vHostValues->{name};
        $self->writeConfFile( $destFile,
                              "webserver/vhost.mas",
                              [ vHostName => $vHostValues->{name} ],
                            );

        # Create the subdir if required
        my $userConfDir = SITES_AVAILABLE_DIR . 'user-' .  VHOST_PREFIX
          . $vHostValues->{name};
        unless ( -d $userConfDir ) {
            EBox::Sudo::root("mkdir $userConfDir");
        }

        if ( $vHostValues->{enabled} ) {
            # Create the symbolic link
            EBox::Sudo::root("ln -s $destFile " . SITES_ENABLED_DIR);
            # Create the directory content if it is not already
            # created
            my $dir = EBox::WebServer::PlatformPath::DocumentRoot()
              . '/' . $vHostValues->{name};
            unless ( -d $dir ) {
                EBox::Sudo::root("mkdir $dir");
            }
        }
    }

}

######################################
# Managing the daemon
######################################
sub _doDaemon
{

    my ($self) = @_;

    if ( $self->running() and $self->service() ) {
        EBox::Service::manage(WEB_SERVICE, 'restart');
    } elsif ( $self->service() ) {
        EBox::Service::manage(WEB_SERVICE, 'start');
    } else {
        EBox::Service::manage(WEB_SERVICE, 'stop');
    }

}

1;
