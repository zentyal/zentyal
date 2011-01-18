# Copyright (C) 2008-2010 eBox Technologies S.L.
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
#      This Zentyal module is responsible for handling the web service
#      within the local network manage by Zentyal.
#
package EBox::WebServer;

use strict;
use warnings;

use base qw(EBox::Module::Service
            EBox::Model::ModelProvider
            EBox::Model::CompositeProvider
            );

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
use constant AVAILABLE_MODS_DIR => CONF_DIR . '/mods-available/';

use constant USERDIR_CONF_FILES     => ('userdir.conf', 'userdir.load');
use constant LDAP_USERDIR_CONF_FILE => 'ldap_userdir.conf';
use constant SITES_AVAILABLE_DIR => CONF_DIR . '/sites-available/';
use constant SITES_ENABLED_DIR   => CONF_DIR . '/sites-enabled/';
use constant GLOBAL_CONF_DIR   => CONF_DIR . '/conf.d/';

use constant VHOST_DFLT_FILE    => SITES_AVAILABLE_DIR . 'default';
use constant VHOST_DFLTSSL_FILE => SITES_AVAILABLE_DIR . 'default-ssl';
use constant SSL_DIR => CONF_DIR . '/ssl/';

# Constructor: _create
#
#        Create the web server module.
#
# Overrides:
#
#        <EBox::Module::Service::_create>
#
# Returns:
#
#        <EBox::WebServer> - the recently created module.
#
sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(
                                          name => 'webserver',
                                          printableName => __n('Web Server'),
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
        'reason' => __('To set webserver listening port.')
    },
    {
        'file' => VHOST_DFLT_FILE,
        'module' => 'webserver',
        'reason' => __('To configure default virtual host.')
    },
    {
        'file' => VHOST_DFLTSSL_FILE,
        'module' => 'webserver',
        'reason' => __('To configure default SSL virtual host.')
    },
    {
        'file' => AVAILABLE_MODS_DIR . LDAP_USERDIR_CONF_FILE,
        'module' => 'webserver',
        'reason' => __('To configure the per-user public_html directory.')
    }
    ];

    my $vHostModel = $self->model('VHostTable');
    foreach my $id (@{$vHostModel->ids()}) {
        my $vHost = $vHostModel->row($id);
        # Access to the field values for every virtual host
        my $vHostName = $vHost->valueByName('name');
        my $destFile = SITES_AVAILABLE_DIR . VHOST_PREFIX . $vHostName;
        push(@{$files}, { 'file' => $destFile, 'module' => 'webserver',
                          'reason' => "To configure $vHostName virtual host." });
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
        'action' => __('Enable Apache LDAP user module'),
        'module' => 'webserver',
        'reason' => __('To fetch home directories from LDAP.')
    },
    {
        'action' => __('Enable Apache SSL module'),
        'module' => 'webserver',
        'reason' => __('To serve pages over HTTPS.')
    },
    ];
}

# Method: menu
#
#        Show the Web Server menu entry.
#
# Overrides:
#
#        <EBox::Module::menu>
#
sub menu
{
      my ($self, $root) = @_;

      my $item = new EBox::Menu::Item(name  => 'WebServer',
                                      text  => $self->printableName(),
                                      separator => 'Infrastructure',
                                      url   => 'WebServer/Composite/General',
                                      order => 430
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
#       Return a list of current virtual hosts.
#
# Returns:
#
#       array ref - containing each element a hash ref with these three
#       components:
#
#       - name - String the virtual's host name
#       - ssl - [disabled|allowssl|forcessl]
#       - enabled - Boolean if it is currently enabled or not
#
sub virtualHosts
{
    my ($self) = @_;

    my $vHostModel = $self->model('VHostTable');
    my @vHosts;
    foreach my $id (@{$vHostModel->ids()}) {
        my $rowVHost = $vHostModel->row($id);
        push (@vHosts, {
                        name => $rowVHost->valueByName('name'),
                        ssl => $rowVHost->valueByName('ssl'),
                        enabled => $rowVHost->valueByName('enabled'),
                       });
    }

    return \@vHosts;
}

# Group: Static public methods

# Method: VHostPrefix
#
#     Get the virtual host prefix used by all virtual host created by
#     Zentyal.
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
#        Regenerate the webserver configuration.
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
    $self->_setDfltVhost();
    $self->_setDfltSSLVhost();
    $self->_checkCertificate();
    $self->_setVHosts();

    unless (-d SSL_DIR ) {
        my $cmd = "mkdir -m 755 " . SSL_DIR;
        EBox::Sudo::root($cmd);
    }
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
                         [ portNumber => $generalConf->portValue(),
                           sslportNumber =>  $generalConf->sslPort(),
                         ],
                        );
}

