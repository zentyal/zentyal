# Copyright (C) 2006-2007 Warp Networks S.L.
# Copyright (C) 2008-2013 Zentyal S.L.
#
# This program is free softwa re; you can redistribute it and/or modify
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

package EBox::OpenVPN;

use base qw(
             EBox::Module::Service
             EBox::NetworkObserver
             EBox::LogObserver
             EBox::FirewallObserver
             EBox::CA::Observer);

use Perl6::Junction qw(any);
use TryCatch;

use EBox::Global;
use EBox::Gettext;
use EBox::Sudo;
use EBox::Validate;
use EBox::Dashboard::Section;
use EBox::Dashboard::Value;
use EBox::OpenVPN::Server;
use EBox::OpenVPN::Client;
use EBox::OpenVPN::Server::ClientBundleGenerator::EBoxToEBox;
use EBox::OpenVPN::FirewallHelper;
use EBox::OpenVPN::LogHelper;
use EBox::CA;
use EBox::CA::DN;
use EBox::NetWrappers qw();
use EBox::FileSystem;
use EBox::Exceptions::External;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;

use Perl6::Junction qw(any);
use File::Slurp;

use constant MAX_IFACE_NUMBER => 999999;  # this is the last number which prints
# correctly in ifconfig
use constant USER  => 'nobody';
use constant GROUP => 'nogroup';

use constant DH_PATH => '/etc/openvpn/ebox-dh2048.pem';
use constant OPENVPN_BIN => '/usr/sbin/openvpn';
use constant CONF_DIR    => '/etc/openvpn';
use constant LOG_DIR => '/var/log/openvpn';

my @daemonTypes   =
  qw(server client); # in the daemons method they will appear in this order
my $anyDaemonType = any @daemonTypes;

sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'openvpn',
                                      printableName => __('VPN'),
                                      @_);
    bless($self, $class);
    return $self;
}

sub _preSetConf
{
    my ($self) = @_;

    $self->_cleanupDeletedDaemons();
    $self->initializeInterfaces();
}

sub _setConf
{
    my ($self) = @_;
    $self->_writeConfFiles();
    $self->_prepareLogFiles();
}

# Method: initializeInterfaces
#
#   Set interface number if has not been set
sub initializeInterfaces
{
    my ($self) = @_;

    my $servers = $self->model('Servers');
    $servers->initializeInterfaces();

    my $clients = $self->model('Clients');
    $clients->initializeInterfaces();
}

# Method: usedFiles
#
#       Override EBox::Module::Service::usedFiles
#
sub usedFiles
{
    return [
            {
              'file' => '/etc/quagga/daemons',
              'module' => 'openvpn',
              'reason' => __('To configure Quagga to run ripd and zebra')
            },
            {
              'file' => '/etc/quagga/debian.conf',
              'module' => 'openvpn',
              'reason' =>
                __('To configure Quagga to listen on the given interfaces')
            },
            {
              'file' => '/etc/quagga/zebra.conf',
              'module' => 'openvpn',
              'reason' => __('Main zebra configuration file')
            },
            {
              'file' => '/etc/quagga/ripd.conf',
              'module' => 'openvpn',
              'reason' => __(
                             'To configure ripd to exchange routes with client '
                               .'to client connections'
              )
            },
            {
              'file' => '/etc/default/openvpn',
              'module' => 'openvpn',
              'reason' => __('To remove system-wide VPN servers autostart')
            }
    ];
}

#  Method: enableModDepends
#
#   Override EBox::Module::Service::enableModDepends
#
sub enableModDepends
{
    my ($self) = @_;
    my @depends = qw(network);

    # we will need iptable postrouting rules if we have any server that uses NAT
    my $postroutingNeeded = grep {$_->masquerade()} $self->servers();

    if ($postroutingNeeded) {

        # we need firewall module to add postrouting rules
        push @depends, 'firewall';
    }

    return \@depends;
}

#
# Method: confDir
#
#    Return the directory used to store OpenVPN's configuration files
#
# Returns:
#
#   String - the directory path
#
sub confDir
{
    my ($self) = @_;
    return CONF_DIR;
}

#
# Method: confDir
#
#    Return the OpenVPN's binary location
#
# Returns:
#
#   String - path to the OpenVPN program
#
sub openvpnBin
{
    my ($self) = @_;
    return OPENVPN_BIN;
}

