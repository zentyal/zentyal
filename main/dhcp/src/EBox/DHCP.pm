# Copyright (C) 2008-2013 Zentyal S.L.
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

package EBox::DHCP;

use base qw( EBox::Module::Service
             EBox::NetworkObserver
             EBox::LogObserver );

use EBox::Config;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::Internal;
use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::External;
use EBox::Exceptions::MissingArgument;
use EBox::Gettext;
use EBox::Global;
use EBox::Menu::Item;
use EBox::Menu::Folder;
use EBox::Validate qw(:all);

use EBox::Sudo;
use EBox::NetWrappers qw(:all);
use EBox::Service;
use EBox::DHCPLogHelper;

use EBox::Dashboard::Section;
use EBox::Dashboard::List;

use Net::IP;
use TryCatch;
use Perl6::Junction qw(any);
use Text::DHCPLeases;
use File::Slurp;
use File::Temp qw(tempfile);

# Module local conf stuff
# FIXME: extract this from somewhere to support multi-distro?
use constant DHCPCONFFILE => "/etc/dhcp/dhcpd.conf";
use constant LEASEFILE => "/var/lib/dhcp/dhcpd.leases";
use constant TFTPD_DEFAULT_CONF => "/etc/default/tftpd-hpa";
use constant PIDFILE => "/var/run/dhcp-server/dhcpd.pid";
use constant DHCP_SERVICE => "isc-dhcp-server";

use constant TFTP_SERVICE => "tftpd-hpa";

use constant CONF_DIR => EBox::Config::conf() . 'dhcp/';
use constant KEYS_DIR => '/etc/dhcp/ddns-keys';
use constant KEYS_FILE => KEYS_DIR . '/keys';
use constant SAMBA_KEY_DIR => '/etc/dhcp/samba-keys';
use constant PLUGIN_CONF_SUBDIR => 'plugins/';
use constant TFTPD_CONF_DIR => '/var/lib/tftpboot/';
use constant INCLUDE_DIR => EBox::Config::etc() . 'dhcp/';
use constant APPARMOR_DHCPD => '/etc/apparmor.d/local/usr.sbin.dhcpd';

# Group: Public and protected methods

# Constructor: _create
#
#    Create the zentyal-dhcp module
#
# Overrides:
#
#    <EBox::Module::Service::_create>
#
sub _create
{
    my $class = shift;
    my $self  = $class->SUPER::_create(name => 'dhcp',
                                       printableName => 'DHCP',
                                       @_);
    bless ($self, $class);

    return $self;
}

# Method: usedFiles
#
#   Override EBox::Module::Service::usedFiles
#
sub usedFiles
{
    return [
            {
             'file' => DHCPCONFFILE,
             'module' => 'dhcp',
             'reason' => __x('{server} configuration file', server => 'dhcpd'),
            },
            {
             'file'   => APPARMOR_DHCPD,
             'module' => 'dhcp',
             'reason' => __x('AppArmor profile for {server} daemon', server => 'dhcpd'),
            },
           ];
}

# Method: initialSetup
#
# Overrides:
#   EBox::Module::Base::initialSetup
#
sub initialSetup
{
    my ($self, $version) = @_;

    # Create default services, rules and conf dir
    # only if installing the first time
    unless ($version) {
        my $network = $self->global()->modInstance('network');
        my $firewall = $self->global()->modInstance('firewall');

        my $serviceName = 'tftp';
        unless ($network->serviceExists(name => $serviceName)) {
            $network->addMultipleService(
                'name' => $serviceName,
                'printableName' => 'TFTP',
                'description' => __('Trivial File Transfer Protocol'),
                'readOnly' => 1,
                'services' => [ { protocol => 'udp',
                                  sourcePort => 'any',
                                  destinationPort => 69 } ] );

            $firewall->setInternalService($serviceName, 'accept');
        }

        $serviceName = 'dhcp';
        unless ($network->serviceExists(name => $serviceName)) {
            $network->addMultipleService(
                'name' => $serviceName,
                'printableName' => 'DHCP',
                'description' => __('Dynamic Host Configuration Protocol'),
                'readOnly' => 1,
                'services' => [ { protocol => 'udp',
                                  sourcePort => '67:68',
                                  destinationPort => '67:68' } ] );

            $firewall->setInternalService($serviceName, 'accept');
        }

        $firewall->saveConfigRecursive();

        mkdir (CONF_DIR, 0755);
        EBox::debug("Creating directory for dynamic DNS keys");
        my @cmds;
        push (@cmds, 'mkdir -p ' . KEYS_DIR);
        push (@cmds, 'chown root:dhcpd ' . KEYS_DIR);
        push (@cmds, 'chmod 0750 ' . KEYS_DIR);
        EBox::Sudo::root(@cmds);
    }
}

# Method: appArmorProfiles
#
#   Overrides to set the own AppArmor profile to allow Dynamic DNS to
#   work and LSTP configuration using /etc/zentyal/dhcp/...
#
# Overrides:
#
#    <EBox::Module::Base::appArmorProfiles>
#
sub appArmorProfiles
{
    my ($self) = @_;

    my @params = ('confDir' => $self->IncludeDir());

    return [
        { 'binary' => 'usr.sbin.dhcpd',
          'local'  => 1,
          'file'   => 'dhcp/apparmor-dhcpd.local.mas',
          'params' => \@params }
       ];
}

# Method: actions
#
#   Override EBox::Module::Service::actions
#
sub actions
{
    return [
        {
            'action' => __x('Disable {server} init script', server => 'dhcpd'),
            'reason' => __('Zentyal will take care of start and stop ' .
                'the service'),
            'module' => 'dhcp',
        }
    ];
}

