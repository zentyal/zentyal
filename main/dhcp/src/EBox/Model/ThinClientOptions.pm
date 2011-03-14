# Copyright (C) 2008-2011 eBox Technologies S.L.
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

# Class: EBox::DHCP::Model::ThinClientOptions
#
# This class is the model to configurate thin client options for the dhcp
# server on a static interface. The fields are the following:
#
#     - next server, which tells dhcp client where to search the
#     terminal server
#
#     - filename, which indicates the firmware to load when the DHCP
#     client loads
#

package EBox::DHCP::Model::ThinClientOptions;

use base 'EBox::Model::DataTable';

use strict;
use warnings;

use feature 'switch';

use EBox::DHCP;
use EBox::DHCP::Types::Group;
use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::External;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::MissingArgument;
use EBox::Gettext;
use EBox::Global;
use EBox::NetWrappers;
use EBox::Types::File;
use EBox::Types::Union;
use EBox::Types::Union::Text;
use EBox::Types::Host;
use EBox::Validate;

# Group: Public methods

# Constructor: new
#
#     Create the thin client options to the dhcp server
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
#     <EBox::DHCP::Model::ThinClientOptions>
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

# Method: notifyForeignModelAction
#
#     Remove rows when a range or fixed address is removed from the
#     same interface and applies to this model and object.
#
#     Do this because of framework limitation.
#
# Overrides:
#
#     <EBox::Model::DataTable::notifyForeignModelAction>
#
sub notifyForeignModelAction
{
    my ($self, $model, $action, $row) = @_;

    if ( $action eq 'del' ) {
        my $idToRemove;
        given ( $model ) {
            when ( 'FixedAddressTable' ) {
                $idToRemove = $row->valueByName('object');
            }
            when ( 'RangeTable' ) {
                $idToRemove = $row->valueByName('name');
            }
            default { return ""; }
        }
        my $matchedRow = $self->findValue(hosts => $idToRemove);
        if ( $matchedRow ) {
            $self->removeRow($matchedRow->id(), 1);
            return __x('Remove thin client options from {model}{br}',
                       model => $self->printableContextName(),
                       br    => '<br>');
        }
    }
    return "";

}

# Method: nextServer
#
#     Get the next server (name or IP address) in an string form to
#     tell the DHCP clients which is the next server to ask for
#     terminal
#
# Parameters:
#
#     id - String the row identifier
#
# Returns:
#
#     String - a name or an IP address
#
# Exceptions:
#
#     <EBox::Exceptions::DataNotFound> - thrown if the given id is not
#     from this model
#
sub nextServer
{
    my ($self, $id) = @_;

    my $row = $self->row($id);

    unless ( defined($row) ) {
        throw EBox::Exceptions::DataNotFound(data => 'id', value => $id);
    }

    my $nextServerType = $row->elementByName('nextServer');
    my $nextServerSelectedName = $nextServerType->selectedType();
    given ( $nextServerSelectedName ) {
        when ('nextServerEBox' ) {
            my $netMod = EBox::Global->modInstance('network');
            return $netMod->ifaceAddress($self->{interface});
        }
        default {
            return $nextServerType->printableValue();
        }
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


    my @tableDesc =
      (
       new EBox::Types::Union(
                              fieldName     => 'nextServer',
                              printableName => __('Next server'),
                              editable      => 1,
                              subtypes      =>
                              [new EBox::Types::Union::Text(fieldName     => 'nextServerEBox',
                                                            printableName => 'Zentyal',
                                                           ),
                               new EBox::Types::Host(fieldName     => 'nextServerHost',
                                                     printableName => __('Host'),
                                                     editable      => 1,
                                                    ),
                              ]),
       new EBox::Types::Text(
                             fieldName     => 'remoteFilename',
                             printableName => __('File path in next server'),
                             editable      => 1,
                            ),
       new EBox::Types::Union(
                              fieldName      => 'hosts',
                              printableName  => __('Clients'),
                              editable       => 1,
                              subtypes       => [
                                  new EBox::DHCP::Types::Group(
                                      fieldName        => 'object',
                                      printableName    => __('Object'),
                                      index            => $self->index(),
                                      foreignModelName => 'FixedAddressTable',
                                      foreignField     => 'object',
                                      unique           => 1,
                                      editable         => 1
                                     ),
                                  new EBox::DHCP::Types::Group(
                                      fieldName        => 'range',
                                      printableName    => __('Range'),
                                      index            => $self->index(),
                                      foreignModelName => 'RangeTable',
                                      foreignField     => 'name',
                                      unique           => 1,
                                      editable         => 1)
                                    ]),
      );

    my $dataTable = {
                    tableName          => 'ThinClientOptions',
                    printableTableName => __('Thin client'),
                    modelDomain        => 'DHCP',
                    defaultActions     => [ 'add', 'del', 'editField', 'changeView' ],
                    tableDescription   => \@tableDesc,
                    class              => 'dataTable',
                    help               => __x('You may want to customise your thin client options.'
                                             . 'To do so, you may include all the files you require '
                                             . 'under {path} directory',
                                             path => EBox::DHCP->PluginConfDir($self->{interface})),
                    sortedBy           => 'hosts',
                    printableRowName   => __('thin client option'),
                    # Notify when there are changes in ranges and
                    # fixed addresses from the same interface
                    notifyActions      => [ 'FixedAddressTable', 'RangeTable' ],
                   };

    return $dataTable;

}

1;