sub _writeConfFiles
{
    my ($self) = @_;

    $self->_writeRIPDaemonConf();

    $self->writeConfFile('/etc/default/openvpn',
        '/openvpn/default-openvpn.mas');

    my $confDir = $self->confDir();

    my @daemons = $self->daemons();
    foreach my $daemon (@daemons) {
        $daemon->createDirectories();
        $daemon->writeConfFile($confDir);
        $daemon->writeSystemdFile();
    }
}

sub _prepareLogFiles
{
    my ($self) = @_;

    my $logDir = $self->logDir();
    foreach my $name (@{$self->daemonsNames()}) {
        for my $file ("$logDir/$name.log", "$logDir/status-$name.log") {
            EBox::Sudo::root("touch '$file'",
                             "chown root:ebox '$file'",
                             "chmod 0640 '$file'");
        }
    }
}

sub _cleanupDeletedDaemons
{
    my ($self) = @_;

    my $deletedModel = $self->model('DeletedDaemons');
    my @deletedDaemons =  @{ $deletedModel->daemons() };

    foreach my $daemon (@deletedDaemons) {
        my $name  = $daemon->{name};
        my $type  = $daemon->{type};

        my $class = undef;
        if ($type eq 'server') {
            $class = 'EBox::OpenVPN::Server';
        }elsif ($type eq 'client') {
            $class = 'EBox::OpenVPN::Client';
        }else {
            throw EBox::Exceptions::Internal("Bad daemon type: $type");
        }

        $class->deletedDaemonCleanup($name);
    }

    # clear deleted daemons data
    $deletedModel->clear();

# this is to avoid mark the modules as changed bz the removal of deleted information
# XXX TODO: reimplement using ebox state
    my $global = EBox::Global->getInstance();
    $global->modRestarted('openvpn');
}

#  Method: notifyDaemonDeletion
#
#    When a daemons is deleted this method must be called to assure that in the
#    next configuration regeration
sub notifyDaemonDeletion
{
    my ($self, $name, $type) = @_;
    $self
      or
      throw EBox::Exceptions::MissingArgument("you must call this on a object");
    $name
      or throw EBox::Exceptions::MissingArgument(
                            "you must supply the name of the daemon to delete");
    $type
      or throw EBox::Exceptions::MissingArgument('type');

    my $removedDaemonsModel = $self->model('DeletedDaemons');
    $removedDaemonsModel->addDaemon($name, $type);

    $self->notifyLogChange();
}

# all openvpn daemons related methods

#
# Method: daemons
#
#       return all daemons registered in the module
#
#
# Returns:
#
#   a list with daemons objects
#
sub daemons
{
    my ($self) = @_;

    my @daemons = ($self->servers(),$self->clients(),);

    return @daemons;
}

#
# Method: activeDaemons
#
#  Return all active daemons registered in the module
#
#
# Returns:
#
#   array - a list with daemons objects
#
sub activeDaemons
{
    my ($self) = @_;
    return grep { $_->isEnabled() } $self->daemons();
}

#
# Method: daemonsNames
#
#  return  the names of all daemons registered in the module
#
#
# Returns:
#
#   array - a list with daemons names
#
sub daemonsNames
{
    my ($self) = @_;

    my @daemonsNames = ($self->serversNames(),$self->clientsNames(),);

    return \@daemonsNames;
}

# server-related methods

#
# Method: servers
#
#   List all servers registered in the module
#
#
# Returns:
#
#   array - a list with servers objects
#
sub servers
{
    my ($self) = @_;
    my $serversModel = $self->model('Servers');
    return @{ $serversModel->servers() };
}

#
# Method: activeServers
#
#   List all active servers registered in the module
#
#
# Returns:
#
#   array - a list with active servers objects
#
sub activeServers
{
    my ($self) = @_;
    return grep { $_->isEnabled() } $self->servers();
}

#
# Method: serverNames
#
#   List the names of all servers registered in the module
#
#
# Returns:
#
#   array - a list with servers names
#
sub serversNames
{
    my ($self) = @_;

    my @serversNames = map {$_->name()} $self->servers();

    return @serversNames;
}

# a object server cache may be a good idea?

