# Copyright (C) 2007 Warp Networks S.L.
# Copyright (C) 2008-2014 Zentyal S.L.
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

package EBox::WebServer;

use base qw(
    EBox::Module::Kerberos
    EBox::SyncFolders::Provider
    EBox::HAProxy::ServiceBase
);

use EBox::Global;
use EBox::Gettext;
use EBox::SyncFolders::Folder;
use EBox::Service;

use EBox::Exceptions::External;
use EBox::Exceptions::Sudo::Command;
use EBox::WebServer::PlatformPath;
use EBox::WebServer::Model::PublicFolder;
use EBox::WebServer::Model::VHostTable;
use EBox::WebServer::Composite::General;
use EBox::WebServer::LdapUser;

use TryCatch::Lite;
use Perl6::Junction qw(any);

use constant VHOST_PREFIX => 'ebox-';
use constant CONF_DIR => EBox::WebServer::PlatformPath::ConfDirPath();
use constant PORTS_FILE => CONF_DIR . '/ports.conf';
use constant ENABLED_MODS_DIR => CONF_DIR . '/mods-enabled/';
use constant AVAILABLE_MODS_DIR => CONF_DIR . '/mods-available/';

use constant LDAP_USERDIR_CONF_FILE => 'ldap_userdir.conf';
use constant SITES_AVAILABLE_DIR => CONF_DIR . '/sites-available/';
use constant SITES_ENABLED_DIR => CONF_DIR . '/sites-enabled/';
use constant CONF_AVAILABLE_DIR => CONF_DIR . '/conf-available/';
use constant CONF_ENABLED_DIR => CONF_DIR . '/conf-enabled/';

use constant VHOST_DFLT_FILE => SITES_AVAILABLE_DIR . '000-default.conf';
use constant VHOST_DFLTSSL_FILE => SITES_AVAILABLE_DIR . 'default-ssl.conf';
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
    my $self = $class->SUPER::_create(name => 'webserver',
                                      printableName => __('Web Server'),
                                      @_);
    bless($self, $class);
    return $self;
}

# Method: usedFiles
#
#       Override EBox::Module::Service::usedFiles
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
        # access to the field values for every virtual host
        my $vHostName = $vHost->valueByName('name');
        my $destFile = SITES_AVAILABLE_DIR . VHOST_PREFIX . "$vHostName.conf";
        push(@{$files}, { 'file' => $destFile, 'module' => 'webserver',
                          'reason' => "To configure $vHostName virtual host." });
    }

    return $files;
}

