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

# Class: EBox::DHCP::Model::Options
#
# This class is the model to configurate general options for the dhcp
# server on a static interface. The fields are the following:
#
#     - default gateway
#     - search domain
#     - primary nameserver
#     - second nameserver
#

package EBox::DHCP::Model::Options;

use base 'EBox::Model::DataForm';

use strict;
use warnings;

# eBox uses
use EBox::Exceptions::External;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::MissingArgument;
use EBox::Gettext;
use EBox::Global;
use EBox::NetWrappers;
use EBox::Types::DomainName;
use EBox::Types::HostIP;
use EBox::Types::Select;
use EBox::Types::Union;
use EBox::Types::Union::Text;
use EBox::Validate;

# Dependencies
use Net::IP;

# Group: Public methods

# Constructor: new
#
#     Create the general options to the dhcp server
#
# Overrides:
#
#     <EBox::Model::DataForm::new>
#
# Parameters:
#
#     interface - String the interface where the DHCP server is
#     attached
#
# Returns:
#
#     <EBox::DHCP::Model::Options>
#
# Exceptions:
#
#     <EBox::Exceptions::MissingArgument> - thrown if any compulsory
#     argument is missing
#
sub new
  {

      my $class = shift;
      my %opts = @_;
      my $self = $class->SUPER::new(@_);
      bless ( $self, $class);

      throw EBox::Exceptions::MissingArgument('interface')
        unless defined ( $opts{interface} );

      $self->{interface} = $opts{interface};
      $self->{netMod} = EBox::Global->modInstance('network');

      return $self;

  }

# Method: index
#
# Overrides:
#
#      <EBox::Model::DataTable::index>
#
sub index
{

    my ($self) = @_;

    return $self->{interface};

}

# Method: printableIndex
#
# Overrides:
#
#     <EBox::Model::DataTable::printableIndex>
#
sub printableIndex
{

    my ($self) = @_;

    return __x("interface {iface}",
              iface => $self->{interface});

}

# Method: validateTypedRow
#
# Overrides:
#
#      <EBox::Model::DataTable::validateTypedRow>
#
sub validateTypedRow
{
    my ($self, $action, $changedFields, $allFields) = @_;

    if ( exists $changedFields->{default_gateway} ) {
        # Check the given gateway is in the current network
        my $networkCIDR =
          EBox::NetWrappers::to_network_with_mask(
                                                  $self->{netMod}->ifaceNetwork($self->{interface}),
                                                  $self->{netMod}->ifaceNetmask($self->{interface}),
                                                 );
        my $networkIP = new Net::IP($networkCIDR);
        my $defaultGwType = $changedFields->{default_gateway};
        my $selectedTypeName = $defaultGwType->selectedType();
        my ($defaultGwIP, $gwName);
        if ( $selectedTypeName eq 'ip' ) {
            $defaultGwIP = new Net::IP($defaultGwType->value());
            $gwName = $defaultGwIP->print();
        } elsif ( $selectedTypeName eq 'name' ) {
            my $gwModel = $defaultGwType->foreignModel();
            my $row = $gwModel->row( $defaultGwType->value() );
            $defaultGwIP = new Net::IP($row->{plainValueHash}->{ip});
            $gwName = $defaultGwType->printableValue();
        }
        if ( defined ( $defaultGwIP )) {
            unless ( $defaultGwIP->overlaps($networkIP) == $IP_A_IN_B_OVERLAP ) {
                throw EBox::Exceptions::External(__x('{gateway} is not in the '
                                                    . 'current network',
                                                    gateway => $gwName));
            }
        }
    }
    if ( exists $changedFields->{primary_ns} ) {
        # Check if chosen is DNS to check if it's enabled
        if ( $changedFields->{primary_ns}->selectedType() eq 'eboxDNS' ) {
            my $dns = EBox::Global->modInstance('dns');
            unless ( $dns->service() ) {
                throw EBox::Exceptions::External(__('DNS service must be active to as primary '
                                                    . 'nameserver the local eBox DNS server'));
            }
        }
    }
}