#
# Method: server
#
#     Return the object representing the given server
#
# Parameters:
#
#    name - the servers name
#
# Returns:
#
#   <EBox::OpenVPN::Server> - the server object
#
sub server
{
    my ($self, $name) = @_;
    my $serversModel = $self->model('Servers');
    return $serversModel->server($name);
}

#
# Method: serverExists
#
#   returns wether a given server exists or not
#
# Parameters:
#
#    name - the server's name
#
# Returns:
#  true if the server exists, false otherwise
#
#
sub serverExists
{
    my ($self, $name) = @_;

    my $serversModel = $self->model('Servers');
    return $serversModel->serverExists($name);
}

sub _portsByProtoFromServers
{
    my ($self, @servers) = @_;

    my %ports;
    foreach my $proto (qw(tcp udp)) {
        my @protoServers = grep { $_->proto eq $proto  } @servers;
        my @ports        = map  { $_->port } @protoServers;

        $ports{$proto} = \@ports;
    }

    return \%ports;
}

## clients

#
# Method: clients
#
#   List all clients registered in the module
#
#
# Returns:
#
#   array - a list with client's objects
#
sub clients
{
    my ($self) = @_;
    my $clientModel = $self->model('Clients');

    return @{  $clientModel->clients };
}

#
# Method: activeClients
#
#   List all active clients registered in the module
#
#
# Returns:
#
#   array - a list with active client's objects
#
sub activeClients
{
    my ($self) = @_;
    return grep { $_->isEnabled() } $self->clients();
}

#
# Method: clientsNames
#
#   List the names of all clients registered in the module
#
#
# Returns:
#
#   array - a list with client's names
#
sub clientsNames
{
    my ($self) = @_;

    my @clientsNames = map {$_->name()} $self->clients();

    return @clientsNames;
}

# Method: userClientsNames
#
#   List the names of all clents registeredby the user
# Returns:
#
#   list - a list with client's names
#
sub userClientsNames
{
    my ($self) = @_;

    my @clients = grep { not $_->internal } $self->clients();
    my @clientsNames = map { $_->name } @clients;

    return @clientsNames;
}

#
# Method: client
#
#    Return the object representing the given client
#
# Parameters:
#
#    name - the client's name
#
# Returns:
#
#   <EBox::OpenVPN::Client> - the client object
#
# Exceptions:
#
#   <EBox::Exceptions::Internal> - throw if the client does not exist
#
sub client
{
    my ($self, $name) = @_;

    my $clientModel = $self->model('Clients');
    return $clientModel->client($name);
}

#
# Method: clientExists
#
#   return whether a given client exists or not
#
# Parameters:
#
#    name - the client's name
#
# Returns:
#  true if the client exists, false otherwise
#
#

sub clientExists
{
    my ($self, $name) = @_;

    my $clientModel = $self->model('Clients');
    return $clientModel->clientExists($name);
}

# return a ref to a list of [proto server port]
sub _serversToConnect
{
    my ($self) = @_;
    my @clients = $self->activeClients();

    my @servers = map {
        my $client = $_;
        my $proto = $client->proto();

        my @serversForClient;
        foreach my $server_r (@{ $client->servers() } ) {
            my ($server, $serverPort) = @{$server_r};
            push @serversForClient, [$proto, $server, $serverPort];
        }

        @serversForClient;
    } @clients;

    return \@servers;
}

# Method: checkNewDaemonName
#
#    Check if the name for a new daemon is correct and does not conflicts with
#    the actual configuration
#
#  Parameters:
#          $name       - name to be checked
#          $daemonType - new daemon's type
#          $internal   - whether is a internal daemon
sub checkNewDaemonName
{
    my ($self, $name, $daemonType, $internal) = @_;

    if (not $name =~ m/^[\w\.\-]+$/) {
        throw EBox::Exceptions::External(
            __x(
              q{Invalid name {name}. Only alpahanumeric  and '-', '_', '.' characters are allowed},
                name => $name,
            )
                                        )
    }

    # check if the daemon name is repeated in others daemon types
    if ($daemonType eq 'server') {
        my $clients = $self->model('Clients');
        if ($clients->clientExists($name)) {
            throw EBox::Exceptions::External(
                __x(
'Cannot use the name {n} because there is a client with the same name',
                    n => $name
                )
            );
        }

    } elsif ($daemonType eq 'client') {
        my $servers = $self->model('Servers');
        if ($servers->serverExists($name)) {
            throw EBox::Exceptions::External(
                __x(
'Cannot use the name {n} because there is a server with the same name',
                    n => $name
                )
            );
        }
    } else {
        throw EBox::Exceptions::Internal("Bad daemon type: $daemonType");
    }
}

