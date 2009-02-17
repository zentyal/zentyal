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

use base qw(EBox::Module::Service 
            EBox::Model::ModelProvider 
            EBox::Model::CompositeProvider
            );

# eBox uses
use EBox::Common::Model::EnableForm;
use EBox::Exceptions::External;
use EBox::Exceptions::Sudo::Command;
use EBox::Gettext;
use EBox::Global;
use EBox::Service;
use EBox::Sudo;
use EBox::WebServer::Composite::General;
use EBox::WebServer::Model::GeneralSettings;
use EBox::WebServer::Model::VHostTable;
use EBox::WebServer::PlatformPath;

use Error qw(:try);

# Constants
use constant VHOST_PREFIX => 'ebox-';
use constant WEB_SERVICE  => 'ebox.apache2-user';
use constant CONF_DIR     => EBox::WebServer::PlatformPath::ConfDirPath();
use constant PORTS_FILE   => CONF_DIR . '/ports.conf';
use constant ENABLED_MODS_DIR   => CONF_DIR . '/mods-enabled/';
use constant AVAILABLE_MODS_DIR   => CONF_DIR . '/mods-available/';

use constant USERDIR_CONF_FILES => ('userdir.conf', 'userdir.load');
use constant LDAP_USERDIR_CONF_FILE => 'ldap_userdir.conf';
use constant SITES_AVAILABLE_DIR   => CONF_DIR . '/sites-available/';
use constant SITES_ENABLED_DIR   => CONF_DIR . '/sites-enabled/';

# Constructor: _create
#
#        Create the web server module
#
# Overrides:
#
#        <EBox::Module::Service::_create>
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
                                          printableName => 'webserver',
                                          domain => 'ebox-webserver',
                                          @_,
                                         );
    bless($self, $class);
    return $self;
}

# Method: usedFiles
#
#	Override EBox::Module::Service::usedFiles
#
sub usedFiles
{
    my ($self) = @_;
    my $files = [
    {
        'file' => PORTS_FILE,
        'module' => 'webserver',
        'reason' => __('To set webserver listening port')
    },
    {
        'file' => AVAILABLE_MODS_DIR . LDAP_USERDIR_CONF_FILE,
        'module' => 'webserver',
        'reason' => __('To configure the per-user public HTML directory')
    }
        ]; 
   
   my $vHostModel = $self->model('VHostTable');

    foreach my $id (@{$vHostModel->ids()}) {
        my $vHost = $vHostModel->row($id);
        # Access to the field values for every virtual host
        my $vHostName = $vHost->valueByName('name');

        my $destFile = SITES_AVAILABLE_DIR . VHOST_PREFIX . $vHostName;
       push @{$files}, { 'file' => $destFile, 'module' => 'webserver' , 
                         'reason' => 'To configure every virtual host'};
    }

    return $files;
}

# Method: actions 
#
#	Override EBox::Module::Service::actions
#
sub actions 
{
    return [
    {
        'action' => __('Enable apache LDAP user module'),
        'module' => 'webserver',
        'reason' => __('To fetch home directories from LDAP')
    },
        ];
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
       'addVHost'       => { action   => 'add',
                             path     => [ 'VHostTable' ],
                           },
       'removeVHost'    => { action   => 'del',
                             path     => [ 'VHostTable' ],
                             indexes  => [ 'name' ],
                           },
       'updateVHost'    => { action   => 'set',
                             path     => [ 'VHostTable' ],
                             indexes  => [ 'name' ],
                           },
       'vHost'          => { action   => 'get',
                             path     => [ 'VHostTable' ],
                             indexes  => [ 'name' ],
                           },
       'isVHostEnabled' => { action   => 'get',
                             path     => [ 'VHostTable' ],
                             indexes  => [ 'name' ],
                             selector => [ 'enabled' ],
                           },
       );

    return \%exposedMethods;
}

#  Method: _daemons
#
#   Override <EBox::Module::Service::_daemons>
#

