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

    my @tableDesc =
      (
       new EBox::Types::Union(
                              fieldName     => 'default_gateway',
                              printableName => __('Default gateway'),
                              editable      => 1,
                              subtypes =>
                              [
                               new EBox::Types::HostIP(
                                                     fieldName     => 'ip',
                                                     printableName => __('IP address'),
                                                     editable      => 1,
                                                     defaultValue  => $self->_fetchIfaceAddress(),
                                                    ),
                               new EBox::Types::Union::Text(
                                                            fieldName => 'ebox',
                                                            printableName => __('eBox'),
                                                           ),
                               new EBox::Types::Select(
                                                       fieldName    => 'name',
                                                       printable    => __('Name'),
                                                       editable     => 1,
                                                       foreignModel => \&_gatewayModel,
                                                       foreignField => 'name'
                                                      ),
                               new EBox::Types::Union::Text(
                                                            fieldName => 'none',
                                                            printableName => __('None'),
                                                           ),
                              ]
                             ),
       new EBox::Types::Union(
                              fieldName     => 'search_domain',
                              printableName => __('Search domain'),
                              editable      => 1,
                              subtypes      =>
                              [
                               new EBox::Types::DomainName(
                                                           fieldName     => 'custom_domain',
                                                           printableName => __('Custom'),
                                                           editable      => 1,
                                                          ),
                               new EBox::Types::Select(
                                                       fieldName     => 'ebox_domain',
                                                       printableName => __('eBox'),
                                                       editable      => 1,
                                                       foreignModel  => \&_domainModel,
                                                       foreignField  => 'domain',
                                                      )
                              ],
                             ),
       new EBox::Types::HostIP(
                               fieldName     => 'primary_ns',
                               printableName => __('Primary nameserver'),
                               editable      => 1,
                               defaultValue  => $self->_fetchPrimaryNS(),
                               optional      => 1,
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
    return EBox::Global->modInstance('dns')->model('domainTable');
}

# Get the object model from Service module
sub _gatewayModel
{
    return EBox::Global->modInstance('network')->model('GatewayTable');
}

# Fetch ip address from current interface
sub _fetchIfaceAddress
{
    my ($self) = @_;

    return $self->{netMod}->ifaceAddress($self->{interface});

}

# Fetch primary nameserver from Network module
sub _fetchPrimaryNS
{

    my ($self) = @_;

    return $self->{netMod}->nameserverOne();

}

# Fetch secondary nameserver from Network module
sub _fetchSecondaryNS
{

    my ($self) = @_;

    return $self->{netMod}->nameserverTwo();

}

1;