# Method: _daemons
#
# Overrides:
#
#   <EBox::Module::Service::_daemons>
#
sub _daemons
{
    my ($self) = @_;

    my $preSub = sub { return $self->_dhcpDaemonNeeded() };

    return [
        {
            'name' => DHCP_SERVICE,
            'precondition' => $preSub
        },
        {
            'name' => TFTP_SERVICE,
            'precondition' => $preSub
        }
    ];
}

sub _dhcpDaemonNeeded
{
    my ($self) = @_;
    my $daemonNeeded = $self->model('Interfaces')->daemonNeeded();
    return $daemonNeeded->{addresses};
}

# Method: _setConf
#
#      Writes the configuration files
#
# Overrides:
#
#      <EBox::Module::Base::_setConf>
#
sub _setConf
{
    my ($self) = @_;
    $self->_setDHCPConf();
    $self->_setTFTPDConf();
}

# Method: menu
#
# Overrides:
#
#     <EBox::Module::menu>
#
#
sub menu
{
    my ($self, $root) = @_;
    $root->add(new EBox::Menu::Item('url' => 'DHCP/View/Interfaces',
                                    'icon' => 'dhcp',
                                    'text' => $self->printableName(),
                                    'tag' => 'main',
                                    'order' => 6));
}

# Method: depends
#
#     DHCP depends on DNS configuration only if the Dynamic DNS
#     feature is done.
#
# Overrides:
#
#     <EBox::Module::Base::depends>
#
sub depends
{
    my ($self) = @_;

    my $dependsList = $self->SUPER::depends();
    if ($self->_dynamicDNSEnabled()) {
        push (@{$dependsList}, 'dns');
    }

    return $dependsList;
}

# DEPRECATED
sub initRange # (interface)
{
    my ($self, $iface) = @_;

    my $net = $self->global()->modInstance('network');

    return $net->netInitRange($iface);
}

# DEPRECATED
sub endRange # (interface)
{
    my ($self, $iface) = @_;

    my $net = $self->global()->modInstance('network');

    return $net->netEndRange($iface);
}

# Method: defaultGateway
#
#   Get the default gateway that will be sent to DHCP clients for a
#   given interface
#
# Parameters:
#
#       iface - interface name
#
# Returns:
#
#       string - the default gateway in a IP address form
#
# Exceptions:
#
#       <EBox::Exceptions::External> - thrown if the interface is not
#       static or the given type is none of the suggested ones
#
#       <EBox::Exceptions::DataNotFound> - thrown if the interface is
#       not found
#
sub defaultGateway # (iface)
{
    my ($self, $iface) = @_;

    my $network = $self->global()->modInstance('network');

    #if iface doesn't exists throw exception
    if (not $iface or not $network->ifaceExists($iface)) {
        throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                value => $iface);
    }

    #if iface is not static, throw exception
    if($network->ifaceMethod($iface) ne 'static') {
        throw EBox::Exceptions::External(__x("{iface} is not static",
            iface => $iface));
    }

    return $self->_getModel('Options', $iface)->defaultGateway();
}

# Method: searchDomain
#
#   Get the search domain that will be sent to DHCP clients for a
#   given interface
#
# Parameters:
#
#       iface - String interface name
#
# Returns:
#
#   String - the search domain
#
#       undef  - if the none search domain has been set
#
sub searchDomain # (iface)
{
    my ($self, $iface) = @_;

    my $network = $self->global()->modInstance('network');

    #if iface doesn't exists throw exception
    if (not $iface or not $network->ifaceExists($iface)) {
        throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                value => $iface);
    }

    #if iface is not static, throw exception
    if($network->ifaceMethod($iface) ne 'static') {
        throw EBox::Exceptions::External(__x("{iface} is not static",
            iface => $iface));
    }

#   $self->get_string("$iface/search");
    return $self->_getModel('Options', $iface)->searchDomain();
}

# Method: nameserver
#
#   Get the nameserver that will be sent to DHCP clients for a
#   given interface
#
# Parameters:
#
#       iface - String interface name
#       number - Int nameserver number (1 or 2)
#
#   Returns:
#
#       string - the nameserver or undef if there is no
#
# Exceptions:
#
#       <EBox::Exceptions::External> - thrown if the interface is not
#       static or the given type is none of the suggested ones
#
#       <EBox::Exceptions::DataNotFound> - thrown if the interface is
#       not found
#
#       <EBox::Exceptions::MissingArgument> - thrown if any compulsory
#       argument is missing
#
sub nameserver # (iface,number)
{
    my ($self, $iface, $number) = @_;

    if ( not defined ( $number )) {
        throw EBox::Exceptions::MissingArgument('number');
    }
    my $network = $self->global()->modInstance('network');

    #if iface doesn't exists throw exception
    if (not $iface or not $network->ifaceExists($iface)) {
        throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                value => $iface);
    }

    #if iface is not static, throw exception
    if($network->ifaceMethod($iface) ne 'static') {
        throw EBox::Exceptions::External(__x("{iface} is not static",
            iface => $iface));
    }

#   $self->get_string("$iface/nameserver$number");
    return $self->_getModel('Options', $iface)->nameserver($number);
}

# Method: ntpServer
#
#       Get the NTP server that will be sent to DHCP clients for a
#       given interface
#
# Parameters:
#
#       iface - String the interface name
#
# Returns:
#
#       String - the IP address for the NTP server, undef if no
#                NTP server has been configured
#
# Exceptions:
#
#       <EBox::Exceptions::External> - thrown if the interface is not
#       static or the given type is none of the suggested ones
#
#       <EBox::Exceptions::DataNotFound> - thrown if the interface is
#       not found
#
#       <EBox::Exceptions::MissingArgument> - thrown if any compulsory
#       argument is missing
#
sub ntpServer # (iface)
{
    my ($self, $iface) = @_;

    my $network = $self->global()->modInstance('network');
    #if iface doesn't exists throw exception
    if (not $iface or not $network->ifaceExists($iface)) {
        throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                                             value => $iface);
    }

    #if iface is not static, throw exception
    if($network->ifaceMethod($iface) ne 'static') {
        throw EBox::Exceptions::External(__x("{iface} is not static",
                                             iface => $iface));
    }

    return $self->_getModel('Options', $iface)->ntpServer();
}

