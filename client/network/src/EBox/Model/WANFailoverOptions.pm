# Copyright (C) 2009 eBox Technologies S.L.
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

package EBox::Network::Model::WANFailoverOptions;

use base 'EBox::Model::DataForm';

use strict;
use warnings;

# eBox uses
use EBox::Gettext;
use EBox::Global;
use EBox::Types::Int;

# Dependencies

# Group: Public methods

# Constructor: new
#
#     Create the DynDNS model
#
# Overrides:
#
#     <EBox::Model::DataForm::new>
#
# Returns:
#
#     <EBox::Network::Model::WANFailoverOptions>
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
       new EBox::Types::Int(
           'fieldName'     => 'period',
           'printableName' => __('Time between checks'),
           'trailingText'  => __('seconds'),
           'defaultValue'  => 30,
           'size'          => 3,
           'min'           => 10,
           'editable'      => 1,
           ),
      );

      my $dataTable = {
                       tableName          => 'WANFailoverOptions',
                       printableTableName => __('Global options'),
                       defaultActions     => [ 'editField', 'changeView' ],
                       tableDescription   => \@tableHeader,
                       class              => 'dataForm',
                       help               => __('These options affect to all the tests.'),
                       modelDomain        => 'Network',
                     };

      return $dataTable;

}

# Method: formSubmitted
#
#   Overrides <EBox::Model::DataForm::formSubmited>
#
sub formSubmitted
{
    # Notify period change to events module
    EBox::Global->getInstance()->modChange('events');
}

1;
