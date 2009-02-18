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

package EBox::SOAP;

# Class: EBox::SOAP
#
# This package is intended to support eBox side of the communication
# among eBox and the control center
#

use strict;
use warnings;

use base 'EBox::Module::Service';

use Error qw(:try);

use EBox::Global;
use EBox::Gettext;
use EBox::Config;
use EBox::Validate qw(checkPort);
use EBox::Sudo;
use EBox::NetWrappers;
use EBox::Service;
use EBox::OpenVPN;

# EBox types wow!
use EBox::Types::IPAddr;
use EBox::Types::Service;

# EBox exceptions
use EBox::Exceptions::External;
use EBox::Exceptions::Internal;

###############
# Core modules
###############
use File::Copy qw(move);
use File::Temp qw(tempdir);
use File::Basename;
use File::Path;

###############
# Dependencies
###############
use File::MMagic;
use Config::Tiny;

# Constants:

# Subdirectory within configuration directory
use constant CONF_SUBDIR => '/soap/';

use constant CONTROL_CENTER_CN => 'Control Center';
use constant SERVICE => 'apache-soap';

use constant APACHE_CONF_FILE => EBox::Config->conf() . CONF_SUBDIR . 'httpd.conf';
use constant STARTUP_FILE => EBox::Config->conf() . CONF_SUBDIR . 'startup.pl';

# File from the OpenVPN client configuration comes from
use constant CLIENT_CC => 'client.conf';


use constant NUM_PING_ATTEMPTS => 3;

sub _create
  {
      my $class = shift;
      my $self = $class->SUPER::_create(
                                        name => 'soap',
                                        domain => 'ebox-soap',
                                        @_
                                       );
      bless($self, $class);

      my $global = EBox::Global->getInstance();
      $self->{openvpn} = $global->modInstance('openvpn');

      # Create SOAP configuration directory if it does not exist
      unless ( -d ( EBox::Config->conf() . CONF_SUBDIR )) {
          mkdir ( EBox::Config->conf() . CONF_SUBDIR, 0700);
      }

      return $self;
  }

# Method: _regenConfig
#
#     Override <EBox::Module::Service::_regenConfig> method
#
sub _regenConfig
  {
      my ( $self ) = @_;

      # OpenVPN client configuration
      # $self->_setOpenVPNClient();

      if ( $self->isReadOnly() ) {
          ### WARNING!!! ###
          # Restart openvpn service as well. This is an inverse
          # dependency needed when restart button from status is
          # clicked.
          my $gl = EBox::Global->getInstance(1);
          my $openvpn = $gl->modInstance('openvpn');
          $openvpn->_regenConfig(restart => 1);
      } else {
          # Delete the certificates only when saving changes are done
          $self->_deleteUnusedCerts();
      }


      # Apache SOAP-enabled Server
      # Regenerate the configuration for the Apache SOAP-enabled server
      $self->_regenHTTPdConfig();
      # Start daemon
      $self->_doDaemon();

  }

# Method: _stopService
#
#      Override <EBox::Module::Service::_stopService> method
#
sub _stopService
  {

      EBox::Service::manage(SERVICE, 'stop');

  }

# Method: summary
#
#       Override <EBox::Module::Service::summary> method
#
sub summary
  {
      # Nothing is required since it has no state
      my ($self) = @_;
      return undef;
  }

# Method: menu
#
#       Add SOAP module to eBox menu. Overrides <EBox::Module::Service::menu> method.
#
# Parameters:
#
#       root - the <EBox::Menu::Root> where to leave our items
#
sub menu
  {

      my ($self, $root) = @_;

      $root->add(new EBox::Menu::Item(
                                      url  => 'SOAP/Index',
                                      text => __('Control center'),
                                     )
                );
  }

# Method: enabled
#
#     Return if the SOAP service is enabled
#
# Returns:
#
#     boolean - true if enabled, otherwise undef
#
sub enabled
  {

      my ( $self ) = @_;

      return $self->get_bool('enabled');

  }