# Returns:
#   directory to store the log files (not status log files)
#
sub logDir
{
    my ($class) = @_;

    return LOG_DIR;
}

#
# Method: user
#
#    Gets the user will be used to run the openvpn daemons
#    after root drops privileges
#
# Returns:
#
#    String - the user's name
#
sub user
{
    my ($self) = @_;
    return USER;
}

#
# Method: group
#
#    Gets the group will be used to run the openvpn daemons
#    after root drops privileges
#
# Returns:
#
#    String - the group's name
#
sub group
{
    my ($self) = @_;
    return GROUP;
}

#
# Method: dh
#
#    Get the path to the Diffie-Hellman
#    parameters file used by openvpn server
#
# Returns:
#
#    String - the path to the Diffie-Hellman parameters file
#
sub dh
{
    my ($self) = @_;
    return DH_PATH;
}

sub usesPort
{
    my ($self, $proto, $port, $iface) = @_;

    my @daemons = $self->daemons();
    foreach my $daemon (@daemons) {
        if ($daemon->usesPort($proto, $port, $iface)) {
            return 1;
        }
    }

    return undef;
}

sub firewallHelper
{
    my ($self) = @_;

    my $enabled = $self->isEnabled();

    # Initialize interfaces before setting fw rules
    if ($enabled and EBox::Global->getInstance()->modIsChanged('openvpn')) {
        $self->initializeInterfaces();
    }

    my @ifaces = map {$_->iface() } $self->activeDaemons();

    my @activeServers =  $self->activeServers();
    my @ports = map {
        my $port = $_->port();
        my $proto = $_->proto();
        my $external = $_->runningOnInternalIface ? 0 : 1;
        my $listen   = $_->local();

        {
           port => $port,
           proto => $proto,
           external => $external,
           listen => $listen
        }
    }  @activeServers;

    my %networksToMasquerade = map {
        my $network = $_->subnet();
        my $mask    = $_->subnetNetmask();
        my $cidrNet = EBox::NetWrappers::to_network_with_mask($network,$mask);
        ($cidrNet => 1)
      } grep {
        $_->masquerade() and $_->can('subnet')
      } @activeServers;

    my $serversToConnect = $self->_serversToConnect();

    my $firewallHelper = new EBox::OpenVPN::FirewallHelper(
        service          => $enabled,
        ifaces           => \@ifaces,
        ports     => \@ports,
        serversToConnect => $serversToConnect,
        networksToMasquerade => [keys %networksToMasquerade],

    );
    return $firewallHelper;
}

#  Method: CAIsReady
#
# return if the CA is ready to support servers (valid CA and at least one
# certificate are required for this)
sub CAIsReady
{
    my $ca = EBox::Global->modInstance('ca');
    if (not  $ca->isCreated) {
        return 0;
    }

    my $nValidCertificates =
      grep {$_->{state} eq 'V'} @{  $ca->listCertificates  };

    my $ready =
      ($nValidCertificates >= 2); # why 2? bz we need the CA certificate and
    # another certifcate for the server (when
    #  the CA is invalid all the other certs
    #  are invalid so if we have valid
    #  certificates we are sure one of the is
    #  the CA cert)

    return $ready;
}

sub _daemons
{
    my ($self) = @_;

    my @daemons = (
        {
            name => 'zebra',
            precondition => sub {  return $self->ripDaemonService() },
        },
        {
            name => 'ripd',
            precondition => sub {  return $self->ripDaemonService() },
        },
    );

    foreach my $daemon ($self->daemons()) {
        push @daemons, $daemon->toDaemonHash();
    }
    return \@daemons;
}