# Set up default vhost
sub _setDfltVhost
{
    my ($self) = @_;

    # We can assume the listening port is ready available
    my $generalConf = $self->model('GeneralSettings');

    # Overwrite the default vhost file
    $self->writeConfFile(VHOST_DFLT_FILE,
                         "webserver/default.mas",
                         [
                             portNumber => $generalConf->portValue(),
                             hostname => $self->_fqdn(),
                         ],
                        );
}

# Set up default-ssl vhost
sub _setDfltSSLVhost
{
    my ($self) = @_;

    my $generalConf = $self->model('GeneralSettings');
    if ($generalConf->sslPort()) {
        # Enable the module
        try {
            EBox::Sudo::root('a2enmod ssl');
        } catch EBox::Exceptions::Sudo::Command with {
            my ($exc) = @_;
            # Already enabled?
            if ( $exc->exitValue() != 1 ) {
                throw $exc;
            }
        };
        # Overwrite the default vhost file
        $self->writeConfFile(VHOST_DFLTSSL_FILE,
                             "webserver/default-ssl.mas",
                             [
                                 sslportNumber => $generalConf->sslPort(),
                                 hostname => $self->_fqdn(),
                             ],
                            );
        # Enable default-ssl vhost
        try {
            EBox::Sudo::root('a2ensite default-ssl');
        } catch EBox::Exceptions::Sudo::Command with {
            my ($exc) = @_;
            # Already enabled?
            if ( $exc->exitValue() != 1 ) {
                throw $exc;
            }
        };
    } else {
        # Disable the module
        try {
            EBox::Sudo::root('a2dissite default-ssl');
        } catch EBox::Exceptions::Sudo::Command with {
            my ($exc) = @_;
            # Already enabled?
            if ( $exc->exitValue() != 1 ) {
                throw $exc;
            }
        };
        # Disable default-ssl vhost
        try {
            EBox::Sudo::root('a2dismod ssl');
        } catch EBox::Exceptions::Sudo::Command with {
            my ($exc) = @_;
            # Already enabled?
            if ( $exc->exitValue() != 1 ) {
                throw $exc;
            }
        };
    }
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
                                                     'is missing! Please recover it.',
                                                     userDirConfFile => AVAILABLE_MODS_DIR . $confFile));
            }
        }
        # Manage configuration for mod_ldap_userdir apache2 module
        if ( $gl->modExists('samba') ) {
            my $usersMod = $gl->modInstance('users');
            my $ldap = $usersMod->ldap();
            my $rootDN = $ldap->rootDn();
            my $ldapPass = $ldap->getPassword();
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

    my $generalConf = $self->model('GeneralSettings');
    my $vHostModel = $self->model('VHostTable');

    # Remove every available site using our vhost pattern ebox-*
    my $vHostPattern = VHOST_PREFIX . '*';
    EBox::Sudo::root('rm -f ' . SITES_ENABLED_DIR . "$vHostPattern");
    my %sitesToRemove = %{_availableSites()};
    foreach my $id (@{$vHostModel->ids()}) {
        my $vHost = $vHostModel->row($id);

        my $vHostName  = $vHost->valueByName('name');
        my $sslSupport = $vHost->valueByName('ssl');

        my $destFile = SITES_AVAILABLE_DIR . VHOST_PREFIX . $vHostName;
        delete $sitesToRemove{$destFile};
        $self->writeConfFile( $destFile,
                              "webserver/vhost.mas",
                              [
                                  vHostName => $vHostName,
                                  portNumber => $generalConf->portValue(),
                                  sslportNumber =>  $generalConf->sslPort(),
                                  hostname => $self->_fqdn(),
                                  sslSupport => $sslSupport,
                              ],
                            );

        # Create the subdir if required
        my $userConfDir = SITES_AVAILABLE_DIR . 'user-' . VHOST_PREFIX
          . $vHostName;
        unless ( -d $userConfDir ) {
            EBox::Sudo::root("mkdir -m 755 $userConfDir");
        }

        if ( $vHost->valueByName('enabled') ) {
            my $vhostfile = VHOST_PREFIX . $vHostName;
            try {
                EBox::Sudo::root("a2ensite $vhostfile");
            } catch EBox::Exceptions::Sudo::Command with {
                my ($exc) = @_;
                # Already enabled?
                if ( $exc->exitValue() != 1 ) {
                    throw $exc;
                }
            };
            # Create the directory content if it is not already
            my $dir = EBox::WebServer::PlatformPath::VDocumentRoot()
              . '/' . $vHostName;
            unless ( -d $dir ) {
                EBox::Sudo::root("mkdir -p -m 755 $dir");
            }
        }
    }

    # Remove not used old dirs
    for my $dir (keys %sitesToRemove) {
        EBox::Sudo::root("rm -f $dir");
    }
}