# Method: winsServer
#
#       Get the WINS server that will be sent to DHCP clients for a
#       given interface
#
# Parameters:
#
#       iface - String the interface name
#
# Returns:
#
#       String - the IP address for the WINS server, undef if no
#                WINS server has been configured
#
# Exceptions:
#
#       <EBox::Exceptions::External> - thrown if the interface is not
#       static or the given type is none of the suggested ones
#
#       <EBox::Exceptions::DataNotFound> - thrown if the interface is
#       not found
#
#       <EBox::Exceptions::MissingArgument> - thrown if any compulsory
#       argument is missing
#
sub winsServer # (iface)
{
    my ($self, $iface) = @_;

    my $network = $self->global()->modInstance('network');
    #if iface doesn't exists throw exception
    if (not $iface or not $network->ifaceExists($iface)) {
        throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                                             value => $iface);
    }

    #if iface is not static, throw exception
    if($network->ifaceMethod($iface) ne 'static') {
        throw EBox::Exceptions::External(__x("{iface} is not static",
                                             iface => $iface));
    }

    return $self->_getModel('Options', $iface)->winsServer();
}

# Method: staticRoutes
#
#   Get the static routes. It polls the Zentyal modules which
#   implements <EBox::DHCP::StaticRouteProvider>
#
# Returns:
#
#   hash ref - contating the static toutes in hash references. The
#   key is the subnet in CIDR notation that denotes where is
#   appliable the new route.  The values are hash reference with
#   the keys 'destination', 'netmask' and 'gw'
#
sub staticRoutes
{
    my ($self) = @_;
    my %staticRoutes = ();

    my @modules = @{ $self->global()->modInstancesOfType('EBox::DHCP::StaticRouteProvider') };
    foreach  my $mod (@modules) {
        my @modStaticRoutes = @{ $mod->staticRoutes() };
        while (@modStaticRoutes) {
            my $net   = shift @modStaticRoutes;
            my $route = shift @modStaticRoutes;
            if (exists $staticRoutes{$net}) {
                push  @{$staticRoutes{$net}}, $route;
            }
            else {
                $staticRoutes{$net} = [$route];
            }
        }
    }

    return \%staticRoutes;
}

sub notifyStaticRoutesChange
{
    my ($self) = @_;
    $self->setAsChanged();
}

# Method: rangeAction
#
#   Set/add a range for a given interface
#
# Parameters:
#
#   iface - String Interface name
#       action - String to perform (add/set/del)
#
#       indexValue - String index to use to set a new value, it can be a
#       name, a from IP addr or a to IP addr.
#
#       indexField - String the field name to use as index
#
#   name - String the range name
#   from - String start of range, an ip address
#   to - String end of range, an ip address
#
#       - Named parameters
#
# Exceptions:
#
#    <EBox::Exceptions::DataNotFound> - Interface does not exist
#    <EBox::Exceptions::External> - interface is not static
#    <EBox::Exceptions::External - invalid range
#    <EBox::Exceptions::External - range overlap
#
sub rangeAction # (iface, name, from, to)
{
    my ($self, %args) = @_;

    my $iface = delete ($args{iface});
    my $action = delete ($args{action});
    unless ( $action eq any(qw(add set del))) {
        throw EBox::Exceptions::External(__('Not a valid action: add, set and del '
                    . 'are available'));
    }

    my $network = $self->global()->modInstance('network');

    #if iface doesn't exists throw exception
    if (not $iface or not $network->ifaceExists($iface)) {
        throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                value => $iface);
    }

    #if iface is not static, throw exception
    if($network->ifaceMethod($iface) ne 'static') {
        throw EBox::Exceptions::External(__x("{iface} is not static",
                    iface => $iface));
    }

    my $rangeModel = $self->_getModel('RangeTable', $iface);
    if ( $action eq 'add' ) {
        $rangeModel->add( name => $args{name},
                from => $args{from},
                to   => $args{to});
    } elsif ( $action eq 'set' ) {
        my $index = delete ( $args{indexValue} );
        my $indexField = delete ( $args{indexField} );
        my @args = map { $_ => $args{$_} } keys (%args);
        $rangeModel->setIndexField($indexField);
        $rangeModel->set( $index, @args );
    } elsif ( $action eq 'del' ) {
        my $index = delete ( $args{indexValue} );
        my $indexField = delete ( $args{indexField} );
        $rangeModel->setIndexField($indexField);
        $rangeModel->del( $index );
    }
}

# Method: ranges
#
#   Return all the set ranges for a given interface
#
# Parameters:
#
#   iface - String interface name
#
# Returns:
#
#   array ref - contating the ranges in hash references. Each hash holds
#   the keys 'name', 'from' and 'to'
#
# Exceptions:
#
#       <EBox::Exceptions::DataNotFound> - Interface does not exist
#
sub ranges # (iface)
{
    my ($self, $iface) = @_;

    my $network = $self->global()->modInstance('network');

    if (not $iface or not $network->ifaceExists($iface)) {
        throw EBox::Exceptions::DataNotFound('data' => __('Interface'),
                                             'value' => $iface);
    }

    my $model = $self->_getModel('RangeTable', $iface);
    my @ranges;
    for my $id (@{$model->ids()}) {
        my $row = $model->row($id);
        push (@ranges,
              { name    => $row->valueByName('name'),
                from    => $row->valueByName('from'),
                to      => $row->valueByName('to'),
                options => $self->_thinClientOptions($iface, $row->valueByName('name'))
               });
    }

    return \@ranges;
}