# Method: formSubmitted
#
#       When the form is submitted, the model must set up the jabber
#       dispatcher client service and sets the output rule in the
#       firewall
#
# Overrides:
#
#      <EBox::Model::DataForm::formSubmitted>
#
sub formSubmitted
  {

      my ($self, $oldRow) = @_;

  }

# Method: defaultGateway
#
#     Get the current default gateway
#
# Returns:
#
#     String - the current default gateway in a IP address form
#
sub defaultGateway
{

    my ( $self ) = @_;

    my $row = $self->row();

    my $gwType = $row->{valueHash}->{default_gateway};
    my $selectedTypeName = $gwType->selectedType();
    if ( $selectedTypeName eq 'ip' ) {
        return $gwType->value();
    } elsif ( $selectedTypeName eq 'name' ) {
        my $gwModel = $gwType->foreignModel();
        my $row = $gwModel->row( $gwType->value() );
        return $row->{plainValueHash}->{ip};
    } elsif ( $selectedTypeName eq 'none' ) {
        return '';
    } elsif ( $selectedTypeName eq 'ebox' ) {
        return $self->{netMod}->ifaceAddress($self->{interface});
    }

}

# Method: setDefaultGateway
#
#     Set the default gateway guessing the type
#
# Parameters:
#
#     gateway - String, it can represent the following values: empty
#     string (none), 'ebox' indicating you want eBox as gateway, an IP
#     address or a named configured gateways
#
sub setDefaultGateway
{
    my ($self, $gateway) = @_;

    my $type;
    if ( $gateway eq 'ebox' ) {
        $type = 'ebox';
    } elsif ( $gateway eq '' ) {
        $type = 'none';
    } elsif ( new Net::IP($gateway) ) {
        $type = 'ip';
    } else {
        $type = 'name';
    }

    $self->set( default_gateway => { $type => $gateway});

}

# Method: searchDomain
#
#     Get the current search domain
#
# Returns:
#
#     String - the current search domain if any, otherwise undef
#
sub searchDomain
{
    my ($self) = @_;

    my $row = $self->row();

    my $selectedType = $row->{valueHash}->{search_domain}->selectedType();

    if ( $selectedType eq 'none' ) {
        return undef;
    } else {
        return $row->{printableValueHash}->{search_domain};
    }

}

# Method: nameserver
#
#     Get the primary or secondary nameserver for this options interface
#
# Parameters:
#
#     number - Int 1 or 2
#
# Returns:
#
#     String - the current nameserver IP if any, otherwise undef
#
sub nameserver
{
    my ($self, $number) = @_;

    my $row = $self->row();

    my $selectedType;
    if ( $number == 1 ) {
        $selectedType = $row->{valueHash}->{primary_ns}->selectedType();
        if ( $selectedType eq 'none' ) {
            return undef;
        } elsif ( $selectedType eq 'eboxDNS' ) {
            my $ifaceAddr = $self->{netMod}->ifaceAddress($self->{interface});
            return $ifaceAddr;
        } else {
            return $row->{printableValueHash}->{primary_ns};
        }
    } else {
        return $row->{valueHash}->{secondary_ns}->printableValue();
    }

}


# Group: Protected methods