# Method: setEnabled
#
#     Set the SOAP service enabled or disabled
#
# Parameters:
#
#     enable - boolean
#
sub setEnabled
  {

      my ( $self, $enable ) = @_;

      my $current = $self->enabled();

      # If they are different, set the value
      if ( $current xor $enable ) {
          $self->set_bool('enabled', $enable);
          try {
              # Configure firewall to let cc connect to eBox
              $self->_configureFirewall();
              # Set the OpenVPN
              $self->_setOpenVPNClient();
          } catch EBox::Exceptions::Base with {
              my ($exc) = @_;
              $self->set_bool('enabled', $current);
              throw $exc;
          };
      }

  }

# Method: listeningPort
#
#    Get the port where SOAP server is listening to
#
# Returns:
#
#    Integer - the listening port
#

sub listeningPort
{
    my ($self) = @_;

    my $port = $self->get_int('listeningPort');
    unless(defined $port) {
        $port = 4430;
    }
    return $port;
}

# Method: running
#
#    Get whether the service is running or not
#
# Returns:
#
#    boolean - true if it's running, undef otherwise
#
sub running
  {

      my ($self) = @_;

      # For now, the apache server should be running
      return EBox::Service::running(SERVICE);

  }

# Method: parseUploadedBundle
#
#      Parse the uploaded bundle and stores the information given in
#      the bundle to configure SOAP module to communicate with the
#      control center.
#
# Parameters:
#
#      uploadedFile - the path to the file which has been uploaded
#
# Exceptions:
#
#      <EBox::Exceptions::External> - throw if the given file does not
#      match to the tar.gz expected
#      <EBox::Exceptions::Internal> - throw if trying to parse another
#      bundle when one is already uploaded
#      <EBox::Exceptions::MissingArgument> - throw if any parameter is
#      missing
#
sub parseUploadedBundle
  {

      my ( $self, $uploadedFile ) = @_;

      defined ( $uploadedFile ) or
        throw EBox::Exceptions::MissingArgument('uploadedFile');

      unless ( -f $uploadedFile ) {
          throw EBox::Exceptions::External(__x('Missing uploaded file: {uploadedFile}',
                                               uploadedFile => $uploadedFile));
      }

      if ( $self->bundleUploaded() ) {
          throw EBox::Exceptions::Internal('There is already a bundle uploaded');
      }

      my $mm = new File::MMagic();
      my $mimeType = $mm->checktype_filename($uploadedFile);

      if ( $mimeType ne 'application/x-gzip' ) {
          throw EBox::Exceptions::External(__x('Uploaded file is a type of {type1} ' .
                                               ' but it should be a file of type {type2}',
                                               type1 => $mimeType, 
                                               type2 => 'application/x-gzip'
                                              ));
      }

      # Get the contents, it can throw External exceptions as well
      my $files_ref = $self->_untarFile($uploadedFile);

      # files now contains the path to the four mandatory paths
      unless ( scalar(@{$files_ref}) == 4 ) {
          throw EBox::Exceptions::External(__x('Uploaded file does not contain the ' .
                                               'four mandatory files. It contains {number} ',
                                               number => scalar(@{$files_ref})));
      }

      # Parse config file
      $self->_parseConfigFile($files_ref);

      # Move remainder certs to their positions
      $self->_moveCerts($files_ref);

      # Create the OpenVPN client with the configuration given by the user
      $self->_createOpenVPNClient();

      # Everything goes ok so set the bundle as uploaded
      $self->set_bool('bundle_uploaded', 'true');

  }

# Method: deleteBundleUploaded
#
#    Destroy the bundle uploaded previously to communicate with the
#    eBox control center. Throw <EBox::Exceptions::External> if not
#    bundle was uploaded previously.
#
# Exceptions:
#
#    <EBox::Exceptions::External> - throw if not bundle was uploaded
#
sub deleteBundleUploaded
  {

      my ($self) = @_;

      unless ( $self->bundleUploaded() ) {
          throw EBox::Exceptions::External(__('It is required to upload ' .
                                              'a bundle to delete it'));
      }

      # Delete the OpenVPN client
      $self->_deleteOpenVPNClient();

      # Set to delete the certs
      $self->_addToCleanUp();

      # Delete the common name
      $self->_setEBoxCN(undef);

      # Undefining any certificate
      $self->_setCertFile(undef);
      $self->_setKeyFile(undef);
      $self->_setCACertFile(undef);

      # Delete the dir with this client OpenVPN configuration
      $self->delete_dir('openvpn');

      # Set as no bundle has been uploaded
      $self->set_bool('bundle_uploaded', 0);

      # Disable soap service
      $self->setEnabled(0);

  }