# Return current Zentyal available sites from actual dir
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

# Return fqdn
sub _fqdn
{
    my $fqdn = `hostname --fqdn`;
    if ($? != 0) {
        $fqdn = 'ebox.localdomain';
    }
    chomp $fqdn;
    return $fqdn;
}

# Method: certificates
#
#   This method is used to tell the CA module which certificates
#   and its properties we want to issue for this service module.
#
# Returns:
#
#   An array ref of hashes containing the following:
#
#       service - name of the service using the certificate
#       path    - full path to store this certificate
#       user    - user owner for this certificate file
#       group   - group owner for this certificate file
#       mode    - permission mode for this certificate file
#
sub certificates
{
    my ($self) = @_;

    return [
            {
             service =>  __('Web Server'),
             path    =>  '/etc/apache2/ssl/apache.pem',
             user => 'root',
             group => 'root',
             mode => '0400',
            },
           ];
}

# Get subjAltNames on the existing certificate
sub _getCertificateSAN
{
    my ($self) = @_;

    my $cn = $self->_fqdn();

    my $ca = EBox::Global->modInstance('ca');
    my $meta = $ca->getCertificateMetadata(cn => $cn);
    return [] unless $meta;

    my @san = @{$meta->{subjAltNames}};

    my @vhosts;
    foreach my $vhost (@san) {
        push(@vhosts, $vhost->{value}) if ($vhost->{type} eq 'DNS');
    }

    return \@vhosts;
}

# Generate subjAltNames array for ebox-ca
sub _subjAltNames
{
    my ($self) = @_;

    my $model = $self->model('VHostTable');
    my @subjAltNames;
    foreach my $vhost (@{$model->getWebServerSAN()}) {
        push(@subjAltNames, { type => 'DNS', value => $vhost });
    }

    return \@subjAltNames;
}

# Compare two arrays
sub _checkVhostsLists
{
    my ($self, $vhostsTable, $vhostsCert) = @_;

    my @array1 = @{$vhostsTable};
    my @array2 = @{$vhostsCert};

    my @union = ();
    my @intersection = ();
    my @difference = ();
    my %count = ();

    foreach my $element (@array1, @array2) { $count{$element}++ }
    foreach my $element (keys %count) {
        push(@union, $element);
        push(@{ $count{$element} > 1 ? \@intersection : \@difference }, $element);
    }

    return @difference;
}

# Generate the certificate, issue a new one or renew the existing one
sub _issueCertificate
{
    my ($self) = @_;

    my $cn = $self->_fqdn();

    my $ca = EBox::Global->modInstance('ca');
    my $caMD = $ca->getCACertificateMetadata();
    my $certMD = $ca->getCertificateMetadata(cn => $cn);

    # If a certificate exists, check if it can still be used
    if (defined($certMD)) {
        my $isStillValid = ($certMD->{state} eq 'V');
        my $isAvailable = (-f $certMD->{path});

        if ($isStillValid and $isAvailable) {
            $ca->renewCertificate(commonName => $cn,
                                  endDate => $caMD->{expiryDate},
                                  subjAltNames => $self->_subjAltNames());
            return;
        }
    }

    $ca->issueCertificate(commonName => $cn,
                          endDate => $caMD->{expiryDate},
                          subjAltNames => $self->_subjAltNames());
}

# Check if we need to regenerate the certificate
sub _checkCertificate
{
    my ($self) = @_;

    my $generalConf = $self->model('GeneralSettings');
    return unless  $generalConf->sslPort();

    my $model = $self->model('VHostTable');
    my @vhostsTable = @{$model->getWebServerSAN()};
    my @vhostsCert = @{$self->_getCertificateSAN()};

    return unless @vhostsTable;

    if (@vhostsCert) {
        if ($self->_checkVhostsLists(\@vhostsTable, \@vhostsCert)) {
            $self->_issueCertificate();
        }
    } else {
        $self->_issueCertificate();
    }
}

sub backupDomains
{
    my $name = 'webserver';
    my %attrs  = (
                  printableName => __('Web server hosted files'),
                  description   => __(q{Virtual hosts data}),
                  order        => 300,
                 );

    return ($name, \%attrs);
}

sub backupDomainsFileSelection
{
    my ($self, %enabled) = @_;
    if ($enabled{webserver}) {
        my $selection = {
                          includes => [
                    EBox::WebServer::PlatformPath::DocumentRoot(),
                    EBox::WebServer::PlatformPath::VDocumentRoot(),
                                      ],
                         };
        return $selection;
    }

    return {};
}

1;
