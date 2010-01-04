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

# Class:
#
#

#
package EBox::OpenVPN::Model::Servers;
use base qw(EBox::Model::DataTable EBox::OpenVPN::Model::InterfaceTable);

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Exceptions::External;
use EBox::Exceptions::DataExists;

use EBox::Types::HasMany;
use EBox::Types::Text::WriteOnce;
use EBox::Types::Boolean;
use EBox::NetWrappers;

use EBox::OpenVPN::Server;

#use EBox::OpenVPN::Model::ServerConfiguration;
use List::Util; # first

use constant START_ADDRESS_PREFIX => '192.168.';
use constant FROM_RANGE => 160;
use constant TO_RANGE => 200;
use constant PORTS => (1194, 11194 .. 11234);


# Group: Public and protected methods

sub new
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

sub _table
{
    my @tableHead =
        (
            new EBox::Types::Boolean (
                                      fieldName => 'service',
                                      printableName => __('Enabled'),
                                      editable => 1,

                                      defaultValue => 1,
                                     ),
            new EBox::Types::Text::WriteOnce
                            (
                                'fieldName' => 'name',
                                'printableName' => __('Name'),
                                'size' => '20',
                                'unique' => 1,
                                'editable' => 1,
                             ),
            new EBox::Types::HasMany
                            (
                                'fieldName' => 'configuration',
                                'printableName' => __('Configuration'),
                                'foreignModel' => 'ServerConfiguration',
                                'view' => '/ebox/OpenVPN/View/ServerConfiguration',
                                'backView' => '/ebox/OpenVPN/View/Servers',
                                'size' => '1',
                             ),
            new EBox::Types::HasMany
                            (
                                'fieldName' => 'advertisedNetworks',
                                'printableName' => __('Advertised networks'),
                                'foreignModel' => 'ExposedNetworks',
                                'view' => '/ebox/OpenVPN/View/ExposedNetworks',
                                'backView' => '/ebox/OpenVPN/View/Servers',
                                'size' => '1',
                             ),
            new EBox::Types::HasMany
                            (
                                'fieldName' => 'download',
                                'printableName' => __('Download client bundle'),
                                'foreignModel' => 'DownloadClientBundle',
                                'view' => '/ebox/OpenVPN/View/DownloadClientBundle',
                                'backView' => '/ebox/OpenVPN/View/Servers',
                                'size' => '1',
                             ),
                             __PACKAGE__->interfaceFields(),
          );

    my $dataTable =
        {
            'tableName'              => __PACKAGE__->name(),
            'printableTableName' => __('List of servers'),
            'pageTitle' => __('VPN servers'),
            'HTTPUrlView' => 'OpenVPN/View/Servers',
            'automaticRemove' => 1,
            'defaultController' => '/ebox/OpenVPN/Controller/Servers',
            'defaultActions' => ['add', 'del', 'editField',  'changeView' ],
            'tableDescription' => \@tableHead,
            'class' => 'dataTable',
            'printableRowName' => __('server'),
            'sortedBy' => 'name',
            'help' => _help(),
            'modelDomain' => 'OpenVPN',
        };

    return $dataTable;
}


sub name
{
    __PACKAGE__->nameFromClass(),
}

# Method: precondition
#
#   Overrides  <EBox::Model::DataTable::precondition>
#   to check if the CA is created otherwise this model can't be used
#
# Returns:
#
#       Boolean - true if the precondition is accomplished, false
#       otherwise
sub precondition
{
    my $global = EBox::Global->getInstance();
    my $ca = $global->modInstance('ca');
    return ($ca->isCreated());
}

# Method: preconditionFailMsg
#
#   Overrides <EBox::Model::DataTable::preconditionFailMsg
#
# Returns:
#
#       String - the i18ned message to inform user why this model
#       cannot be handled
#
#
sub preconditionFailMsg
{
    return  __x('{openpar}You need to create a CA certificate to use this module.'
        . ' {closepar}{openpar}Please, go to the {openhref}certification '
        . 'authority module{closehref} and create it.{closepar}',
        openhref => qq{<a href='/ebox/CA/Index'>}, closehref => qq{</a>},
        openpar => '<p>', closepar => '</p>' );

}

sub validateTypedRow
{
    my ($self, $action, $params_r, $actual_r) = @_;

    if ($action eq 'add') {
        $self->_checkCertificatesAvailable(
                  __('Server creation')
                                          );
        return;
    }

    $self->_validateService($action, $params_r, $actual_r);
    $self->_validateName($action, $params_r, $actual_r);
}

sub servers
{
    my ($self) = @_;
    my @servers = map {
        EBox::OpenVPN::Server->new(
                                    $self->row($_)
                                  )
    } @{  $self->ids() };

    return \@servers;

}


sub server
{
    my ($self, $name) = @_;
    $name or
        throw EBox::Exceptions::MissingArgument('name');

    my $row = $self->findRow(name => $name);
    defined $row or
        throw EBox::Exceptions::Internal("Server $name does not exist");

    return EBox::OpenVPN::Server->new($row);
}


sub serverExists
{
    my ($self, $name) = @_;
    $name or
        throw EBox::Exceptions::MissingArgument('name');

    my $row = $self->findValue(name => $name);
    return defined $row
}