# Method: bundleUploaded
#
#    Check if the bundle to communicate with the control center is
#    already uploaded
#
# Returns:
#
#    boolean - true if it's already uploaded, undef otherwise
#
sub bundleUploaded
{
    my ($self) = @_;

    my $bundle = $self->get_bool('bundle_uploaded');
    if ($bundle == 0) {
        $bundle = undef;
    }
    return $bundle;
}

# Method: connectivityTest
#
#       Make a connectivity test between the control center and this
#       eBox. If everything goes ok, return true. Otherwise launch an
#       exception
#
# Returns:
#
#       integer - the percentage of loss in the connectivity test
#
# Exceptions:
#
#      <EBox::Exceptions::External> - if anything goes wrong to the
#      connection
#
sub connectivityTest
  {

      my ($self) = @_;

      unless ( $self->enabled() ) {
          throw EBox::Exceptions::External(__('You should enable the service ' .
                                              'to test the connectivity'));
      }

      # Test if client OpenVPN is running
      my $openvpnClient = $self->_isClientRunning();
      # Ping to the control center if possible
      return $self->_pingCC($openvpnClient);

  }

# Method: eBoxCN
#
#   Get eBox common name in the control center. That is, the name
#   which is known eBox in the control center
#
# Returns:
#
#   String - the common name
#
sub eBoxCN
  {
      my ( $self ) = @_;

      return $self->get_string('common_name');

  }

# Method: controlCenterIP
#
#     Get the control center public IP address
#
# Returns:
#
#     <EBox::Types::IPAddr> - containing the IP Address
#
sub controlCenterIP
  {

      my ( $self ) = @_;

      # Get the value from GConf (Currently manually)
      my $ip = EBox::Types::IPAddr->new( 'fieldName' => 'control_center',
                                         'printableName' => 'controlCenterIP',
                                         'optional'  => 0);
      $ip->setMemValue($self->hash_from_dir('openvpn'));

      return $ip;

  }

# Method: controlCenterSOAPServerPort
#
#     Get the port where the Control Center SOAP server will be
#     listening to
#
# Returns:
#
#     Integer - the port
#
sub controlCenterSOAPServerPort
  {

      my ($self) = @_;

      return $self->get_int('soap_server_port');

  }

# Method: certificateFile
#
#        Get the certificate file path which identifies this eBox at
#        the control center
#
# Returns:
#
#        String - the file path
#
sub certificateFile
  {

      my ( $self ) = @_;

      return $self->get_string('openvpn/certs/certificateFilePath');

  }

# Method: privateKeyFile
#
#        Get the private file path which is used to assure the
#        certificate file is from this eBox
#
# Returns:
#
#        String - the file path
#
sub privateKeyFile
  {

      my ( $self ) = @_;

      return $self->get_string('openvpn/certs/privateKeyFilePath');

  }

# Method: CACertificateFile
#
#        Get the CA certificate file path which identifies the control
#        center to communicate securely with it
#
# Returns:
#
#        String - the file path
#
sub CACertificateFile
  {

      my ( $self ) = @_;

      return $self->get_string('openvpn/certs/CACertificateFilePath');

  }





##########################
# Group: Private methods
##########################

# Method to regenerate httpd configuration
sub _regenHTTPdConfig
  {

      my ($self) = @_;

      my @confParams;
      push ( @confParams, 'port'  => $self->listeningPort());
      push ( @confParams, 'user'  => EBox::Config::user());
      push ( @confParams, 'group' => EBox::Config::group());
      push ( @confParams, 'debug' => EBox::Config::configkey('debug'));
      push ( @confParams, 'controlCenterCN' => CONTROL_CENTER_CN);
      push ( @confParams, 'certFile'   => $self->certificateFile());
      push ( @confParams, 'keyFile'    => $self->privateKeyFile());
      push ( @confParams, 'CACertFile' => $self->CACertificateFile());

      $self->writeConfFile ( APACHE_CONF_FILE, 'soap/apache.mas', \@confParams );
      $self->writeConfFile ( STARTUP_FILE, 'soap/startup.pl.mas', []);

  }