#  rip daemon/quagga stuff
#
# Method: ripDaemon
#
#    Get the parameters of the RIP daemon
#    if the OpenVPN module needs one
#
# Returns:
#
#    - undef if not RIP daemon is neccessary
#    - if RIP is neccessary a hash ref with RIP daemons parameters:
#          ifaces      - list of ifaces to use by RIP daemon
#          redistribute - bool parameters which signal if routes
#                           redistribution is required
#
sub ripDaemon
{
    my ($self) = @_;

    my @ifaces;
    my $redistribute = 0;

    foreach my $daemon ($self->activeDaemons()) {
        my $rip = $daemon->ripDaemon();
        if (defined $rip) {
            push @ifaces, $rip->{iface};
            if ( (exists $rip->{redistribute}) && $rip->{redistribute}) {
                $redistribute = 1;
            }
        }
    }

    if (@ifaces) {
        return { ifaces => \@ifaces, redistribute => $redistribute  };
    }else {
        return undef;
    }

}

#
# Method: ripDaemonService
#
#   Check whether a RIP daemon is neccesary or not
#
# Returns:
#
#    bool
sub ripDaemonService
{
    my ($self) = @_;

    foreach my $daemon ($self->activeDaemons()) {
        my $rip = $daemon->ripDaemon();
        if (defined $rip) {
            return 1;
        }
    }

    return undef;
}

sub _writeRIPDaemonConf
{
    my ($self) = @_;

    my $ripDaemon =  $self->ripDaemon();
    defined $ripDaemon or return;

    my $ifaces       = $ripDaemon->{ifaces};
    my $redistribute = $ripDaemon->{redistribute};

    my $confDir = '/etc/quagga';
    my ($quaggaUser, $quaggaPasswd, $quaggaUid, $quaggaGid) =
      getpwnam('quagga');
    defined $quaggaUser
      or throw EBox::Exceptions::Internal('No quagga user found in the system');

    my $debug = EBox::Config::boolean('debug');

    my $fileAttrs = {
                     uid  => $quaggaUid,
                     gid  => $quaggaGid,
                     mode => '0400',
    };

    $self->writeConfFile("$confDir/debian.conf", '/openvpn/quagga/debian.conf.mas', [],
                         $fileAttrs);
    $self->writeConfFile("$confDir/daemons", '/openvpn/quagga/daemons.mas', [],
                         $fileAttrs);
    $self->writeConfFile("$confDir/zebra.conf", '/openvpn/quagga/zebra.conf.mas',
                         [
                             debug => $debug
                         ],
                         $fileAttrs);

    my @ripdConfParams = (
                          ifaces       => $ifaces,
                          redistribute => $redistribute,
                          insecurePasswd => _insecureRipPasswd(),
                          debug          => $debug,
                         );
    $self->writeConfFile("$confDir/ripd.conf", '/openvpn/quagga/ripd.conf.mas',
                         \@ripdConfParams, $fileAttrs);

}

#
# Method: availableCertificates
#
#   Get the certificates which are available to use with OpenVPN
#
# Returns:
#
#    array ref -  a list with the common names of available certificates
sub availableCertificates
{
    my ($self) = @_;

    my $ca = EBox::Global->modInstance('ca');
    return [] unless ($ca->isCreated());
    my $certificates_r = $ca->listCertificates(state => 'V', excludeCA => 1);
    my @certificatesCN =
      map {$_->{dn}->attribute('commonName');} @{$certificates_r};

    return \@certificatesCN;
}

# ca observer stuff

sub certificateRevoked
{
    my ($self, @params) = @_;
    foreach my $server ($self->servers()) {
        if ($server->certificateRevoked(@params)) {
            return 1;
        }
    }

    return 0;
}

sub certificateExpired
{
    my ($self, @params) = @_;
    $self->_invokeOnServers('certificateExpired', @params);
}

sub freeCertificate
{
    my ($self, @params) = @_;
    $self->_invokeOnServers('freeCertificate', @params);
}

# network observer stuff

sub ifaceMethodChanged
{
    my ($self, @params) = @_;
    return $self->_anyDaemonReturnsTrue('ifaceMethodChanged', @params);
}

sub vifaceDelete
{
    my ($self, @params) = @_;
    return $self->_anyDaemonReturnsTrue('vifaceDelete', @params);
}

sub freeIface
{
    my ($self, @params) = @_;
    return $self->_invokeOnDaemons('freeIface', @params);
}

sub freeViface
{
    my ($self, @params) = @_;
    return $self->_invokeOnDaemons('freeViface', @params);
}

