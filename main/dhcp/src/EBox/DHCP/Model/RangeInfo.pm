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

use EBox::Gettext;
use EBox::Global;
use EBox::NetWrappers;
use EBox::Types::IPAddr;
use EBox::Types::Text;
use EBox::Types::HostIP;

# Group: Public methods

# Constructor: new
#
#     Create the general options to the dhcp server
#
# Overrides:
#
#     <EBox::Model::DataForm::new>
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
    bless ($self, $class);

    return $self;
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
         new EBox::Types::HostIP(
             fieldName     => 'iface_address',
             printableName => __('Interface IP address'),
             ),
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

    my $net  = EBox::Global->modInstance('network');

    my $interface = $self->_iface();
    my $ifaceAddr = $net->ifaceAddress($interface);

    my $subnet = EBox::NetWrappers::to_network_with_mask(
                            $net->ifaceNetwork($interface),
                            $net->ifaceNetmask($interface)
                                                        );

    my $availableRange = $net->netInitRange($interface) . ' - '
      . $net->netEndRange($interface);

    return {
       iface_address   => $ifaceAddr,
       subnet          => $subnet,
       available_range => $availableRange,
    };
}

sub _iface
{
    my ($self) = @_;

    my $parentRow = $self->parentRow();
    if (not $parentRow) {
        # workaround: sometimes with a logout + apache restart the directory
        # parameter is lost. (the apache restart removes the last directory used
        # from the models)
        EBox::Exceptions::ComponentNotExists->throw('Directory parameter and attribute lost');
    }

    return $parentRow->valueByName('iface');
}

# Method: viewCustomizer
#
#   Overrides <EBox::Model::DataTable::viewCustomizer>
#
#
sub viewCustomizer
{
    my ($self) = @_;

    my $customizer = new EBox::View::Customizer();

    $customizer->setModel($self);
    $customizer->setHTMLTitle([]);

    return $customizer;
}

1;