# Method to start/stop/restart the daemon depending on the enability
# the service
sub _doDaemon
  {

      my ($self) = @_;

      # Check the VPN daemon is running
      my $vpnClient = $self->_vpnClient();
      my $vpnClientRunning = defined ( $vpnClient ) and $vpnClient->running();

      if ( $self->enabled() and $vpnClientRunning and
           EBox::Service::running(SERVICE) ) {
          EBox::Service::manage( SERVICE, 'restart' );
      } elsif ( $self->enabled() and $vpnClientRunning) {
          EBox::Service::manage( SERVICE, 'start' );
      } elsif ( not $self->enabled() ) {
          EBox::Service::manage( SERVICE, 'stop' );
      }

  }


# Method to configure firewall rules
#
sub _configureFirewall
  {

      my ($self) = @_;

      my $gl = EBox::Global->getInstance();
      my $fw = $gl->modInstance('firewall');
      try {
          $fw->removeOutputRule('tcp', $self->listeningPort());
      } catch EBox::Exceptions::Internal with {
          # Do nothing
      };

      # It's enabled set before calling this method
      if ( $self->enabled() ) {
#          $fw->addService('soap', 'tcp', $self->listeningPort());
          $fw->addOutputRule('tcp', $self->listeningPort());
#          $fw->setObjectService('_global', 'soap', 'allow');
#      } else {
#          $fw->removeService('soap');
      }

  }

#####################################
# Accesors to certificate file paths
#####################################

# Method to set the certificate file path
sub _setCertFile # (self, path)
  {

      my ( $self, $path ) = @_;

      if ( defined ($path)) {
          $self->set_string('openvpn/certs/certificateFilePath', $path);
      } else {
          $self->unset('openvpn/certs/certificateFilePath');
      }

  }


# Method to set the private file path
sub _setKeyFile # (self, path)
  {

      my ( $self, $path ) = @_;

      if ( defined($path)) {
          $self->set_string('openvpn/certs/privateKeyFilePath', $path);
      } else {
          $self->unset('openvpn/certs/privateKeyFilePath');
      }

  }

# Method to set the CA certificate file path
sub _setCACertFile # (self, path)
  {

      my ( $self, $path ) = @_;

      if ( defined ($path)) {
          $self->set_string('openvpn/certs/CACertificateFilePath', $path);
      } else {
          $self->unset('openvpn/certs/CACertificateFilePath');
      }

  }

# Method to add to clean up the directory
sub _addToCleanUp
  {

      my ($self) = @_;

      my $dir = $self->eBoxCN();
      my $oldValues_ref = $self->get_list('to_clean_up');
      if ( defined ( $oldValues_ref )) {
          push ( @{$oldValues_ref}, $dir);
      } else {
          $oldValues_ref = [ $dir ];
      }
      $self->set_list('to_clean_up', 'string', $oldValues_ref);

  }

#####################################
# Accesors to OpenVPN client config
#####################################

# Method to set eBox common name in the control center
sub _setEBoxCN # (self, cn)
  {
      my ( $self, $cn ) = @_;

      if ( defined ( $cn )) {
          $self->set_string('common_name', $cn);
      } else {
          $self->unset('common_name');
      }

  }

# Method to set eBox common name in the control center
# String with the first part of the IP address
sub _setControlCenterIP # (self, ip)
  {
      my ( $self, $ip ) = @_;

      # If undef, then it unsets the value

      # Setting a host IP address
      my $ipType = EBox::Types::IPAddr->new(
                          'fieldName' => 'control_center',
                          'printableName' => 'control center IP address',
                          'ip' => $ip,
                          'mask' => 32
                                           );
      $ipType->storeInGConf($self, 'openvpn');

  }