sub changeIfaceExternalProperty # (iface, external)
{
    my ($self, @params) = @_;
    return $self->_invokeOnDaemons('changeIfaceExternalProperty', @params);
}

sub staticIfaceAddressChanged
{
    my ($self, @params) = @_;
    return $self->_anyDaemonReturnsTrue('staticIfaceAddressChanged', @params);
}

# common listeners helpers..

sub _invokeOnServers
{
    my ($self, $method, @methodParams) = @_;
    foreach my $server ($self->servers()) {
        my $method_r = $server->can($method);
        defined $method_r
          or throw EBox::Exceptions::Internal("No such method $method");
        $method_r->($server, @methodParams);
    }
}

sub _invokeOnDaemons
{
    my ($self, $method, @methodParams) = @_;
    foreach my $daemon ($self->daemons()) {
        my $method_r = $daemon->can($method);
        defined $method_r
          or throw EBox::Exceptions::Internal("No such method $method");
        $method_r->($daemon, @methodParams);
    }
}

sub _anyDaemonReturnsTrue
{
    my ($self, $method, @methodParams) = @_;
    foreach my $daemon ($self->daemons()) {
        my $method_r = $daemon->can($method);
        defined $method_r
          or throw EBox::Exceptions::Internal("No such method $method");
        if ($method_r->($daemon, @methodParams)) {
            return 1;
        }
    }

    return undef;
}

# Method: newClient
#
#    Create a new VPN client from API
#
# Positional parameters:
#
#    name - String the name to set the VPN client
#
# Named parameters:
#
#    internal - Boolean indicating whether the client is internal or
#               not
#
#    service - Boolean indicating whether the new client must be up or
#              not
#
#    proto - String the protocol used by client. Options: 'udp' or
#            'tcp'
#
#    servers - Array ref containing tuples with two elements: the VPN
#              server IP address and the port which is listening to
#
#    caCertificate - String the path to the CA certificate
#
#    certificate   - String the path to the VPN client certificate
#
#    certificateKey - String the path to the VPN client private key
#    corresponding to the previous certificate
#
#    ripPasswd     - String the RIP password to exchange routes with
#
#    local         - local interface/address to bind to (optional)
#    lport         - local port to bind to (optional)
#
# Returns:
#
#    <EBox::OpenVPN::Client> - the newly created VPN client daemon
#    instance
#
sub newClient
{
    my ($self, $name, %params) = @_;
    my @paramsNeeded = qw(servers proto
      caCertificate certificate certificateKey
      ripPasswd
      service internal);

    if (( exists $params{bundle} ) and ($params{bundle})) {
        %params = (
                   %params,
                   EBox::OpenVPN::Server::ClientBundleGenerator::EBoxToEBox
                     ->initParamsFromBundle(
                                            $params{bundle}
                     )
        );
    }

    foreach my $param (@paramsNeeded) {
        exists $params{$param}
          or throw EBox::Exceptions::MissingArgument($param);
    }

    my $client;
    try {
        $client = $self->_doNewClient($name, %params);
    } catch ($e) {
        system ('rm -rf ' . $params{tmpDir}) if ($params{bundle});
        $e->throw();
    }
    system ('rm -rf ' . $params{tmpDir}) if ($params{bundle});

    return $client;
}

sub setClientConfFromBundle
{
    my ($self, $name, $bundle) = @_;

    my @confParams =
      EBox::OpenVPN::Server::ClientBundleGenerator::EBoxToEBox->initParamsFromBundle($bundle);

    $self->_setClientConf($name, @confParams);
}

sub _doNewClient
{
    my ($self, $name, %params) = @_;

    # create client

    my $clients = $self->model('Clients');

    my $hidden = $params{internal} ? 1 : 0;
    my $addedId = $clients->add(
        name => $name,
        internal => $params{internal},
        service => 0,
       );
    my $clientRow = $clients->row($addedId);
    $clientRow->setReadOnly($hidden);

    $self->_setClientConf($name, %params);

    # config complete! we can set service to 1
    if ($params{service}) {
        $clientRow->elementByName('service')->setValue(1);
    }
    $clientRow->store();

    return $clients->client($name);
}

