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

    # Validate default gateway
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
    # Validate primary Nameserver
    if ( exists $changedFields->{primary_ns} ) {
        # Check if chosen is DNS to check if it's enabled
        if ( $changedFields->{primary_ns}->selectedType() eq 'eboxDNS' ) {
            my $dns = EBox::Global->modInstance('dns');
            unless ( $dns->isEnabled() ) {
                throw EBox::Exceptions::External(__('DNS module must be enabled to be able to select eBox as primary DNS server'));
            }
        }
    }
    # Validate NTP server
    if ( exists $changedFields->{ntp_server} ) {
        # Check if chosen is NTP to check if it is enabled
        if ( $changedFields->{ntp_server}->selectedType() eq 'eboxNTP' ) {
            my $ntp = EBox::Global->modInstance('ntp');
            unless ( $ntp->isEnabled() ) {
                throw EBox::Exceptions::External(__('NTP module must be enabled to be able to select eBox as NTP server'));
            }
        }
    }
    # Validate WINS server
    if ( exists $changedFields->{wins_server} ) {
        # Check if chosen is WINS to check if it is enabled
        if ( $changedFields->{wins_server}->selectedType() eq 'eboxWINS' ) {
            my $sambaMod = EBox::Global->modInstance('samba');
            unless ( $sambaMod->isEnabled() and $sambaMod->pdc() ) {
                throw EBox::Exceptions::External(
                    __('Samba module must be enabled and in PDC mode '
                       . 'to be able to select eBox as WINS server'));
            }
        }
    }

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

    my $gwType = $row->elementByName('default_gateway');
    my $selectedTypeName = $gwType->selectedType();
    if ( $selectedTypeName eq 'ip' ) {
        return $gwType->subtype->value();
    } elsif ( $selectedTypeName eq 'name' ) {
        my $gwModel = $gwType->subtype()->foreignModel();
        my $row = $gwModel->row( $gwType->subtype()->value() );
        return $row->valueByName('ip');
    } elsif ( $selectedTypeName eq 'none' ) {
        return '';
    } elsif ( $selectedTypeName eq 'ebox' ) {
        return $self->{netMod}->ifaceAddress($self->{interface});
    }

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

    my $selectedType = $row->elementByName('search_domain')->selectedType();

    if ( $selectedType eq 'none' ) {
        return undef;
    } else {
        return $row->elementByName('search_domain')->subtype()->printableValue();
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
        $selectedType = $row->elementByName('primary_ns')->selectedType();
        if ( $selectedType eq 'none' ) {
            return undef;
        } elsif ( $selectedType eq 'eboxDNS' ) {
            my $ifaceAddr = $self->{netMod}->ifaceAddress($self->{interface});
            return $ifaceAddr;
        } else {
            return $row->elementByName('primary_ns')->subtype()->printableValue();
        }
    } else {
            return $row->printableValueByName('secondary_ns');
    }

}

# Method: ntpServer
#
#     Get the current IP address from the NTP server
#
# Returns:
#
#     String - the current NTP server if any, otherwise undef is returned
#
sub ntpServer
{
    my ($self) = @_;

    my $row = $self->row();

    my $selectedType = $row->elementByName('ntp_server')->selectedType();

    if ( $selectedType eq 'none' ) {
        return undef;
    } elsif ( $selectedType eq 'eboxNTP' ) {
        my $ifaceAddr = $self->{netMod}->ifaceAddress($self->{interface});
        return $ifaceAddr;
    } elsif ( $selectedType eq 'custom_ntp' ) {
        return $row->valueByName('custom_ntp');
    }

}

# Method: winsServer
#
#     Get the current IP address from the WINS server
#
# Returns:
#
#     String - the current WINS server if any, otherwise undef is returned
#
sub winsServer
{
    my ($self) = @_;

    my $row = $self->row();

    my $selectedType = $row->elementByName('wins_server')->selectedType();

    if ( $selectedType eq 'none' ) {
        return undef;
    } elsif ( $selectedType eq 'eboxWINS' ) {
        my $ifaceAddr = $self->{netMod}->ifaceAddress($self->{interface});
        return $ifaceAddr;
    } elsif ( $selectedType eq 'custom_wins' ) {
        return $row->valueByName('custom_wins');
    }

}

