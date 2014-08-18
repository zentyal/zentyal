# Copyright
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

package EBox::Radius::Model::Clients;

use base 'EBox::Model::DataTable';

# Class: EBox::Radius::Model::Clients
#
#   TODO: Document class
#

use EBox::Gettext;
use EBox::Types::Text;
use EBox::Types::IPAddr;
use EBox::Types::Password;

# Group: Public methods

# Constructor: new
#
#       Create the new Clients model
#
# Overrides:
#
#       <EBox::Model::DataForm::new>
#
# Returns:
#
#       <EBox::Radius::Model::Clients> - the recently created model
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless($self, $class);

    return $self;
}

# Method: getClients
#
#      Returns the enabled RADIUS clients
#
# Returns:
#
#      array - to ref hash clients
#
sub getClients
{
    my ($self) = @_;

    my @clients = ();

    foreach my $id (@{$self->enabledRows()}) {

        my $row = $self->row($id);

        my %client=();

	$client{'name'} = $row->valueByName('name');
        $client{'secret'} = $row->valueByName('secret');
        $client{'ipaddr'} = $row->printableValueByName('ipaddr');
        push (@clients, \%client);

    }

    return \@clients;
}

# Group: Private methods

# Method: _table
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
sub _table
{

    my @tableHeader =
        (
         new EBox::Types::Text(
                                   fieldName => 'name',
                                   printableName => __('Client'),
                                   size => 12,
                                   unique => 1,
                                   editable => 1,
                              ),
         new EBox::Types::IPAddr(
                                   fieldName => 'ipaddr',
                                   printableName => __('IP Address'),
                                   unique => 1,
                                   editable => 1,
                                ),
         new EBox::Types::Password(
                                   fieldName => 'secret',
                                   printableName => __('Shared Secret'),
                                   editable => 1,
                                  ),
        );

    my $dataTable =
    {
        tableName => 'Clients',
        printableTableName => __('RADIUS Clients'),
        printableRowName => __('client'),
        defaultActions => ['add', 'del', 'editField', 'changeView' ],
        tableDescription => \@tableHeader,
        class => 'dataTable',
        modelDomain => 'Radius',
        enableProperty => 1,
        defaultEnabledValue => 1,
    };

    return $dataTable;
}

1;