# Method to get the OpenVPN client service
# Return <EBox::Types::Service>
sub _clientOpenVPNService
  {
      my ( $self ) = @_;

      my $serv = EBox::Types::Service->new( 'fieldName' => 'server' );
      $serv->setMemValue($self->hash_from_dir('openvpn'));

      return $serv;

  }

# Method to set the OpenVPN client service
sub _setClientOpenVPNService # (self, protocol, port)
  {
      my ( $self, $protocol, $port ) = @_;

      my $serv;
      if ( defined ($protocol) and defined ($port)) {
          $serv = EBox::Types::Service->new( 'fieldName' => 'server',
                                             'protocol'  => $protocol,
                                             'port'      => $port);
      } else {
          $serv = EBox::Types::Service->new( 'fieldName' => 'server');
      }

      # Unset the value if protocol or port is undefined
      $serv->storeInGConf($self, 'openvpn');

  }

# Method to set the port where the SOAP Server from the CC will be listening to
sub _setControlCenterSOAPServerPort
  {

      my ($self, $port) = @_;

      $self->set_int('soap_server_port', $port);

  }

# Method to set up/down a hidden client to the OpenVPN
sub _setOpenVPNClient
  {

      my ( $self ) = @_;

      my $client = $self->_vpnClient();

      # Set hidden clients active if the SOAP Module is enabled
      $self->{openvpn}->setInternalService( $self->enabled() );

      if ( defined ( $client ) ){
          # Set active, when soap is enabled
          $client->setService( $self->enabled() );
      }

  }

# Method to create an OpenVPN client if does not exist
# If exists return the created one
sub _createOpenVPNClient
  {

      my ($self) = @_;

      # Check whether the client is already created or not
      my $client = $self->_vpnClient();
      unless ( defined ( $client ) ) {
          # Get the client name
          my $clientName = $self->_vpnClientName();
          # Create the list servers
          my $vpnServ = $self->_clientOpenVPNService();
          my @servers = ([ $self->controlCenterIP()->ip() , $vpnServ->port()]);
          # Create the client
          my $openvpn = $self->{openvpn};
          $client = $openvpn->newClient(
                                        $clientName,
                                        servers => \@servers,
                                        proto   => $vpnServ->protocol(),
                                        caCertificate  => $self->CACertificateFile(),
                                        certificate    => $self->certificateFile(),
                                        certificateKey => $self->privateKeyFile(),
                                        service => $self->enabled(),
                                        internal  => 1,
                                       );
      }

      return $client;

  }

# Method to delete OpenVPN client if it created
sub _deleteOpenVPNClient
  {

      my ($self) = @_;

      my $clientName = $self->_vpnClientName();

      if ( $self->{openvpn}->clientExists($clientName) ) {
          # Get the client to delete
          my $client = $self->{openvpn}->client($clientName);
          $client->delete();
      }

  }
# Method to untar the bundle
# Return an array ref with the paths to the files untarred
sub _untarFile
  {

      my ($self, $uploadedFile) = @_;

      # It returns the absolute path
      my $outDir = tempdir( DIR => EBox::Config::tmp() );

      # Put output to the directory outDir
      my $tarCmd = qq{tar xzvf '$uploadedFile' --directory '$outDir'};

      # Return an array ref with the output
      my $ret_ref = EBox::Sudo::command($tarCmd);

      my @retArray = map { $_ = $outDir . '/' . $_; chomp; $_ } @{$ret_ref};

      return \@retArray;

  }

# Method to parse the config file given by the control center.
# Parameters: files_ref with an array ref with the paths to the files
# within the tar file. It can throw EBox::Exceptions::External if
# doesn't exist or its content is invalid
sub _parseConfigFile # (self, files_ref)
  {

      my ($self, $files_ref) = @_;

      my $clientConfName = CLIENT_CC;
      my $confPath = (grep { m/$clientConfName$/ } @{$files_ref})[0];

      unless ( defined ( $confPath ) ) {
          throw EBox::Exceptions::External(__('The OpenVPN client ' .
                                              'configuration file ' .
                                              'is missing'));
      }

      my $confFile = new Config::Tiny->read($confPath);
      unless ( defined ( $confFile ) ) {
          throw EBox::Exceptions::External(__('The OpenVPN client ' .
                                              'configuration file ' .
                                              'is not well formatted '));
      }

      # Store the properties to the correct GConf variables
      $self->_setEBoxCN( $confFile->{_}->{common_name} );
      $self->_setControlCenterIP( $confFile->{_}->{vpn_server_ip} );
      $self->_setClientOpenVPNService(
                                      $confFile->{_}->{vpn_server_protocol},
                                      $confFile->{_}->{vpn_server_port}
                                     );
      $self->_setControlCenterSOAPServerPort(
                                      $confFile->{_}->{soap_server_port}
                                            );


  }