# Method: actions
#
#       Override EBox::Module::Service::actions
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
    {
        'action' => __('Remove apache2 init script link'),
        'reason' => __('Zentyal will take care of starting and stopping ' .
                       'the services.'),
        'module' => 'webserver'
    }
    ];
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

    my $global = $self->global();
    my $haproxyMod = $global->modInstance('haproxy');
    # Create default rules and services
    # only if installing the first time
    unless ($version) {
        # Stop Apache process to allow haproxy to use the public port
        EBox::Sudo::silentRoot('service apache2 stop');

        my $firewall = $global->modInstance('firewall');

        my $fallbackPort = 8080;
        my $port = $firewall->requestAvailablePort('tcp', $self->defaultHTTPPort(), $fallbackPort);

        # Set port in reverse proxy
        my @args = ();
        push (@args, modName        => $self->name);
        push (@args, port           => $port);
        push (@args, enablePort     => 1);
        push (@args, defaultPort    => 1);
        push (@args, sslPort        => $self->defaultHTTPSPort());
        push (@args, enableSSLPort  => 0);
        push (@args, defaultSSLPort => 0);
        push (@args, force          => 1);

        $haproxyMod->setHAProxyServicePorts(@args);

        my $settings = $self->model('PublicFolder');
        $settings->setValue(enableDir => EBox::WebServer::Model::PublicFolder::DefaultEnableDir());
    }

    # Upgrade from 3.3
    if (defined ($version) and (EBox::Util::Version::compare($version, '3.4') < 0)) {
        # Stop Apache process to allow haproxy to use the public port
        EBox::Sudo::silentRoot('service apache2 stop');

        # Disable the ssl module in Apache, haproxy handles it now.
        try {
            EBox::Sudo::root('a2dismod ssl');
        } catch (EBox::Exceptions::Sudo::Command $e) {
            # If it's already disable, ignore the exception.
            if ( $e->exitValue() != 1 ) {
                $e->throw();
            }
        }

        # Migrate ports definition to haproxy.
        my $redis = $self->redis();
        my $key = 'webserver/conf/GeneralSettings/keys/form';
        my $value = $redis->get($key);
        unless ($value) {
            # Fallback to the 'ro' version.
            $key = 'webserver/ro/GeneralSettings/keys/form';
            $value = $redis->get($key);
        }
        my $port = $self->defaultHTTPPort();
        my $sslPort = $self->defaultHTTPSPort();
        my $sslEnabled = 0;
        my $defaultSSLPort = 0;
        if ($value) {
            if (defined $value->{port}) {
                $port = $value->{port};
                delete $value->{port};
            }
            if (defined $value->{ssl_selected}) {
                if ($value->{ssl_selected} eq 'ssl_port' and defined $value->{ssl_port}) {
                    $sslEnabled = 1;
                    # At this point, the SSL port is not being shared yet, so we set it as the default one.
                    $defaultSSLPort = 1;
                }
                delete $value->{ssl_selected};
            }
            if (defined $value->{ssl_port}) {
                $sslPort = $value->{ssl_port};
                delete $value->{ssl_port};
            }
        }
        # Set port in reverse proxy
        my @args = ();
        push (@args, modName        => $self->name);
        push (@args, port           => $port);
        push (@args, enablePort     => 1);
        push (@args, defaultPort    => 1);
        push (@args, sslPort        => $sslPort);
        push (@args, enableSSLPort  => $sslEnabled);
        push (@args, defaultSSLPort => $defaultSSLPort);
        push (@args, force          => 1);

        $haproxyMod->setHAProxyServicePorts(@args);

        my @keys = $redis->_keys('webserver/*/GeneralSettings/keys/forms');
        foreach my $key (@keys) {
            my $value = $redis->get($key);
            my $newkey = $key;
            $newkey =~ s{GeneralSettings}{PublicFolder};
            $redis->set($newkey, { enableDir => $value->{enableDir} });
        }
        $redis->unset(@keys);

        # Migrate the existing zentyal ca definition to follow the new layout used by HAProxy.
        my @caKeys = $redis->_keys('ca/*/Certificates/keys/*');
        foreach my $key (@caKeys) {
            my $value = $redis->get($key);
            unless (ref $value eq 'HASH') {
                next;
            }
            if ($value->{serviceId} eq 'Web Server') {
                # WebServer.
                $value->{serviceId} = 'zentyal_' . $self->name();
                $value->{service} = $self->printableName();
                # Zentyal handles this service automatically
                $value->{readOnly} = 1;
                $redis->set($key, $value);
            }
        }
    }

    foreach my $modName ('firewall', 'haproxy', 'webserver') {
        my $mod = $self->global()->modInstance($modName);
        if ($mod and $mod->changed()) {
            $mod->saveConfigRecursive();
        }
    }
}

# Method: depends
#
#     WebServer depends on modules that have webserver in enabledepends.
#
# Overrides:
#
#        <EBox::Module::Base::depends>
#
sub depends
{
    my ($self) = @_;

    my $dependsList = $self->SUPER::depends();

    my $global = EBox::Global->getInstance(1);
    foreach my $mod (@{ $global->modInstancesOfType('EBox::Module::Service') }) {
        next if ($self eq $mod);
        my $deps = $mod->enableModDepends();
        next unless $deps;
        if ($self->name() eq any(@$deps)) {
            push(@{$dependsList}, $mod->name());
        }
    }

    return $dependsList;
}

# overloaded to force haproxy to restart
sub setEnable
{
    my ($self, @params) = @_;
    $self->SUPER::setEnable(@params);
    if ($self->changed ) {
        $self->global()->modInstance("haproxy")->setAsChanged(1);
    }
}

# to avoid circular restore dependencies cause by depends override
sub restoreDependencies
{
    my ($self) = @_;
    my $dependsList = $self->SUPER::depends();
    return $dependsList;
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
                                      icon  => 'webserver',
                                      text  => $self->printableName(),
                                      url   => 'WebServer/Composite/General',
                                      order => 570);
      $root->add($item);
}

#  Method: _daemons
#
#   Override <EBox::Module::Service::_daemons>
#