# Method: fixedAddresses
#
#   Return the list of fixed addreses
#
# Parameters:
#
#   iface - String interface name
#
#       readonly - Boolean indicate to get the information from
#                  readonly backend or current one
#                  *(Optional)* Default value: False
#
# Returns:
#
#   array ref - contating the fixed addresses in hash refereces.
#   Each hash holds the keys 'mac', 'ip' and 'name'
#
#       hash ref - if you set readOnly parameter, then it returns
#           two keys:
#              options - hash ref containing the PXE options

#              members - array ref containing the members of this
#                        objects as it does if readOnly is set to false
#
# Exceptions:
#
#   <EBox::Exceptions::DataNotFound> - Interface does not exist
#
#       <EBox::Exceptions::External> - Interface is not static
#
sub fixedAddresses
{
    my ($self, $iface, $readOnly) = @_;

    $readOnly = 0 unless ($readOnly);

    my $global  = EBox::Global->getInstance($readOnly);
    my $network = $global->modInstance('network');

    #if iface doesn't exists throw exception
    if (not $iface or not $network->ifaceExists($iface)) {
        throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                                             value => $iface);
    }

    #if iface is not static, throw exception
    if ($network->ifaceMethod($iface) ne 'static') {
        throw EBox::Exceptions::External(__x("{iface} is not static",
                                             iface => $iface));
    }

    my $ifaceModel = $self->model('Interfaces');
    my $ifaceRow = $ifaceModel->findRow(iface => $iface);
    my $ifaceConf = $ifaceRow->subModel('configuration');
    my $model = $ifaceConf->componentByName('FixedAddressTable');
    return $model->addresses($iface, $readOnly);
}

# Group: Static or class methods

# Method: ConfDir
#
#      Get the DHCP configuration directory where to store the user
#      defined configuration files
#
# Parameters:
#
#      iface - String the interface which the user configuration file
#      is within
#
# Returns:
#
#      String - the configuration path
#
sub ConfDir
{
    my ($class, $iface) = @_;

    # Create directory unless it already exists
    unless ( -d CONF_DIR . $iface ) {
        mkdir ( CONF_DIR . $iface, 0755 );
    }
    my $pluginDir = CONF_DIR . $iface . '/' . PLUGIN_CONF_SUBDIR;
    unless ( -d $pluginDir ) {
        mkdir ( $pluginDir, 0755 );
    }
    return CONF_DIR . "$iface/";
}

# Method: TftpdRootDir
#
#      Get the default Tftpd root directory to store the firmwares
#      uploaded by our users
#
# Returns:
#
#      String - the tftpd root directory path
#
sub TftpdRootDir
{
    my ($class) = @_;

    # Create directory unless it already exists
    unless ( -d TFTPD_CONF_DIR ) {
        mkdir ( TFTPD_CONF_DIR, 0755 );
    }
    return TFTPD_CONF_DIR;
}

# Method: PluginConfDir
#
#      Get the DHCP plugin configuration directory where to store the user
#      defined configuration files
#
# Parameters:
#
#      iface - String the interface which the user configuration file
#      is within
#
# Returns:
#
#      String - the configuration path
#
sub PluginConfDir
{
    my ($class, $iface) = @_;

    my $pluginDir = $class->PluginConfDirPath($iface);
    unless ( -d $pluginDir ) {
        mkdir ( $pluginDir, 0755 );
    }
    return $pluginDir;
}

sub PluginConfDirPath
{
    my ($class, $iface) = @_;
    return CONF_DIR . $iface . '/' . PLUGIN_CONF_SUBDIR;
}

# Method:  userConfDir
#
#  Returns:
#  path to the user configuration dir
sub userConfDir
{
  return CONF_DIR;
}

# Method: IncludeDir
#
#    Path to the directory to include custom configuration
#
# Returns:
#
#    String - the path to the directory
#
sub IncludeDir
{
    return INCLUDE_DIR;
}

# Group: Network observer implementations

# Method: ifaceMethodChanged
#
# Implements:
#
#    <EBox::NetworkObserver::ifaceMethodChanged>
#
# Returns:
#
#     true - if the old method is 'static' and there are configured
#     ranges or fixed addresses attached to this interface
#     false - otherwise
#
sub ifaceMethodChanged # (iface, old_method, new_method)
{
    my ($self, $iface, $old_method, $new_method) = @_;

    if ($old_method eq 'static'
          and $new_method ne 'static') {
        my $rangeModel = $self->_getModel('RangeTable', $iface);
        if ( defined ( $rangeModel )) {
            return 1 if ( $rangeModel->size() > 0);
        }
        my $fixedAddrModel = $self->_getModel('FixedAddressTable', $iface);
        if ( defined ( $fixedAddrModel )) {
            return 1 if ( $fixedAddrModel->size() > 0);
        }
    }

    return 0;
}