sub _setClientConf
{
    my ($self, $name, %params) = @_;

    # unroll servers parameter
    my $server     = $params{servers}->[0]->[0];
    my $serverPort = $params{servers}->[0]->[1];
    EBox::OpenVPN::Client->checkServer($server);

    my $serverPortAndProtocol = "$serverPort/" . $params{proto};

    my $clients   = $self->model('Clients');
    my $clientRow = $clients->findRow(name => $name);

    my $certPaths = EBox::OpenVPN::Client->setCertificatesFilesForName(
        $name,
        caCertificate => $params{caCertificate},
        certificate => $params{certificate},
        certificateKey => $params{certificateKey},
       );

    # set config
    my $configRow =  $clientRow->subModel('configuration')->row();
    my %configToSet = (
                       server => $server,
                       serverPortAndProtocol =>  $serverPortAndProtocol,
                       ripPasswd             => $params{ripPasswd},
                       tunInterface          => $params{tunInterface},
                       %{$certPaths},
                      );

    my @optionalParameters = qw(lport localAddr);
    foreach my $optional (@optionalParameters) {
        if (exists $params{$optional}) {
            $configToSet{$optional} = $params{$optional};
        }
    }

    while (my ($attr, $value) = each %configToSet) {
        $configRow->elementByName($attr)->setValue($value);
    }
    $configRow->store();

    # remove leftover upload temporary files bz they aren't needed anymore
    foreach my $f (qw(caCertificate certificate certificateKey)) {
        my $path =  EBox::Config::tmp() . $f . '_path';
        EBox::Sudo::root("rm -rf '$path'");
    }
}

#   Method: deleteClient
#
#      deletes a client
#
#   Parameters:
#         name - client's name
sub deleteClient
{
    my ($self, $name) = @_;
    my $clients = $self->model('Clients');

    my $id = $clients->findId(name => $name);

    if (not defined $id) {
        throw EBox::Exceptions::External(__x(
                                             'Client {c} does not exist',
                                             c => $name
                                            )
                                        );
    }

    $clients->removeRow($id, 1);
}

# Method: menu
#
#       Overrides <EBox::Module::menu> method.
#
sub menu
{
    my ($self, $root) = @_;

    my $folder = new EBox::Menu::Folder(
                                        'icon' => 'openvpn',
                                        'name' => 'VPN',
                                        'text' => 'VPN',
                                        'order' => 425
                                       );

    $folder->add(
                 new EBox::Menu::Item(
                                      'url' => 'VPN/Servers',
                                      'text' => __('Servers'),
                                      'order' => 10
                                     )
    );
    $folder->add(
                 new EBox::Menu::Item(
                                      'url' => 'VPN/Clients',
                                      'text' => __('Clients'),
                                      'order' => 20
                                     )
    );

    $root->add($folder);
}

sub refreshIfaceInfoCache
{
    my ($self) = @_;
    my $webAdmin = EBox::Global->getInstance()->modInstance('webadmin');
    $webAdmin->setAsChanged(1);
}

sub openVPNWidget
{
    my ($self, $widget, $ovpn) = @_;
    my $section = new EBox::Dashboard::Section($ovpn);
    $widget->add($section);

    my $titles = [__('Common name'),__('Address'), __('Connected since')];
    my $rows = {};

    my $path = $self->logDir() . '/' . 'status-' . $ovpn . '.log';

    if (-f $path) {
        my @status = read_file($path);
        my $state = 0;

        for my $line (@status) {
            chomp($line);
            if($state == 0) {
                if($line =~m/^Common Name,/) {
                    $state = 1;
                }
            } elsif($state == 1) {
                my @fields = split(',', $line);
                if(@fields != 5) {
                    last;
                }
                my ($cname,$address,$recv,$sent,$date) = @fields;
                $rows->{$cname} = [$cname,$address,$date];
            }
        }
    }
    my $ids = [sort keys %{$rows}];
    $section->add(new EBox::Dashboard::List(undef, $titles, $ids, $rows,
        __('No users connected to the VPN')));
}

sub openVPNDaemonsWidget
{
    my ($self, $widget) = @_;

    my @daemons = $self->daemons();

    if ( @daemons == 0 ) {
        return;
    }

    foreach my $daemon (@daemons) {
        my @daemonSummary = $daemon->summary();
        @daemonSummary or next;

        my $name = shift @daemonSummary;
        my $section = new EBox::Dashboard::Section($daemon->name(),$name);

        while (@daemonSummary) {
            my ($valueName, $valueData) = splice(@daemonSummary, 0, 2);
            $section->add(new EBox::Dashboard::Value ($valueName, $valueData));
        }
        $widget->add($section);
    }
}