# Method: headTitle
#
# Overrides:
#
#   <EBox::Model::Component::headTitle>
#
sub headTitle
{
    return undef;
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
                                  ),
           new EBox::Types::Union::Text(
                                        fieldName => 'none',
                                        printableName => __('None'),
                                       ));

    my @ntpSubtypes = ( new EBox::Types::Union::Text(fieldName     => 'none',
                                                     printableName => __('None')));

    if ( $gl->modExists('ntp') ) {
        push(@ntpSubtypes,
             new EBox::Types::Union::Text(fieldName     => 'eboxNTP',
                                          printableName => __('local eBox NTP')));
    }
    push(@ntpSubtypes,
         new EBox::Types::HostIP(fieldName     => 'custom_ntp',
                                 printableName => __('Custom'),
                                 editable      => 1)
        );

    my @winsSubtypes = ( new EBox::Types::Union::Text(fieldName    => 'none',
                                                      printableName => __('None')));

    if ( $gl->modExists('samba') ) {
        push(@winsSubtypes,
             new EBox::Types::Union::Text(fieldName     => 'eboxWINS',
                                          printableName => __('local eBox')));
    }
    push(@winsSubtypes,
         new EBox::Types::HostIP(fieldName     => 'custom_wins',
                                 printableName => __('Custom'),
                                 editable      => 1)
        );

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
                              ],
                              help          => __('Setting "eBox" as default gateway will set the interface '
                                                  . 'IP address as gateway'),

                             ),
       new EBox::Types::Union(
                              fieldName     => 'search_domain',
                              printableName => __('Search domain'),
                              editable      => 1,
                              subtypes      => \@searchDomainSubtypes,
                              help          => __('The selected domain will complete on your clients '
                                                  . 'those DNS queries which are not fully qualified'),
                             ),
       new EBox::Types::Union(
                              fieldName      => 'primary_ns',
                              printableName  => __('Primary nameserver'),
                              editable       => 1,
                              subtypes       => \@primaryNSSubtypes,
                              help           => __('If "eBox DNS" is present and selected, the eBox server will act '
                                                   . 'as cache DNS server'),
                             ),
       new EBox::Types::HostIP(
                               fieldName     => 'secondary_ns',
                               printableName => __('Secondary nameserver'),
                               editable      => 1,
                               optional      => 1,
                              ),
       new EBox::Types::Union(
                              fieldName      => 'ntp_server',
                              printableName  => __('NTP server'),
                              editable       => 1,
                              subtypes       => \@ntpSubtypes,
                              help           => __('If "eBox NTP" is present and selected, '
                                                   . 'eBox will be the NTP server for DHCP clients'),
                              ),
       new EBox::Types::Union(
                              fieldName      => 'wins_server',
                              printableName  => __('WINS server'),
                              editable       => 1,
                              subtypes       => \@winsSubtypes,
                              help           => __('If "eBox Samba" is present and selected, '
                                                   . 'eBox will be the WINS server for DHCP clients'),
                             ),
      );

      my $dataForm = {
                      tableName          => 'Options',
                      printableTableName => __('Common options'),
                      modelDomain        => 'DHCP',
                      defaultActions     => [ 'editField', 'changeView' ],
                      tableDescription   => \@tableDesc,
                      class              => 'dataForm',
                      help               => __('If you set a "configured ones" as default gateway, '
                                               . 'you may choose one the configured gateways. As '
                                               . '"search domain" value, one of the configured '
                                               . 'DNS domains on eBox might be chosen. '
                                               . 'All fields are optionals setting '
                                               . 'its value as "None" or leaving blank.'),
                     };

      return $dataForm;

  }

# Group: Private methods

# Get the object model from Objects module
sub _domainModel
{
    # FIXME: when model works with old fashioned
    return EBox::Global->modInstance('dns')->model('DomainTable');
}

# Get the object model from Service module
sub _gatewayModel
{
    # FIXME: when model works with old fashioned
    return EBox::Global->modInstance('network')->model('GatewayTable');
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
