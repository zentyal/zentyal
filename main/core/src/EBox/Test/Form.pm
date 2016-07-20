# Copyright (C) 2007 Warp Networks S.L.
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

# Class: EBox::Test::Form
#
#   This class is used as an example for EBox::Model::DataForm
#
#   It subclasses <EBox::Model::DataForm>
#

use strict;
use warnings;

package EBox::Test::Form;

use base 'EBox::Model::DataForm';

use EBox::Gettext;
use EBox::Types::Boolean;
use EBox::Types::HasMany;
use EBox::Types::Int;
use EBox::Types::InverseMatchSelect;
use EBox::Types::InverseMatchUnion;
use EBox::Types::IPAddr;
use EBox::Types::Link;
use EBox::Types::MACAddr;
use EBox::Types::Password;
use EBox::Types::PortRange;
use EBox::Types::Select;
use EBox::Types::Service;
use EBox::Types::Text;
use EBox::Types::Union;
use EBox::Types::Union::Text;

sub new
  {
      my $class = shift;
      my %parms = @_;

      my $self = $class->SUPER::new(@_);
      bless($self, $class);

      return $self;
  }

# Method:  _table
#
# This method overrides <EBox::Model::DataTable::_table> to return
# a table model description.
#
sub _table
{
    my @tableHead =
        (
         new EBox::Types::IPAddr(
                                 'fieldName' => 'compulsory_addr',
                                 'printableName' => 'Compulsory IP Address',
                                 'class' => 'tcenter',
                                 'size' => '12',
                                 'editable' => 1,
                                 'optional' => 0,
                                 'defaultValue' => '192.168.45.1/32',
                                ),
         new EBox::Types::Boolean(
                                  'fieldName' => 'compulsory_boolean',
                                  'printableName' => 'Compulsory Boolean',
                                  'class' => 'tcenter',
                                  'size' => '1',
                                  'editable' => 1,
                                  'optional' => 0,
                                  'defaultValue' => 1,
                                ),
         new EBox::Types::Int(
                              'fieldName' => 'compulsory_int',
                              'printableName' => 'Compulsory Integer',
                              'class' => 'tcenter',
                              'size' => '1',
                              'editable' => 1,
                              'optional' => 0,
                              'defaultValue' => 11,
                             ),
         new EBox::Types::Select(
                                 'fieldName' => 'compulsory_select',
                                 'printableName' => 'Compulsory Select',
                                 'class' => 'tcenter',
                                 'size' => '1',
                                 'editable' => 1,
                                 'populate' => \&compulsoryOptionsCallback,
                                 'defaultValue' => 'b',
                                ),
         new EBox::Types::Text(
                               'fieldName' => 'compulsory_text',
                               'printableName' => 'Compulsory Text',
                               'class' => 'tcenter',
                               'size' => '10',
                               'editable' => 1,
                               'optional' => 0,
                               'defaultValue' => 'foo',
                              ),
         new EBox::Types::MACAddr(
                               'fieldName' => 'compulsory_mac',
                               'printableName' => 'Compulsory MAC Address',
                               'class' => 'tcenter',
                               'size' => '10',
                               'editable' => 1,
                               'optional' => 0,
                               'defaultValue' => '00:0C:29:AD:B4:60',
                              ),
         new EBox::Types::Password(
                                   'fieldName' => 'compulsory_password',
                                   'printableName' => 'Compulsory Password',
                                   'class' => 'tcenter',
                                   'size' => '10',
                                   'editable' => 1,
                                   'optional' => 0,
                                   'minLength' => 5,
                                   'maxLength' => 10,
                                   'defaultValue' => 'foobar',
                                  ),
         new EBox::Types::PortRange(
                                   'fieldName' => 'port_range',
                                   'printableName' => 'Port range',
                                   'class' => 'tcenter',
                                   'size' => '5',
                                   'editable' => 1,
                                   'optional' => 0,
                                    'defaultValue' => '2132',
                                  ),
         new EBox::Types::Union(
                                'fieldName'     => 'union',
                                'printableName' => 'Union',
                                'class'         => 'tcenter',
                                'size'          => 10,
                                'editable'      => 1,
                                'subtypes'      =>
                                [
                                 new EBox::Types::Text(
                                                       'fieldName' => 'foo',
                                                       'printableName' => 'Foo',
                                                       'editable'      => 1,
                                                      ),
                                 new EBox::Types::PortRange(
                                                            'fieldName' => 'bar',
                                                            'printableName' => 'Bar',
                                                            'editable'      => 1,
                                                            'defaultValue'  => '2000:2001',
                                                           ),
                                 new EBox::Types::IPAddr(
                                                         'fieldName' => 'baz',
                                                         'printableName' => 'Baz',
                                                         'editable' => 1,
                                                         ),
                                 new EBox::Types::Union::Text(
                                                              'fieldName' => 'others',
                                                              'printableName' => 'Other option',
                                                             ),
                                ]
                               ),
         new EBox::Types::InverseMatchSelect(
                                             'fieldName' => 'inverse_select',
                                             'printableName' => 'Inverse Match Select',
                                             'class' => 'tcenter',
                                             'size' => '11',
                                             'editable' => 1,
                                             'populate' => \&compulsoryOptionsCallback,
                                             'optional' => 0,
                                             'defaultValue' => 'c',
                                            ),
         new EBox::Types::InverseMatchUnion(
                                            'fieldName'     => 'inverse_union',
                                            'printableName' => 'Inverse Match Union',
                                            'class'         => 'tcenter',
                                            'size'          => 10,
                                            'editable'      => 1,
                                            'subtypes'      =>
                                            [
                                             new EBox::Types::Text(
                                                                   'fieldName' => 'inverse_foo',
                                                                   'printableName' => 'Inverse Foo',
                                                                   'editable'      => 1,
                                                                  ),
                                             new EBox::Types::PortRange(
                                                                        'fieldName' => 'inverse_bar',
                                                                        'printableName' => 'Inverse Bar',
                                                                        'editable'      => 1,
                                                                        'defaultValue'  => '19201',
                                                                       ),
                                             new EBox::Types::IPAddr(
                                                                     'fieldName' => 'inverse_baz',
                                                                     'printableName' => 'Inverse Baz',
                                                                     'editable' => 1,
                                                                    ),
                                             new EBox::Types::Union::Text(
                                                                          'fieldName' => 'inverse_others',
                                                                          'printableName' => 'Inverse Other option',
                                                                          'editable' => 1,
                                                                         ),
                                            ]
                                           ),
         new EBox::Types::Service(
                                  'fieldName'     => 'compulsory_service',
                                  'printableName' => 'Compulsory Service',
                                  'class'         => 'tcenter',
                                  'editable'      => 1,
                                  'defaultValue'  => '1010/udp',
                                 ),
        );

    my $dataTable =
        {
            'tableName' => 'TestForm',
            'printableTableName' => 'Test form',
	    'defaultController' => '/Test/Controller/TestForm',
            'defaultActions' => [ 'editField', 'changeView' ],
            'tableDescription' => \@tableHead,
            'modelDomain' => 'Logs',
            'class' => 'dataForm',
            'help' => 'Test form to test types',
        };

    return $dataTable;
}

# Callback functions:

# Function: compulsoryOptionsCallback
#
#     Get the options for the compulsory_select field
#
# Returns:
#
#     array ref - containing hash ref with the following elements:
#                 - value
#                 - printableValue
#
sub compulsoryOptionsCallback
  {

      return [
              { value => 'a', printableValue => 'A' },
              { value => 'b', printableValue => 'B' },
              { value => 'c', printableValue => 'C' },
             ];

  }

# Function: optionalOptionsCallback
#
#     Get the options for the optional_select field
#
# Returns:
#
#     array ref - containing hash ref with the following elements:
#                 - value
#                 - printableValue
#
sub optionalOptionsCallback
  {

      return [
              { value => '1', printableValue => 1 },
              { value => '2', printableValue => 2 },
              { value => '5', printableValue => 5 },
             ];

  }

# Function: objectModelCallback
#
#     Get the object model to select one of the objects
#
# Returns:
#
#     <EBox::Model::DataTable> - the object model
#
sub objectModelCallback
  {

      return EBox::Global->modInstance('network')->models()->[0];

  }

1;