sub _daemons
{
    return [
        {
            'name' => WEB_SERVICE
        }
    ];
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
    foreach my $id (@{$vHostModel->ids()}) {
        my $rowVHost = $vHostModel->row($id);
        push ( @vHosts, {
                         name => $rowVHost->valueByName('name'), 
                         enabled => $rowVHost->valueByName('enabled'), 
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

# Method: _setConf
#
#        Regenerate the webserver configuration
#
# Overrides:
#
#       <EBox::Module::Service::_setConf>
#

sub _setConf
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
    my $gl = EBox::Global->getInstance();

    if ( $generalConf->enableDirValue() ) {
        # User dir enabled
        foreach my $confFile (USERDIR_CONF_FILES) {
            unless ( -e AVAILABLE_MODS_DIR . $confFile ) {
                throw EBox::Exceptions::External(__x('The {userDirConfFile} ' .
                                                     'is missing! Please recover it',
                                                     userDirConfFile => AVAILABLE_MODS_DIR . $confFile));
            }
        }
        # Manage configuration for mod_ldap_userdir apache2 module
        if ( $gl->modExists('samba') ) {
            eval 'use EBox::Ldap; use EBox::UsersAndGroups;';
            my $rootDN = EBox::Ldap::rootDn();
            my $ldapPass = EBox::Ldap::getPassword();
            my $usersMod = $gl->modInstance('users');
            my $usersDN = $usersMod->usersDn();
            $self->writeConfFile( AVAILABLE_MODS_DIR . LDAP_USERDIR_CONF_FILE,
                                  'webserver/ldap_userdir.conf.mas',
                                  [
                                   rootDN  => $rootDN,
                                   usersDN => $usersDN,
                                   dnPass  => $ldapPass,
                                  ],
                                  { 'uid' => 0, 'gid' => 0, mode => '600' }
                                  );
            try {
                EBox::Sudo::root('a2enmod ldap_userdir');
            } catch EBox::Exceptions::Sudo::Command with {
                my ($exc) = @_;
                # Already enabled?
                if ( $exc->exitValue() != 1 ) {
                    throw $exc;
                }
            };
        }
        # Enable the modules
        try {
            EBox::Sudo::root('a2enmod userdir');
        } catch EBox::Exceptions::Sudo::Command with {
            my ($exc) = @_;
            # Already enabled?
            if ( $exc->exitValue() != 1 ) {
                throw $exc;
            }
        };
    } else {
        # Disable the modules
        try {
            EBox::Sudo::root('a2dismod userdir');
        } catch EBox::Exceptions::Sudo::Command with {
            my ($exc) = @_;
            # Already enabled?
            if ( $exc->exitValue() != 1 ) {
                throw $exc;
            }
        };
        if ( $gl->modExists('samba')) {
            try {
                EBox::Sudo::root('a2dismod ldap_userdir');
            } catch EBox::Exceptions::Sudo::Command with {
                my ($exc) = @_;
                # Already disabled?
                if ( $exc->exitValue() != 1 ) {
                    throw $exc;
                }
            };
        }
    }
}

# Set up the virtual hosts
sub _setVHosts
{

    my ($self) = @_;

    my $vHostModel = $self->model('VHostTable');

    # Remove every available site using our vhost pattern ebox-*
    my $vHostPattern = VHOST_PREFIX . '*';
    EBox::Sudo::root('rm -f ' . SITES_ENABLED_DIR . "$vHostPattern");
    my %sitesToRemove = %{_availableSites()};
    foreach my $id (@{$vHostModel->ids()}) {
        my $vHost = $vHostModel->row($id);
        # Access to the field values for every virtual host
        my $vHostName  = $vHost->valueByName('name');

        my $destFile = SITES_AVAILABLE_DIR . VHOST_PREFIX . $vHostName;
        delete $sitesToRemove{$destFile};
        $self->writeConfFile( $destFile,
                              "webserver/vhost.mas",
                              [ vHostName => $vHostName ],
                            );

        # Create the subdir if required
        my $userConfDir = SITES_AVAILABLE_DIR . 'user-' .  VHOST_PREFIX
          . $vHostName;
        unless ( -d $userConfDir ) {
            EBox::Sudo::root("mkdir $userConfDir");
        }

        if ( $vHost->valueByName('enabled') ) {
            # Create the symbolic link
            EBox::Sudo::root("ln -s $destFile " . SITES_ENABLED_DIR);
            # Create the directory content if it is not already
            # created
            my $dir = EBox::WebServer::PlatformPath::DocumentRoot()
              . '/' . $vHostName;
            unless ( -d $dir ) {
                EBox::Sudo::root("mkdir $dir");
            }
        }
    }

    # Remove not used old dirs
    for my $dir (keys %sitesToRemove) { 
        EBox::Sudo::root("rm -f $dir");
    }

}

# return current eBox available sites from actual dir
sub _availableSites
{
    my $vhostPrefixPath = SITES_AVAILABLE_DIR . VHOST_PREFIX;
    my $cmd = "ls $vhostPrefixPath*";
    my @dirs;
    try {
      @dirs = @{EBox::Sudo::root($cmd)};
    } catch EBox::Exceptions::Sudo::Command with { 
        # No sites 
    };
    my %dirs = map  {chop($_); $_ => 1} @dirs;
    return \%dirs;
}

1;