sub _daemons
{
    return [
        {
            'name' => 'apache2',
            'type' => 'init.d',
            'pidfiles' => ['/var/run/apache2/apache2.pid'],
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
#        <EBox::Module::Service::_setConf>
#
sub _setConf
{
    my ($self) = @_;

    # adjust mpm modules
    EBox::Sudo::root(
        'a2dismod mpm_event',
        'a2enmod mpm_prefork'
       );

    my $vHostModel = $self->model('VHostTable');
    my $vhosts    = $vHostModel->virtualHosts();
    my $hostname      = $self->_fqdn();
    my $hostnameVhost = delete $vhosts->{$hostname};

    $self->_setPort();
    $self->_setUserDir();
    $self->_setDfltVhost($hostname, $hostnameVhost);
    $self->_setDfltSSLVhost($hostname, $hostnameVhost);
    $self->_checkCertificate();
    $self->_setVHosts($vhosts, $hostnameVhost);
}

# Set up the listening port
sub _setPort
{
    my ($self) = @_;

    my @params = ();
    push (@params, bindAddress => $self->targetIP());
    push (@params, port        => $self->targetHTTPPort());
    push (@params, sslPort     => $self->targetHTTPSPort());

    $self->writeConfFile(PORTS_FILE, "webserver/ports.conf.mas", \@params);
}

# Set up default vhost
sub _setDfltVhost
{
    my ($self, $hostname, $hostnameVhost) = @_;

    if ($self->listeningHTTPPort()) {
        my @params = ();
        push (@params, hostname      => $hostname);
        push (@params, hostnameVhost => $hostnameVhost);
        push (@params, publicPort    => $self->listeningHTTPPort());
        push (@params, port          => $self->targetHTTPPort());
        push (@params, publicSSLPort => $self->listeningHTTPSPort());
        push (@params, sslPort       => $self->targetHTTPSPort());

        # Overwrite the default vhost file
        $self->writeConfFile(VHOST_DFLT_FILE, "webserver/default.mas", \@params);

        # Enable 000-default vhost
        try {
            EBox::Sudo::root('a2ensite 000-default');
        } catch (EBox::Exceptions::Sudo::Command $e) {
            # Already enabled?
            if ($e->exitValue() != 1) {
                $e->throw();
            }
        }
    } else {
        # Disable 000-default vhost
        try {
            EBox::Sudo::root('a2dissite 000-default');
        } catch (EBox::Exceptions::Sudo::Command $e) {
            # Already disabled?
            if ($e->exitValue() != 1) {
                $e->throw();
            }
        }
    }
}

# Set up default-ssl vhost
sub _setDfltSSLVhost
{
    my ($self, $hostname, $hostnameVhost) = @_;

    if ($self->listeningHTTPSPort()) {
        my @params = ();
        push (@params, hostname      => $hostname);
        push (@params, hostnameVhost => $hostnameVhost);
        push (@params, sslPort       => $self->targetHTTPSPort());
        push (@params, publicSSLPort => $self->listeningHTTPSPort());

        # Overwrite the default-ssl vhost file
        $self->writeConfFile(VHOST_DFLTSSL_FILE, "webserver/default-ssl.mas", \@params);

        # Enable default-ssl vhost
        try {
            EBox::Sudo::root('a2ensite default-ssl');
        } catch (EBox::Exceptions::Sudo::Command $e) {
            # Already enabled?
            if ($e->exitValue() != 1) {
                $e->throw();
            }
        }
    } else {
        # Disable default-ssl vhost
        try {
            EBox::Sudo::root('a2dissite default-ssl');
        } catch (EBox::Exceptions::Sudo::Command $e) {
            # Already disabled?
            if ($e->exitValue() != 1) {
                $e->throw();
            }
        }
    }
}

# Set up the user directory by enable/disable the feature
sub _setUserDir
{
    my ($self) = @_;

    my $publicFolder = $self->model('PublicFolder');
    my $gl = EBox::Global->getInstance();

    # Manage configuration for mod_ldap_userdir apache2 module
    if ($publicFolder->enableDirValue() and $gl->modExists('samba')) {
        my $ldap = $self->ldap();
        my $ldapServer = '127.0.0.1';
        my $ldapPort   = $ldap->ldapConf()->{port};
        my $rootDN = $self->_kerberosServiceAccountDN();
        my $ldapPass = $self->_kerberosServiceAccountPassword();
        my $dse = $ldap->rootDse();
        my $defaultNC = $dse->get_value('defaultNamingContext');
        $self->writeConfFile(AVAILABLE_MODS_DIR . LDAP_USERDIR_CONF_FILE,
                             'webserver/ldap_userdir.conf.mas',
                             [
                               ldapServer => $ldapServer,
                               ldapPort  => $ldapPort,
                               rootDN  => $rootDN,
                               usersDN => $defaultNC,
                               dnPass  => $ldapPass,
                             ],
                             { 'uid' => 0, 'gid' => 0, mode => '600' }
                            );
        # Enable the modules
        try {
            EBox::Sudo::root('a2enmod ldap_userdir');
        } catch (EBox::Exceptions::Sudo::Command $e) {
            # Already enabled?
            if ($e->exitValue() != 1) {
                $e->throw();
            }
        }
        try {
            EBox::Sudo::root('a2enmod userdir');
        } catch (EBox::Exceptions::Sudo::Command $e) {
            # Already enabled?
            if ($e->exitValue() != 1) {
                $e->throw();
            }
        }
    } else {
        # Disable the modules
        try {
            EBox::Sudo::root('a2dismod userdir');
        } catch (EBox::Exceptions::Sudo::Command $e) {
            # Already enabled?
            if ($e->exitValue() != 1) {
                $e->throw();
            }
        }
        if ($gl->modExists('samba')) {
            try {
                EBox::Sudo::root('a2dismod ldap_userdir');
            } catch (EBox::Exceptions::Sudo::Command $e) {
                # Already disabled?
                if ($e->exitValue() != 1) {
                    $e->throw();
                }
            }
        }
    }
}

# Set up the virtual hosts
sub _setVHosts
{
    my ($self, $vhosts, $vHostDefault) = @_;

    # Remove every available site using our vhost pattern ebox-*
    my $vHostPattern = VHOST_PREFIX . '*';
    EBox::Sudo::root('rm -f ' . SITES_ENABLED_DIR . "$vHostPattern");

    my %sitesToRemove = %{_availableSites()};
    if ($vHostDefault) {
        my $vHostDefaultSite = SITES_AVAILABLE_DIR . VHOST_PREFIX . $vHostDefault->{name};
        delete $sitesToRemove{$vHostDefaultSite};
        $self->_createSiteDirs($vHostDefault);
    }

    foreach my $vHost (values %{$vhosts}) {
        my $vHostName  = $vHost->{'name'};
        my $sslSupport = $vHost->{'ssl'};

        my $destFile = SITES_AVAILABLE_DIR . VHOST_PREFIX . "$vHostName.conf";
        delete $sitesToRemove{$destFile};

        my @params = ();
        push (@params, vHostName  => $vHostName);
        push (@params, hostname   => $self->_fqdn());
        push (@params, publicPort    => $self->listeningHTTPPort());
        push (@params, port       => $self->targetHTTPPort());
        push (@params, publicSSLPort => $self->listeningHTTPSPort());
        push (@params, sslPort    => $self->targetHTTPSPort());
        push (@params, sslSupport => $sslSupport);

        $self->writeConfFile($destFile, "webserver/vhost.mas", \@params);
        $self->_createSiteDirs($vHost);

        if ( $vHost->{'enabled'} ) {
            my $vhostfile = VHOST_PREFIX . $vHostName;
            $self->_enableVHost($vhostfile);
        }
    }

    # add additional vhost files
    foreach my $vHostFilePath (@{ $self->_internalVHosts() }) {
        delete $sitesToRemove{$vHostFilePath};

        my $vhostfileBasename = File::Basename::basename($vHostFilePath);
        $self->_enableVHost($vhostfileBasename);
    }

    # Remove not used old dirs
    for my $dir (keys %sitesToRemove) {
        EBox::Sudo::root("rm -f $dir");
    }
}

sub _internalVHosts
{
    my ($self) = @_;
    my @vhosts;

    # for now only used by openchange/rpcproxy
    my $openchange = $self->global()->modInstance('openchange');
    if ($openchange) {
        push @vhosts, @{ $openchange->internalVHosts() }
    }

    return \@vhosts;
}

sub _enableVHost
{
    my ($self, $vhostfile) = @_;
    try {
       EBox::Sudo::root("a2ensite $vhostfile");
    } catch (EBox::Exceptions::Sudo::Command $exc) {
       # Already enabled?
        if ( $exc->exitValue() != 1 ) {
            throw $exc;
        }
    };
}

sub _createSiteDirs
{
    my ($self, $vHost) = @_;
    my $vHostName  = $vHost->{'name'};

    # Create the user-conf subdir if required
    my $userConfDir = SITES_AVAILABLE_DIR . 'user-' . VHOST_PREFIX
        . $vHostName;
    if (EBox::Sudo::fileTest('-e', $userConfDir)) {
        if (not EBox::Sudo::fileTest('-d', $userConfDir)) {
            throw EBox::Exceptions::External(
                  __x('{dir} should be a directory for virtual host configuration. Please, move or remove it',
                      dir => $userConfDir
                     )
            );
        }
    } else {
        EBox::Sudo::root("mkdir -m 755 $userConfDir");
    }

    # Create the directory content if it is not already
    my $dir = EBox::WebServer::PlatformPath::VDocumentRoot()
        . '/' . $vHostName;
    if (EBox::Sudo::fileTest('-e', $dir)) {
        if (not EBox::Sudo::fileTest('-d', $dir)) {
            throw EBox::Exceptions::External(
                  __x('{dir} should be a directory for virtual host document root. Please, move or remove it',
                      dir => $dir
                     )
            );
        }
    } else {
        EBox::Sudo::root("mkdir -p -m 755 $dir");
    }
}

# Return current Zentyal available sites from actual dir
sub _availableSites
{
    my $vhostPrefixPath = SITES_AVAILABLE_DIR . VHOST_PREFIX;
    my @dirs = glob "$vhostPrefixPath*";
    my %dirs = map {$_ => 1} @dirs;
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

    my @certificates = map {
        my $path = $_;
        {
            serviceId =>  'zentyal_' . $self->name(),
            service   =>  $self->printableName(),
            path      =>  $path,
            user      => 'root',
            group     => 'root',
            mode      => '0400',
        }
    } @{ $self->pathHTTPSSSLCertificate() };


    return \@certificates;
}

# Get CN and subjAltNames on the existing certificate
sub _getCertificateCNAndSAN
{
    my ($self) = @_;

    my $ca = $self->global()->modInstance('ca');
    my $certificates = $ca->model('Certificates');
    my $cn = $certificates->cnByService('zentyal_' . $self->name());

    my $meta = $ca->getCertificateMetadata(cn => $cn);
    return [] unless $meta;

    my @san = @{$meta->{subjAltNames}};

    my @vhosts;
    foreach my $vhost (@san) {
        push(@vhosts, $vhost->{value}) if ($vhost->{type} eq 'DNS');
    }
    push @vhosts, $cn;

    return \@vhosts;
}

# Generate subjAltNames array for zentyal-ca
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

    my $ca = $self->global()->modInstance('ca');
    my $certificates = $ca->model('Certificates');
    my $cn = $certificates->cnByService('zentyal_' . $self->name());

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

    return unless $self->listeningHTTPSPort();

    my $ca = $self->global()->modInstance('ca');
    my $certificates = $ca->model('Certificates');
    return unless $certificates->isEnabledService('zentyal_' . $self->name());

    my $model = $self->model('VHostTable');
    my @vhostsTable = @{$model->getWebServerSAN()};
    my @vhostsCert = @{$self->_getCertificateCNAndSAN()};
    return unless @vhostsTable;

    if (@vhostsCert) {
        if ($self->_checkVhostsLists(\@vhostsTable, \@vhostsCert)) {
            $self->_issueCertificate();
        }
    } else {
        $self->_issueCertificate();
    }

    my $global = EBox::Global->getInstance();
    $global->modRestarted('ca');
}

sub dumpConfig
{
    my ($self, $dir) = @_;
    my $sitesBackDir = "$dir/sites-available";
    mkdir $sitesBackDir;

    my @dirs = keys %{ _availableSites() };

    if (not @dirs) {
        EBox::warn(SITES_AVAILABLE_DIR . ' has not custom configuration dirs. Skipping them for the backup');
        return;
    }

    my $toReplace= SITES_AVAILABLE_DIR . 'ebox-';
    my $replacement = SITES_AVAILABLE_DIR . 'user-ebox-';
    foreach my $dir (@dirs) {
       $dir =~ s/$toReplace/$replacement/;
        try {
            EBox::Sudo::root("cp -a $dir $sitesBackDir");
        } catch (EBox::Exceptions::Sudo::Command $e) {
            EBox::error("Failed to do backup of the vhost custom configuration dir $dir");
        }
    }
}

sub restoreConfig
{
    my ($self, $dir) = @_;
    my $sitesBackDir = "$dir/sites-available";
    if (EBox::FileSystem::dirIsEmpty($sitesBackDir)) {
        EBox::warn('No data in the backup for vhosts custom configuration files (maybe the backup was done in a previous version?). Actual files are left untouched');
        return;
    }

    if (not EBox::FileSystem::dirIsEmpty(SITES_AVAILABLE_DIR)) {
        #  backup actual sites-available-dir
        my $backActual = CONF_DIR . '/sites-available.bak';
        $backActual = EBox::FileSystem::unusedFileName($backActual);
        EBox::Sudo::root("mkdir $backActual");
        EBox::Sudo::root('mv ' . SITES_AVAILABLE_DIR .  "/* $backActual");
    }

    EBox::Sudo::root("cp -a $sitesBackDir/* " . SITES_AVAILABLE_DIR);
}

# Implement EBox::SyncFolders::Provider interface
sub syncFolders
{
    my ($self) = @_;

    my @folders;

    if ($self->recoveryEnabled()) {
        foreach my $dir (EBox::WebServer::PlatformPath::DocumentRoot(),
                         EBox::WebServer::PlatformPath::VDocumentRoot()) {
            push (@folders, new EBox::SyncFolders::Folder($dir, 'recovery'));
        }
    }

    return \@folders;
}

sub recoveryDomainName
{
    return __('Web server data');
}

#
# Implementation of EBox::HAProxy::ServiceBase
#

# Method: defaultHTTPPort
#
# Returns:
#
#   integer - The default public port that should be used to publish this service or undef if unused.
#
# Overrides:
#
#   <EBox::HAProxy::ServiceBase::defaultHTTPPort>
#
sub defaultHTTPPort
{
    return 80;
}

# Method: defaultHTTPSPort
#
# Returns:
#
#   integer - The default public port that should be used to publish this service over SSL or undef if unused.
#
# Overrides:
#
#   <EBox::HAProxy::ServiceBase::defaultHTTPSPort>
#
sub defaultHTTPSPort
{
    return 443;
}

# Method: targetVHostDomains
#
# Returns:
#
#   list - List of domains that the target service will handle. If empty, this service will be used as the default
#          traffic destination for the configured ports.
#
sub targetVHostDomains
{
    my ($self) = @_;

    my @domains = ();
    push (@domains, $self->_fqdn());

    my $vhosts = $self->virtualHosts();
    foreach my $vhost (@{$vhosts}) {
        if ($vhost->{enabled}) {
            push (@domains, $vhost->{name});
        }
    }

    return \@domains;
}

# Method: pathHTTPSSSLCertificate
#
# Returns:
#
#   string - The full path to the SSL certificate file to use by HAProxy.
#
sub pathHTTPSSSLCertificate
{
    return ['/etc/apache2/ssl/ssl.pem'];
}

# Method: targetIP
#
# Returns:
#
#   string - IP address where the service is listening, usually 127.0.0.1 .
#
# Overrides:
#
#   <EBox::HAProxy::ServiceBase::targetIP>
#
sub targetIP
{
    return '127.0.0.1';
}

# Method: targetHTTPPort
#
# Returns:
#
#   integer - Port on <EBox::HAProxy::ServiceBase::targetIP> where the service is listening for requests.
#
# Overrides:
#
#   <EBox::HAProxy::ServiceBase::targetHTTPPort>
#
sub targetHTTPPort
{
    return 62080;
}

# Method: targetHTTPSPort
#
# Returns:
#
#   integer - Port on <EBox::HAProxy::ServiceBase::targetIP> where the service is listening for SSL requests.
#
# Overrides:
#
#   <EBox::HAProxy::ServiceBase::targetHTTPSPort>
#
sub targetHTTPSPort
{
    return 62443;
}

# Method: _kerberosServicePrincipals
#
#   EBox::Module::Kerberos implementation. We don't create any SPN, just
#   the service account to bind to LDAP
#
sub _kerberosServicePrincipals
{
    return undef;
}

sub _kerberosKeytab
{
    return undef;
}

sub _ldapModImplementation
{
    return new EBox::WebServer::LdapUser();
}

1;