# Method: widgets
#
# Overrides:
#
#      <EBox::Module::widgets>
#
sub widgets
{
    my ($self) = @_;

    my $widgets = {
        'openvpndaemons' => {
            'title' => __('OpenVPN daemons'),
            'widget' => \&openVPNDaemonsWidget,
            'order' => 13,
            'default' => 1
        }
    };

    my @servers = $self->servers();
    foreach my $ovpn (@servers) {
        unless ( $ovpn->internal() ) {
            my $widget = {
                'title' => $ovpn->name(),
                'widget' => \&openVPNWidget,
                'parameter' => $ovpn->name(),
               };
            $widgets->{'vpn' . $ovpn->name()} = $widget;
        }
    }
    return $widgets;
}

sub _backupClientCertificatesDir
{
    my ($self, $dir) = @_;
    return $dir .'/clientCertificates';
}

sub dumpConfig
{
    my ($self, $dir) = @_;

    my $backupServersDir = "$dir/servers";
    EBox::FileSystem::makePrivateDir($backupServersDir);
    foreach my $server ($self->servers()) {
        $server->backupFiles($backupServersDir);
    }

    # save client's certificates
    my $certificatesDir = $self->_backupClientCertificatesDir($dir);
    EBox::FileSystem::makePrivateDir($certificatesDir);
    foreach my $client ($self->clients) {
        $client->backupCertificates($certificatesDir);
    }
}

sub restoreConfig
{
    my ($self, $dir, %extraParams) = @_;

    my $backupServersDir = "$dir/servers";
    foreach my $server ($self->servers()) {
        $server->restoreFiles($backupServersDir);
    }

    # restore client certificates
    my $certificatesDir = $self->_backupClientCertificatesDir($dir);
    my @clients = $self->clients();
    foreach my $client (@clients) {
        $client->restoreCertificates($certificatesDir);
    }
}

# log observer stuff

sub logHelper
{
    my ($self, @params) = @_;
    return EBox::OpenVPN::LogHelper->new($self, @params);
}

sub tableInfo
{
    my ($self) = @_;
    my $titles = {
                  timestamp => __('Date'),
                  event    => __('Event'),
                  daemon_name => ('Daemon'),
                  daemon_type => __('Type'),
                  from_ip     => __(q{Remote IP}),
                  from_cert     => __(q{Remote Certificate}),
                 };
    my @order = qw(timestamp event daemon_name daemon_type from_ip from_cert );

    my $events = {
                  initialized => __('Initialization sequence completed'),

                  verificationIssuerError => __('Certificate issuer not authorized'),
                  verificationNameError  => __('Certificate common name not authorized'),
                  verificationError => __('Certificate verification failed'),

                  connectionInitiated => __('Client connection initiated'),
                  connectionReset     => __('Client connection terminated'),

                  serverConnectionInitiated => __('Connection to server initiated'),
                  connectionResetByServer => __('Server connection terminated'),
                 };

    return [{
            'name' => $self->printableName(),
            'tablename' => 'openvpn',
            'titles' => $titles,
            'order' => \@order,
            'timecol' => 'timestamp',
            'filter' => ['daemon_name', 'from_ip', 'from_cert'],
            'types' => { 'from_ip' => 'IPAddr' },
            'events' => $events,
            'eventcol' => 'event'
           }];
}

sub _insecureRipPasswd
{
    my $insecure = EBox::Config::configkey('insecure_rip_conf');
    unless (defined($insecure)) {
        return undef;
    }
    if ($insecure eq 'no') {
        return 0;
    } elsif ($insecure eq 'yes') {
        return 1;
    } else {
        thore EBox::Exceptions::External(
                             __('You must set insecure_rip_conf to yes or no'));
    }
}

# Method: notifyLogChange
#
#   this is used to notify the log module of changes which will affect the logs
sub notifyLogChange
{
    my ($self) = @_;

    my $logs = EBox::Global->modInstance('logs');
    defined $logs or return;

    $logs->setAsChanged();
}

1;
