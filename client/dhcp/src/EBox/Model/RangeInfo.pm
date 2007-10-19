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

package EBox::DHCP::Model::RangeInfo;

use base 'EBox::Model::DataForm::ReadOnly';

# eBox uses
use EBox::Gettext;
use EBox::Global;
use EBox::NetWrappers;
use EBox::Types::IPAddr;
use EBox::Types::Text;

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

      return $self;

  }

sub domain
{
    return 'ebox-dhcp';
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

    my @tableDesc =
      (
       new EBox::Types::IPAddr(
                               fieldName     => 'subnet',
                               printableName => __('Subnet'),
                              ),
       new EBox::Types::Text(
                              fieldName     => 'available_range',
                              printableName => __('Available range'),
                             ),
      );

      my $dataForm = {
                      tableName          => 'RangeInfo',
                      printableTableName => __('DHCP ranges'),
                      modelDomain        => 'DHCP',
                      tableDescription   => \@tableDesc,
                      class              => 'dataForm',
                     };

      return $dataForm;

  }

# Group: Protected methods

# Method: _content
#
# Overrides:
#
#    <EBox::Model::DataForm::ReadOnly::_content>
#
sub _content
{

    my ($self) = @_;

    my $dhcp = $self->{gconfmodule};
    my $net  = EBox::Global->modInstance('network');

    my $subnet = EBox::NetWrappers::to_network_with_mask(
                            $net->ifaceNetwork($self->{interface}),
                            $net->ifaceNetmask($self->{interface})
                                                        );

    my $availableRange = $dhcp->initRange($self->{interface}) . ' - '
      . $dhcp->endRange($self->{interface});

    return
      {
       subnet          => $subnet,
       available_range => $availableRange,
      };

}

1;