# Move the certs to the conf file
# files_ref with an array ref to the paths where certificates are
# Throw EBox::Exceptions::External if something goes wrong
sub _moveCerts # (self, files_ref)
  {

      my ( $self, $files_ref ) = @_;

      my @pemFiles = grep { m/.pem$/ } @{$files_ref};

      unless (scalar ( @pemFiles ) == 3) {
          throw EBox::Exceptions::External(__('Some certificate is missing'));
      }

      my $destDir = EBox::Config->conf() . CONF_SUBDIR . $self->eBoxCN() . '/';

      # Check if already exists if so, throw an exception
      if ( -d $destDir ) {
          throw EBox::Exceptions::External(__x('You cannot upload this bundle ' .
                                               'since the name {name} has been ' .
                                               'already used for a bundle which ' .
                                               'will be cleaned up. If you want ' .
                                               'to upload the bundle, please save ' .
                                               'changes first',
                                               name => $self->eBoxCN(),
                                              ));
      } else {
          mkdir ( $destDir, 0700 );
      }

      foreach my $file (@pemFiles) {
          # Get the name from the abs path
          my $fileName = fileparse($file);
          if ( $fileName eq 'ca-cert.pem' ) {
              move( $file, $destDir ) or
                throw EBox::Exceptions::Internal("Error moving from $file to $destDir");
              $self->_setCACertFile( $destDir . $fileName );
          } elsif ( $fileName =~ m/cert/ ) {
              # Client certification file
              move ( $file, $destDir ) or
                throw EBox::Exceptions::Internal("Error moving from $file to $destDir");
              $self->_setCertFile( $destDir . $fileName );
          } elsif ( $fileName =~ m/private-key/ ) {
              # Client private key file
              move ( $file, $destDir ) or
                throw EBox::Exceptions::Internal("Error moving from $file to $destDir");
              $self->_setKeyFile( $destDir . $fileName );
          }
      }

      unless ( defined ( $self->certificateFile() )){
          throw EBox::Exceptions::External(__('Certificate file is missing'));
      }
      unless ( defined ( $self->privateKeyFile() )){
          throw EBox::Exceptions::External(__('Private key file is missing'));
      }
      unless ( defined ( $self->CACertificateFile() )){
          throw EBox::Exceptions::External(__('Certification Authority file ' .
                                              'is missing'));
      }

  }

# This method deletes any certificate which is not longer used
# Get the list and then delete
sub _deleteUnusedCerts
  {

      my ($self) = @_;

      # Delete all directories under to clean up key
      my $dirsToCleanUp_ref = $self->get_list('to_clean_up');

      # Check there is something to delete
      (scalar ( @{$dirsToCleanUp_ref} ) > 0) or return;

      foreach my $dir (@{$dirsToCleanUp_ref}) {
          # The complete path
          $dir = EBox::Config::conf() . CONF_SUBDIR . $dir;
          File::Path::rmtree( $dir, { error => \my $err } );
          if ( defined ( $err ) and scalar ( @{$err} ) > 0 ) {
              my ($file, $msg) = $err->[0];
              throw EBox::Exceptions::Internal("No possible unlink $file: $msg");
          }
      }

      # Unset the list
      $self->unset('to_clean_up');

      # this is to avoid mark the modules as changed by the removal of deleted information
      # XXX TODO: reimplement using ebox state
      my $global = EBox::Global->getInstance();
      $global->modRestarted('soap');


  }

