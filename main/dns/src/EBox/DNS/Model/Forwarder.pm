# Copyright (C) 2011-2013 Zentyal S.L.
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
#   <EBox::DNS::Model::Forwarder>
#
#   This class inherits from <EBox::Model::DataTable> and represents
#   the object table which consists of forwarders to forwards those
#   queries whose asked zone the server is not authorised. The single
#   field available is:
#
#     - forwarder
#
use strict;
use warnings;

package EBox::DNS::Model::Forwarder;

use base 'EBox::Model::DataTable';

use EBox::Global;
use EBox::Gettext;

use EBox::Types::HostIP;

# Group: Public methods

# Constructor: new
#
#      Create a new Text model instance
#
# Returns:
#
#      <EBox::DNS::Model::Forwarder> - the newly created model
#      instance
#
sub new
{
    my ($class, %params) = @_;

    my $self = $class->SUPER::new(%params);
    bless($self, $class);

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
    my ($self) = @_;

    my @tableDesc =
      (
          new EBox::Types::HostIP(
              fieldName     => 'forwarder',
              printableName => __('Forwarder'),
              editable      => 1,
              unique        => 1,
             ),
      );

    my $dataTable =
        {
            tableName => 'Forwarder',
            printableTableName => __('Forwarders'),
            modelDomain     => 'DNS',
            defaultActions => ['add', 'del', 'move', 'editField',  'changeView' ],
            tableDescription => \@tableDesc,
            class => 'dataTable',
            help => __('The server will send the queries to the forwarders first, '
                       . 'and if not answered it will attempt to answer the query.'),
            printableRowName => __('forwarder'),
            order => 1,
            insertPosition => 'back',
        };

    return $dataTable;
}

# Method: validateTypedRow
#
# Override to forbid adding loopback addresses to forwarder list
#
# Overrides:
#
#    <EBox::Model::DataTable::validateTypedRow>
#
sub validateTypedRow
{
    my ($self, $action, $changedFields, $allFields) = @_;

    return unless (exists $changedFields->{forwarder});

    my $forwarder = $changedFields->{forwarder}->value();
    if ($forwarder =~ m/^127\./) {
        throw EBox::Exceptions::External(
            __x('Forwarder cannot be a loopback address like {forw}',
                forw => $forwarder
               )
           );
    }
}

1;