# Method: staticIfaceAddressChanged
#
#       Return true *unless*:
#
#       - all ranges are still in the network
#       - new IP is not in any range
#       - all fixed addresses are still in the network
#       - new IP is not any fixed IP address
#
# Implements:
#
#       <EBox::NetworkObserver::staticIfaceAddressChanged>
#
sub staticIfaceAddressChanged # (iface, old_addr, old_mask, new_addr, new_mask)
{
    my ( $self, $iface, $old_addr, $old_mask, $new_addr, $new_mask) = @_;
#   my $nr = @{$self->ranges($iface)};
#   my $nf = @{$self->fixedAddresses($iface)};
#   if(($nr == 0) and ($nf == 0)){
#       return 0;
#   }

    my $ip = new Net::IP($new_addr);

    my $network = ip_network($new_addr, $new_mask);
    my $bits = bits_from_mask($new_mask);
    my $netIP = new Net::IP("$network/$bits");

    # Check ranges
    my $rangeModel = $self->_getModel('RangeTable', $iface);
    foreach my $id (@{$rangeModel->ids()}) {
        my $rangeRow = $rangeModel->row($id);
        my $range = new Net::IP($rangeRow->valueByName('from')
                                    . ' - ' .
                                $rangeRow->valueByName('to'));
        # Check the range is still in the network
        unless ($range->overlaps($netIP) == $IP_A_IN_B_OVERLAP){
            return 1;
        }
        # Check the new IP isn't in any range
        unless($ip->overlaps($range) == $IP_NO_OVERLAP ){
            return 1;
        }
    }

    my $fixedAddrs = $self->fixedAddresses($iface, 0);
    foreach my $fixedAddr (@{$fixedAddrs}) {
        my $fixedIP = new Net::IP( $fixedAddr->{'ip'} );
        # Check the fixed address is still in the network
        unless($fixedIP->overlaps($netIP) == $IP_A_IN_B_OVERLAP){
            return 1;
        }
        # Check the new IP isn't in any fixed address
        unless( $ip->overlaps($fixedIP) == $IP_NO_OVERLAP){
            return 1;
        }
    }

    return 0;
}

# Function: freeIface
#
#    Delete every single row from the models attached to this
#    interface
#
# Implements:
#
#    <EBox::NetworkObserver::freeIface>
#
#
sub freeIface #( self, iface )
{
    my ( $self, $iface ) = @_;
#   $self->delete_dir("$iface");
    $self->_removeDataModelsAttached($iface);

    my $net = $self->global()->modInstance('network');
    if ($net->ifaceMethod($iface) eq 'static') {
        $self->_checkStaticIfaces(-1);
    }
}

# Group: Private methods

# Impelment LogHelper interface
sub tableInfo
{
    my ($self) = @_;

    my $titles = { 'timestamp' => __('Date'),
        'interface' => __('Interface'),
        'mac' => __('MAC address'),
        'ip' => __('IP'),
        'event' => __('Event')
    };
    my @order = ('timestamp', 'ip', 'mac', 'interface', 'event');
    my $events = {'leased' => __('Leased'), 'released' => __('Released') };

    return [{
        'name' => __('DHCP'),
        'tablename' => 'leases',
        'titles' => $titles,
        'order' => \@order,
        'timecol' => 'timestamp',
        'filter' => ['interface', 'mac', 'ip'],
        'types' => { 'ip' => 'IPAddr', 'mac' => 'MACAddr' },
        'events' => $events,
        'eventcol' => 'event',
    }];
}

