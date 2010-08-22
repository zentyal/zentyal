# Copyright (C) 2010 eBox Technologies S.L.
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

package EBox::Network::Model::Proxy;

use base 'EBox::Model::DataForm';

use strict;
use warnings;

use EBox::Gettext;
use EBox::Global;
use EBox::Types::Host;
use EBox::Types::Port;

# Dependencies

# Group: Public methods

# Constructor: new
#
#     Create the Proxy model
#
# Overrides:
#
#     <EBox::Model::DataForm::new>
#
# Returns:
#
#     <EBox::Network::Model::Proxy>
#
sub new
{
      my $class = shift;

      my $self = $class->SUPER::new(@_);

      bless ( $self, $class );

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

    my @tableHeader =
      (
       new EBox::Types::Host(
           'fieldName'     => 'server',
           'printableName' => __('Proxy server'),
           'editable'      => 1,
           'optional'      => 1,
       ),
       new EBox::Types::Port(
           'fieldName'     => 'port',
           'printableName' => __('Proxy port'),
           'editable'      => 1,
           'optional'      => 1,
       ),
      );

      my $dataTable = {
                       tableName          => 'Proxy',
                       printableTableName => __('Proxy'),
                       defaultActions     => [ 'editField', 'changeView' ],
                       tableDescription   => \@tableHeader,
                       class              => 'dataForm',
                       help               => __('This settings will be used to allow '
                                               . 'Zentyal to access the Internet if an HTTP proxy '
                                               . 'is needed.'),
                       modelDomain        => 'Network',
                     };

      return $dataTable;
}

1;
