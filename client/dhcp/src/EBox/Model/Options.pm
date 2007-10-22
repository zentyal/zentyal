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

# eBox uses
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::MissingArgument;
use EBox::Gettext;
use EBox::Global;
use EBox::Types::DomainName;
use EBox::Types::HostIP;
use EBox::Types::Select;
use EBox::Types::Union;
use EBox::Types::Union::Text;
use EBox::Validate;

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
                                       fieldName     => 'custom_domain',
                                       printableName => __('Custom'),
                                       editable      => 1,
                                      ));
    # Set the subtypes associated to DNS module
    if ( $gl->modExists('dns') ) {
        push( @searchDomainSubtypes,
              new EBox::Types::Select(
                                      fieldName     => 'ebox_domain',
                                      printableName => __('eBox'),
                                      editable      => 1,
                                      foreignModel  => \&_domainModel,
                                      foreignField  => 'domain',
                                     ));
        push ( @primaryNSSubtypes,
               new EBox::Types::Union::Text(
                                            fieldName => 'eboxDNS',
                                            printableName => __('eBox DNS')
                                           ));

    }
    push ( @searchDomainSubtypes,
           new EBox::Types::Union::Text(
                                        fieldName => 'none',
                                        printableName => __('None'),
                                       ));
    push ( @primaryNSSubtypes,
           new EBox::Types::HostIP(
                                   fieldName     => 'custom',
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
                                                       fieldName    => 'name',
                                                       printable    => __('Configured ones'),
                                                       editable     => 1,
                                                       foreignModel => \&_gatewayModel,
                                                       foreignField => 'name'
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
                               fieldName     => 'second_ns',
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

    my $ns0ne = $self->{netMod}->nameserverOne();
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