sub logHelper
{
    my $self = shift;

    return (new EBox::DHCPLogHelper);
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

sub _dhcpLeases
{
    my ($self) = @_;

    my @stats = stat LEASEFILE;
    @stats or
           return {};
    my $mtime = $stats[9];
    my $refresh = 0;
    if (defined $self->{leases} and (defined $self->{leasesMTime})) {
        $refresh = $mtime ne $self->{leasesMTime};
    } else {
        $refresh = 1;
    }

    if ($refresh) {
        $self->{'leases'} = {};

        my $leases;
        # Workaround to avoid statement not recognized parse errors
        my @lines = read_file(LEASEFILE);
        @lines = grep { not /set ddns-/ } @lines;
        my ($fh, $tmpfile) = tempfile(DIR => EBox::Config::tmp);
        print $fh @lines;
        close ($fh);
        try {
            local $SIG{__WARN__};
            $leases = Text::DHCPLeases->new(file => $tmpfile);
        } catch ($e) {
           EBox::error('Error parsing DHCP leases file (' . LEASEFILE . "): $e");
        }
        unlink ($tmpfile);

        if (not $leases) {
            return $self->{'leases'};
        }

        foreach my $lease ($leases->get_objects()) {
            my $id = _leaseIDFromIP($lease->ip_address());
            $self->{'leases'}->{$id} = $lease;
        }
        $self->{leasesMTime} = $mtime;
    }
    return $self->{'leases'};
}

sub _leaseFromIP
{
    my ($self, $ip) = @_;

    my $leases = $self->_dhcpLeases();
    my $id = _leaseIDFromIP($ip);
    return $leases->{$id};
}

sub dhcpLeasesWidget
{
    my ($self, $widget) = @_;
    my $section = new EBox::Dashboard::Section('dhcpleases');
    $widget->add($section);
    my $titles = [__('IP address'),__('MAC address'), __('Host name')];

    my $leases = $self->_dhcpLeases();

    my $ids = [];
    my $rows = {};
    foreach my $id (sort keys (%{$leases})) {
        my $lease = $leases->{$id};
        if($lease->binding_state() eq 'active') {
            my $hostname = $lease->client_hostname();
            if ($hostname) {
                $hostname =~ s/"//g;
            } else {
                $hostname = __('Unknown');
            }

            push(@{$ids}, $id);
            $rows->{$id} = [$lease->ip_address(),$lease->mac_address(),
                            $hostname];
        }
    }

    $section->add(new EBox::Dashboard::List(undef, $titles, $ids, $rows));
}

# Method: widgets
#
#   Overrides <EBox::Module::Base::widgets>
#
sub widgets
{
    return {
        'dhcpleases' => {
            'title' => __("DHCP leases"),
            'widget' => \&dhcpLeasesWidget,
            'order' => 5,
            'default' => 1
        }
    };
}

# Group: Private methods

# Method: _setDHCPConf
#
#     Updates the dhcpd.conf file
#
sub _setDHCPConf
{
    my ($self) = @_;

    # Write general configuration
    my $net = $self->global()->modInstance('network');
    my $staticRoutes_r =  $self->staticRoutes();

    my $ifacesInfo = $self->_ifacesInfo($staticRoutes_r);
    my @params = ();
    push @params, ('dnsone' => $net->nameserverOne());
    push @params, ('dnstwo' => $net->nameserverTwo());
    push @params, ('thinClientOption' =>
                   $self->_areThereThinClientOptions($ifacesInfo));
    push @params, ('ifaces' => $ifacesInfo);
    push @params, ('real_ifaces' => $self->_realIfaces());
    my $dynamicDNSEnabled = $self->_dynamicDNSEnabled($ifacesInfo);
    if ($dynamicDNSEnabled) {
        push @params, ('dynamicDNSEnabled' => $dynamicDNSEnabled);
        push @params, ('keysFile' => KEYS_FILE);

        # Write keys file
        if (EBox::Global->modExists('dns')) {
            my $dns = EBox::Global->modInstance('dns');
            my $keys = $dns->getTsigKeys();
            $self->writeConfFile(KEYS_FILE, 'dns/keys.mas', [ keys => $keys ],
                {uid => 'root', 'gid' => 'dhcpd', mode => '640'});

            EBox::info("Checking by config of DDNS for dhcp dns and samba");
            if (EBox::Global->modExists('samba')){
                my $samba = EBox::Global->modInstance('samba');
                if ($samba->isEnabled()){
                    $self->_setDynDnsConf();
                    push (@params, ('dynDnsSamba' => 1));
                }
            }
        }
    }
    push(@params, ('pidFile' => PIDFILE));
    $self->writeConfFile(DHCPCONFFILE, "dhcp/dhcpd.conf.mas", \@params);

}

# Method: _createUserDhcpdUser
#
#   Creates the dhcpd user and adds it to the DsnAdmins group to be called by the script that updates dynamic dns.
#
sub _createUserDhcpdUser
{
    my ($self) = @_;
    my @cmds1;

    EBox::Sudo::silentRoot("samba-tool user list | grep ^dhcpduser");
    if ($? == 0) {
        EBox::info("Creating dhcpduser for dynamic dns DON'T NEED, ignore step.");
    }else{
        my $samba = EBox::Global->modInstance('samba');

        if (defined $samba and $samba->isEnabled()){
            require EBox::Samba::User;
            my $ldapDN = $samba->ldap->dn();
            my $userDN = sprintf("CN=dhcpduser,CN=Users,%s",$ldapDN);
            EBox::info("Creating dhcpduser for dynamic dns");
            my $newUid = EBox::Samba::User->_newUserUidNumber(1);
            EBox::info("dhcpduser uid: $newUid");
            my $cmdFunction = sprintf ('samba-tool user create dhcpduser --uid-number %s --description="Unprivileged user for TSIG-GSSAPI DNS updates via ISC DHCP server" --random-password', $newUid);
            push (@cmds1, $cmdFunction);
            push (@cmds1, 'samba-tool user setexpiry dhcpduser --noexpiry');
            EBox::Sudo::root(@cmds1);
            EBox::Sudo::silentRoot('samba-tool group addmembers DnsAdmins dhcpduser');
            my $user = EBox::Samba::User->new(dn => $userDN);
            $user->setCritical(1);

            return 1;
        }
    }

    return 0;
}

# Method: _setDynDnsConf
#
#   Generate user and keys for dhcpduser
#
sub _setDynDnsConf
{
    my ($self) = @_;
    my @cmds;

    # Get the host domain
    if($self->_createUserDhcpdUser()) {
        my $sysinfo = EBox::Global->modInstance('sysinfo');
        my $ownDomain = $sysinfo->hostDomain();
        my $cmd = sprintf('samba-tool domain exportkeytab --principal=dhcpduser@%s %s/dhcpduser.keytab', $ownDomain, SAMBA_KEY_DIR);

        push(@cmds, 'mkdir -p ' . SAMBA_KEY_DIR);
        push(@cmds, 'chown root:dhcpd ' . SAMBA_KEY_DIR);
        push(@cmds, 'chmod 0750 ' . SAMBA_KEY_DIR);
        push(@cmds, $cmd);
        push(@cmds, 'chown root:dhcpd ' . SAMBA_KEY_DIR . '/dhcpduser.keytab');
        push(@cmds, 'chmod 440 ' . SAMBA_KEY_DIR . '/dhcpduser.keytab');
        EBox::Sudo::root(@cmds);
    }
}


# Method: _setTFTPDConf
#
#     Set the proper default file for TFTP daemon
#
sub _setTFTPDConf
{
    my ($self) = @_;

    $self->writeConfFile(TFTPD_DEFAULT_CONF, "dhcp/tftpd-hpa.mas", []);
}

# Method: _ifacesInfo
#
#      Return a well structure to configure dhcp3-server using the
#      data installed in the module as well as the static routes
#      provided by <EBox::DHCP::StaticRouteProvider> modules
#
# Parameters:
#
#      staticRouters - hash ref containing those static routes to add
#      to a network which acts as key and the routes as value.
#
# Returns:
#
#      hash ref - an structure storing the required information for
#      dhcpd configuration
#
sub _ifacesInfo
{
    my ($self, $staticRoutes_r) = @_;

    my $roGlobal = EBox::Global->getInstance('readonly');
    my $net = $roGlobal->modInstance('network');
    my $ifaces = $net->ifaces();

    my %iflist;
    foreach my $iface (@{$ifaces}) {
        if ($net->ifaceMethod($iface) eq 'static') {
            my $address = $net->ifaceAddress($iface);
            my $netmask = $net->ifaceNetmask($iface);
            my $network = ip_network($address, $netmask);

            $iflist{$iface}->{'net'} = $network;
            $iflist{$iface}->{'address'} = $address;
            $iflist{$iface}->{'netmask'} = $netmask;
            $iflist{$iface}->{'ranges'} = $self->ranges($iface);
            $iflist{$iface}->{'fixed'} = $self->fixedAddresses($iface, 'readonly');

            # look if we have static routes for this network
            my $netWithMask = EBox::NetWrappers::to_network_with_mask($network, $netmask);
            if (exists $staticRoutes_r->{$netWithMask}) {
                $iflist{$iface}->{'staticRoutes'} =
                    $staticRoutes_r->{$netWithMask};
            }

            my $gateway = $self->defaultGateway($iface);
            if (defined ($gateway)) {
                if ($gateway) {
                    $iflist{$iface}->{'gateway'} = $gateway;
                }
            } else {
                $iflist{$iface}->{'gateway'} = $address;
            }
            my $search = $self->searchDomain($iface);
            $iflist{$iface}->{'search'} = $search;
            my $nameserver1 = $self->nameserver($iface,1);
            if (defined($nameserver1) and $nameserver1 ne "") {
                $iflist{$iface}->{'nameserver1'} = $nameserver1;
            }
            my $nameserver2 = $self->nameserver($iface,2);
            if (defined($nameserver2) and $nameserver2 ne "") {
                $iflist{$iface}->{'nameserver2'} = $nameserver2;
            }
            # NTP option
            my $ntpServer = $self->ntpServer($iface);
            if ( defined($ntpServer) and $ntpServer ne "") {
                $iflist{$iface}->{'ntpServer'} = $ntpServer;
            }
            # WINS/Netbios server option
            my $winsServer = $self->winsServer($iface);
            if ( defined($winsServer) and $winsServer ne "") {
                $iflist{$iface}->{'winsServer'} = $winsServer;
            }
            # Leased times
            my $defaultLeasedTime = $self->_leasedTime('default', $iface);
            if (defined($defaultLeasedTime)) {
                $iflist{$iface}->{'defaultLeasedTime'} = $defaultLeasedTime;
            }
            my $maxLeasedTime = $self->_leasedTime('max', $iface);
            if (defined($maxLeasedTime)) {
                $iflist{$iface}->{'maxLeasedTime'} = $maxLeasedTime;
            }

            # Dynamic DNS options
            my $dynamicDomain = $self->_dynamicDNS('dynamic', $iface);
            if (defined($dynamicDomain)) {
                $iflist{$iface}->{'dynamicDomain'} = $dynamicDomain;
                $iflist{$iface}->{'staticDomain'}  = $self->_dynamicDNS('static', $iface);
                $iflist{$iface}->{'reverseZones'}  = $self->_reverseZones($iface);
            }
        }
    }

    return \%iflist;
}

# Method: _realIfaces
#
#    Get those interfaces which are real static ones containing the
#    virtual interfaces names which contain the real static interface
#
# Returns:
#
#    hash ref - containing interface name as key and an array ref
#    containing the virtual interface names as value
#
sub _realIfaces
{
    my ($self) = @_;
    my $net = $self->global()->modInstance('network');

    my $real_ifaces = $net->ifaces();
    my %realifs;
    foreach my $iface (@{$real_ifaces}) {
        if ($net->ifaceMethod($iface) eq 'static') {
            $realifs{$iface} = 1;
        }

    }

    return \%realifs;
}

# Method: _areThereThinClientOptions
#
#    Check if there are thin client options in order to allow DHCP
#    server acting as a boot server by setting these options on the
#    configuration file
#
# Parameters:
#
#    ifacesInfo - hash ref every static interface is the key and the
#    value contains every single parameter required to be written on
#    the configuration file
#
# Returns:
#
#    Boolean - true if there are thin client options in at least one
#    iface, false otherwise
#
sub _areThereThinClientOptions
{
    my ($self, $ifacesInfo) = @_;

    foreach my $ifaceInfo (values %{$ifacesInfo}) {
        foreach my $range (@{$ifaceInfo->{ranges}}) {
            if ( values %{$range->{options}} > 0 ) {
                return 1;
            }
        }
        foreach my $objFixed (values %{$ifaceInfo->{fixed}}) {
            if ( values %{$objFixed->{options}} > 0 ) {
                return 1;
            }
        }
    }

    foreach my $ifaceInfo (values %{$ifacesInfo}) {
        if ( values %{$ifaceInfo->{options}} > 0 ) {
            return 1;
        }
    }
    return 0;
}

# Method: _leasedTime
#
#    Get the leased time (default or maximum) in seconds if any
#
sub _leasedTime # (which, iface)
{
    my ($self, $which, $iface) = @_;

    my $advOptionsModel = $self->_getModel('LeaseTimes', $iface);

    my $fieldName = $which . '_leased_time';
    return $advOptionsModel->row()->valueByName($fieldName);
}

# Method: _thinClientOptions
#
#    Get the thin client options
#
sub _thinClientOptions # (iface, element)
{
    my ($self, $iface, $element) = @_;

    my $thinClientModel = $self->_getModel('ThinClientOptions', $iface);

    my $ret = {};
    my $row = $thinClientModel->row();
    if (defined ($row)) {
        $ret->{nextServer} = $thinClientModel->nextServer($iface);
        $ret->{filename} = $row->valueByName('remoteFilename');
        unless ($self->global()->communityEdition()) {
            $ret->{tftpServers} = $row->valueByName('option150');
            $ret->{shoretelServer} = $row->valueByName('option155');
        }
    }
    return $ret;
}

# Method: _dynamicDNS
#
#    Get the domains to be updated by DHCP server (dynamic or statics)
#
# Returns:
#
#    undef - if the dynamic DNS feature is not enabled
#
sub _dynamicDNS # (which, iface)
{
    my ($self, $which, $iface) = @_;

    return undef unless (EBox::Global->modExists('dns'));

    my $dynamicDNSModel = $self->_getModel('DynamicDNS', $iface);

    my $dynamicOptionsRow = $dynamicDNSModel->row();
    if ($dynamicOptionsRow->valueByName('enabled')) {
        if ($which eq 'dynamic') {
            return $dynamicOptionsRow->printableValueByName('dynamic_domain');
        } elsif ($which eq 'static') {
            my $staticOption = $dynamicOptionsRow->elementByName('static_domain');
            if ($staticOption->selectedType() eq 'same') {
                return $dynamicOptionsRow->printableValueByName('dynamic_domain');
            } elsif ($staticOption->selectedType() eq 'custom') {
                return $dynamicOptionsRow->printableValueByName('static_domain');
            }
        }
    }
    return undef;
}

# Return the reverse zones for the given interface
sub _reverseZones
{
    my ($self, $iface) = @_;

    my @ranges = @{ $self->ranges($iface) };

    my @revZones;
    foreach my $range (@ranges) {
        my $initRange = $range->{from};
        my $endRange  = $range->{to};
        my $ip = new Net::IP("$initRange - $endRange");
        do {
            my $rev = Net::IP->new($ip->ip())->reverse_ip();
            if ( defined($rev) ) {
                # It returns 100.55.168.192.netaddr.in-addr.arpa for
                # example so we need to remove the first group
                # to make it compilant with bind zone definition
                $rev =~ s/^[0-9]+\.//;
                push (@revZones, $rev);
            }
        } while ( $ip += 256 );
    }
    return \@revZones;
}

# Return if the dynamic DNS feature is enabled for this DHCP server or
# not given the iface list info
sub _dynamicDNSEnabled # (ifacesInfo)
{
    my ($self, $ifacesInfo) = @_;

    return 0 unless ( EBox::Global->modExists('dns') );

    if ( defined($ifacesInfo) ) {
        my $nDynamicOptionsOn = grep { defined($ifacesInfo->{$_}->{'dynamicDomain'}) } keys %{$ifacesInfo};
        return ($nDynamicOptionsOn > 0);
    } else {
        my $net = $self->global()->modInstance('network');
        my $ifaces = $net->ifaces();
        foreach my $iface (@{$ifaces}) {
            if ( $net->ifaceMethod($iface) eq 'static' ) {
                my $mod = $self->_getModel('DynamicDNS', $iface);
                if ( $mod->row()->valueByName('enabled') ) {
                    return 1;
                }
            }
        }
        return 0;
    }
}

# Returns those model instances attached to the given interface
sub _removeDataModelsAttached
{
    my ($self, $iface) = @_;
    my $ifacesModel = $self->model('Interfaces');
    my $rowId       = $ifacesModel->findId(iface => $iface);
    $ifacesModel->removeRow($rowId, 1);

#     # RangeTable/Options/FixedAddressTable
#     foreach my $modelName (qw(LeaseTimes ThinClientOptions Options RangeTable FixedAddressTable)) {
#         my $model = $self->_getModel($modelName, $iface);
#         if ( defined ( $model )) {
#             $model->removeAll(1);
#         }
#    }
}

# Model getter, check if there are any model with the given
# description, if not returns undef
sub _getModel
{
    my ($self, $modelName, $iface) = @_;
    my $row = $self->model('Interfaces')->findRow(iface => $iface);
    if (not $row) {
        throw EBox::Exceptions::Internal("Inexistent row for iface $iface")
    }

    my $configuration = $row->subModel('configuration');
    return $configuration->componentByName($modelName, 1);
}

sub _getAllModelInstances
{
    my ($self, $modelName) = @_;
    my @models;
    my $interfaces = $self->model('Interfaces');
    foreach my $id (@{ $interfaces->ids() }) {
        my $row = $interfaces->row($id);
        my $configuration = $row->subModel('configuration');
        my $model = $configuration->componentByName($modelName, 1);
        push @models, $model if $model;
    }

    return \@models;
}

# return the Dynamic DNS configutation row for the given iface
sub dynamicDNSDomains
{
    my ($self, $iface) = @_;
    my $ddModel= $self->_getModel('DynamicDNS', $iface);
    return $ddModel->row();
}

# Check there are enough static interfaces to have DHCP service enabled
sub _checkStaticIfaces
{
    my ($self, $adjustNumber) = @_;
    defined $adjustNumber or $adjustNumber = 0;

    my $nStaticIfaces = $self->_nStaticIfaces() + $adjustNumber;
    if ($nStaticIfaces == 0) {
        if ($self->isEnabled()) {
            $self->enableService(0);
            EBox::info('DHCP service was deactivated because there was not any static interface left');
        }
    }
}

# Return the current number of static interfaces
sub _nStaticIfaces
{
    my ($self) = @_;

    my $net = $self->global()->modInstance('network');
    my $ifaces = $net->ifaces();
    my $staticIfaces = grep  { $net->ifaceMethod($_) eq 'static' } @{$ifaces};

    return $staticIfaces;
}

# Method: gatewayDelete
#
#  Overrides:
#    EBox::NetworkObserver::gatewayDelete
sub gatewayDelete
{
    my ($self, $gwName) = @_;

    my $global = EBox::Global->getInstance($self->{ro});
    my $network = $global->modInstance('network');
    foreach my $iface (@{$network->ifaces()}) {
        next unless ($network->ifaceMethod($iface) eq 'static');
        my $options = $self->_getModel('Options', $iface);
        my $optionsGwName = $options->gatewayName();
        if (defined($optionsGwName) and ($gwName eq $optionsGwName)) {
            return 1;
        }
    }

    return 0;
}

sub dynamicDomainsIds
{
    my ($self) = @_;
    return $self->model('Interfaces')->dynamicDomainsIds();
}

1;