sub addedRowNotify
{
    my ($self, $row) = @_;

    EBox::OpenVPN::Model::InterfaceTable::addedRowNotify($self, $row);

    $self->_configureVPN($row);
    unless ($row->subModel('configuration')->configured()) {
        my $service = $row->elementByName('service');
        $service->setValue(0);
        $row->store();
    }
    my $service = $row->elementByName('service');

    if ($service->value()) {
        my $openvpn = EBox::Global->modInstance('openvpn');
        $openvpn->notifyLogChange();
    }

}

sub updatedRowNotify
{
    my ($self, $row) = @_;

    my $openvpn = EBox::Global->modInstance('openvpn');
    $openvpn->notifyLogChange();

}

sub deletedRowNotify
{
    my ($self, $row) = @_;
    my $name = $row->elementByName('name')->value();

    my $openvpn = EBox::Global->modInstance('openvpn');
    $openvpn->notifyDaemonDeletion($name, 'server');

}

# Group: Private methods

sub _validateService
{
    my ($self, $action, $params_r, $actual_r) = @_;


    if ( not exists $params_r->{service} ) {
        return;
    }

    if (not $params_r->{service}->value()) {
        return;
    }

    my $configuration = $actual_r->{'configuration'}->foreignModelInstance();
    if ((not defined $configuration) or (not $configuration->configured())) {
        throw EBox::Exceptions::External(
                                         __('Cannot activate the server because '
                                            .' is not fully configured; please '
                                            . 'edit the configuration and retry')
                                            )
        }

    unless ($self->precondition()) {
        throw EBox::Exceptions::External(
                __('Cannot create a server because there is not a CA certificate')
                );
    }
}


sub _validateName
{
    my ($self, $action, $params_r, $actual_r) = @_;

    if ( not exists $params_r->{name} ) {
        return;
    }

    my $name =  $params_r->{name}->value();
    my $openvpn = EBox::Global->modInstance('openvpn');
    $openvpn->checkNewDaemonName($name, 'server');
}

sub _checkCertificatesAvailable
{
    my ($self, $printableAction) = @_;

    unless ($self->precondition()) {
        throw EBox::Exceptions::External(
                   __x(
                       q/{act} not possible because there aren't/
                       . 'any available certificate. Please, go to'
                       . 'the certificate authority module'
                       . 'and create new certificates',
                       act => $printableAction
                      )
                                        );
    }
}

# Return the model help message
sub _help
{
    return __x('{openpar}You can configure openVPN servers to easily connect remote ' .
            'offices or users.{closepar}' .
            '{openpar}Click on {openit}Configuration{closeit} to set the VPN parameters.{closepar}' .
            '{openpar}{openit}Advertised networks{closeit} allows you to configure which ' .
            'networks you want to make accessible to the remote users.' .
            '{openpar}Once you are done with the configuration you can download ' .
            'a file bundle for your operating system to use in your clients.',
            openpar => '<p>', closepar => '</p>', openit => '<i>',
            closeit => '</i>');

}

# Configure VPN address, port and create a server certificate automatically
sub _configureVPN
{
    my ($self, $row) = @_;

    my $name = $row->valueByName('name');

    # Configure network
    my $networkMod = EBox::Global->modInstance('network');
    my @addresses;
    for my $iface (@{$networkMod->allIfaces()}) {
        my $address = $networkMod->ifaceAddress($iface);
        push (@addresses, $address) if ($address);
    }

    for my $id (@{$self->ids()}) {
        next if ($id eq $row->id());
        my $subModel = $self->row($id)->subModel('configuration');
        my $vpn = $subModel->row()->elementByName('vpn')->printableValue();
        my $name = $self->row($id)->valueByName('name');
        push (@addresses, $vpn) if ($vpn);
    }
    my $network;
    for my $postfix (FROM_RANGE .. TO_RANGE) {
        my $net = START_ADDRESS_PREFIX . $postfix;
        next if (List::Util::first {$_ =~ /^$net.*/ } @addresses);
        $network= "${net}.0/24";
        last;
    }

    # Configure  port
    my $port;
    my $firewall = EBox::Global->modInstance('firewall');
    $port = List::Util::first { $firewall->availablePort('udp', $_) } PORTS;

    # Create server certificate
    my $ca = EBox::Global->modInstance('ca');
    my $certName = "vpn-$name";
    my @certs = @{$ca->listCertificates()};
    unless (List::Util::first { $_->{dn}->{commonName} eq $certName } @certs ) {
        my $caExpiration = $ca->getCACertificateMetadata()->{expiryDate};
        $ca->issueCertificate(commonName => $certName , endDate => $caExpiration);
    }

    if ($port and $network) {
        my $conf = $row->subModel('configuration');
        my $subRow = $conf->row();
        $subRow->elementByName('vpn')->setValue($network);
        $subRow->elementByName('portAndProtocol')->setValue("$port/udp");
        $subRow->elementByName('masquerade')->setValue(1);
        $subRow->elementByName('certificate')->setValue($certName);
        $subRow->store();
    }

    # Advertise local networks
    for my $iface (@{$networkMod->InternalIfaces()}) {
        next unless ($networkMod->ifaceMethod($iface) eq 'static');
        for my $ifaceAddress (@{$networkMod->ifaceAddresses($iface)}) {
            my $netAddress = EBox::NetWrappers::ip_network(
                    $ifaceAddress->{address},
                    $ifaceAddress->{netmask}
                    );
            my $advertise = $row->subModel('advertisedNetworks');
            $advertise->add(
                    network => EBox::NetWrappers::to_network_with_mask(
                        $netAddress,
                        $ifaceAddress->{netmask}
                        )
                    );
        }
    }
}

1;