# Method to test if the OpenVPN client is up and running
# Returns <EBox::OpenVPN::Client>
# It can throw External exceptions
sub _isClientRunning
  {

      my ($self) = @_;

      # Get the OpenVPN client
      my $client = $self->_vpnClient();

      unless ( defined ( $client )) {
          throw EBox::Exceptions::External(__('You should upload a bundle ' .
                                              'to be able to communicate with ' .
                                              'the control center'));
      }

      # Test if it's running
      unless ( $client->running() ) {
          EBox::error('The OpenVPN client ' . $self->_vpnClientName() .
                      ' is not running');
          throw EBox::Exceptions::External(__('The OpenVPN client is not running. ' .
                                              'You may need to save changes in order ' .
                                              'to set up the OpenVPN client'));
      }

      return $client;

  }

# Method to ping the server via vpn net device
# Launch an exception if it was not possible to contact with the
# control center.
# Returns: the percent of loss
sub _pingCC # (self, client)
  {

      my ($self, $client) = @_;

      my $iface = $client->iface();

      unless ( EBox::NetWrappers::iface_exists($iface) and
               EBox::NetWrappers::iface_is_up($iface) ) {
          throw EBox::Exceptions::Internal("The $iface interface is currently down");
      }

      my $networkAddresses_ref = EBox::NetWrappers::iface_addresses_with_netmask($iface);
      # I assume just one address for vpn
      my $hostIP = (keys (%{$networkAddresses_ref}))[0];
      my $networkMask = (values (%{$networkAddresses_ref}))[0];

      my $bits = EBox::NetWrappers::bits_from_mask($networkMask);

      my $networkIP = EBox::NetWrappers::ip_network( $hostIP, $networkMask );
      my $vpnAddress = new Net::IP( "$networkIP/$bits" );
      # I assume first IP address from VPN is the server IP (OpenVPN standard)
      $vpnAddress++;

      my $serverAddress = $vpnAddress->ip();

      my ($attempts, $success, $percentLoss);
      try {
          my $result_ref = EBox::Sudo::command('ping -c ' . NUM_PING_ATTEMPTS .
                                               " -I $iface $serverAddress");
          my ($lineNeeded) = grep { m/\d packets/g } @{$result_ref};
          ($attempts, $success, $percentLoss) =
            ($lineNeeded =~ m/^(\d) packets.*(\d) received.*(\d)%/);
      } catch EBox::Exceptions::Command with {
          $percentLoss = 100;
          $success = 0;
          $attempts = NUM_PING_ATTEMPTS;
      };

      return $percentLoss;


  }

# Method to get the client name
# Helper function
# Return an string containing the name or undef if there is no eBox CN
sub _vpnClientName
  {

      my ($self) = @_;

      if ( defined ( $self->eBoxCN() )) {
          return EBox::OpenVPN::reservedPrefix() . $self->eBoxCN();
      } else {
          return undef;
      }

  }

# Helper function to get the VPN client from ebox-openvpn interface
# Return <EBox::OpenVPN::Client> object
# Return undef it does not exist
sub _vpnClient
  {

      my ( $self ) = @_;

      # The prefix is available from openvpn API
      my $clientName = $self->_vpnClientName();
      if ( defined ($clientName) ) {
          if ( $self->{openvpn}->clientExists($clientName) ) {
              return $self->{openvpn}->client($clientName);
          }
      }

      # No client name
      return undef;

  }

# Method to get the address from the VPN interface (tapX)
# Returns the string with the vpn interface
# Undef if not exists
sub _vpnAddress
  {

      my ( $self ) = @_;

      my $client = $self->_vpnClient();

      unless ( defined ( $client )) {
          return undef;
      }

      my $vpnIface = $client->iface();

      unless ( EBox::NetWrappers::iface_exists($vpnIface) and
               EBox::NetWrappers::iface_is_up($vpnIface) ) {
          return undef;
      }

      my $networkAddresses_ref = EBox::NetWrappers::iface_addresses_with_netmask($vpnIface);
      # I assume just one address for vpn
      my $hostIP = (keys (%{$networkAddresses_ref}))[0];

      return $hostIP;

  }

1;