# Method: _table
#
# Overrides:
#
#     <EBox::Model::DataForm::_table>
#
sub _table
{
    my ($self) = @_;

    my $gl = EBox::Global->getInstance();

    my (@searchDomainSubtypes, @primaryNSSubtypes) = ( (), () );
    push ( @searchDomainSubtypes,
           new EBox::Types::DomainName(
                                       fieldName     => 'custom',
                                       printableName => __('Custom'),
                                       editable      => 1,
                                      ));
    # Set the subtypes associated to DNS module
    if ( $gl->modExists('dns') ) {
        push( @searchDomainSubtypes,
              new EBox::Types::Select(
                                      fieldName     => 'ebox',
                                      printableName => __(q{eBox's domain}),
                                      editable      => 1,
                                      foreignModel  => \&_domainModel,
                                      foreignField  => 'domain',
                                     ));
        push ( @primaryNSSubtypes,
               new EBox::Types::Union::Text(
                                            fieldName => 'eboxDNS',
                                            printableName => __('local eBox DNS')
                                           ));

    }
    push ( @searchDomainSubtypes,
           new EBox::Types::Union::Text(
                                        fieldName => 'none',
                                        printableName => __('None'),
                                       ));
    push ( @primaryNSSubtypes,
           new EBox::Types::HostIP(
                                   fieldName     => 'custom_ns',
                                   printableName => __('Custom'),
                                   editable      => 1,
                                   defaultValue  => $self->_fetchPrimaryNS(),
                                   optional      => 1,
                                  ),
           new EBox::Types::Union::Text(
                                        fieldName => 'none',
                                        printableName => __('None'),
                                       ));

    my @tableDesc =
      (
       new EBox::Types::Union(
                              fieldName     => 'default_gateway',
                              printableName => __('Default gateway'),
                              editable      => 1,
                              subtypes =>
                              [
                               new EBox::Types::Union::Text(
                                                            fieldName => 'ebox',
                                                            printableName => __('eBox'),
                                                           ),
                               new EBox::Types::HostIP(
                                                       fieldName     => 'ip',
                                                       printableName => __('Custom IP address'),
                                                       editable      => 1,
                                                       #defaultValue  => $self->_fetchIfaceAddress(),
                                                    ),
                               new EBox::Types::Union::Text(
                                                            fieldName => 'none',
                                                            printableName => __('None'),
                                                           ),
                               new EBox::Types::Select(
                                                       fieldName     => 'name',
                                                       printableName => __('Configured ones'),
                                                       editable      => 1,
                                                       foreignModel  => \&_gatewayModel,
                                                       foreignField  => 'name'
                                                      ),
                              ]
                             ),
       new EBox::Types::Union(
                              fieldName     => 'search_domain',
                              printableName => __('Search domain'),
                              editable      => 1,
                              subtypes      => \@searchDomainSubtypes,
                             ),
       new EBox::Types::Union(
                              fieldName      => 'primary_ns',
                              printableName  => __('Primary nameserver'),
                              editable       => 1,
                              subtypes       => \@primaryNSSubtypes,
                             ),
       new EBox::Types::HostIP(
                               fieldName     => 'secondary_ns',
                               printableName => __('Secondary nameserver'),
                               editable      => 1,
                               defaultValue  => $self->_fetchSecondaryNS(),
                               optional      => 1,
                              ),
      );

      my $dataForm = {
                      tableName          => 'Options',
                      printableTableName => __('Options'),
                      modelDomain        => 'DHCP',
                      defaultActions     => [ 'editField' ],
                      tableDescription   => \@tableDesc,
                      class              => 'dataForm',
                      help               => __('Setting "eBox" as default gateway will set '
                                               . 'as default gateway the interface address. '
                                               . 'If you set a "name", you may choose one the configured '
                                               . 'gateways. As "search domain" value, '
                                               . 'one of the configured DNS domains on eBox might be chosen. '
                                               . 'If you set the "Primary nameserver" the "eBox '
                                               . 'DNS" if installed, the eBox server may act as '
                                               . 'cache DNS server. All fields are optionals setting '
                                               . 'its value as "None" or leaving blank.'),
                     };

      return $dataForm;

  }

# Group: Private methods

# Get the object model from Objects module
sub _domainModel
{
    # FIXME: when model works with old fashioned
    return EBox::Global->modInstance('dns')->{domainModel};
}

# Get the object model from Service module
sub _gatewayModel
{
    # FIXME: when model works with old fashioned
    return EBox::Global->modInstance('network')->{gatewayModel};
}

# Fetch ip address from current interface
sub _fetchIfaceAddress
{
    my ($self) = @_;

    my $ifaceAddr = $self->{netMod}->ifaceAddress($self->{interface});
    ($ifaceAddr) or return undef;
    return $ifaceAddr;

}

# Fetch primary nameserver from Network module
sub _fetchPrimaryNS
{

    my ($self) = @_;

    my $nsOne = $self->{netMod}->nameserverOne();
    ($nsOne) or return undef;
    return $nsOne;

}

# Fetch secondary nameserver from Network module
sub _fetchSecondaryNS
{

    my ($self) = @_;

    my $nsTwo = $self->{netMod}->nameserverTwo();
    ($nsTwo) or return undef;
    return $nsTwo;
}

1;
