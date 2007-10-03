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

# Class: EBox::Test::Model
#
#
#   This class is used as a model to refactoring <EBox::Types> as #690
#   shows
#
#   It subclasses <EBox::Model::DataTable>
#

package EBox::Test::Model;

use base 'EBox::Model::DataTable';

use strict;
use warnings;

## eBox uses
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
      my %params = @_;

      my $self = $class->SUPER::new(@_);
      bless($self, $class);

      $self->{runtimeIndex} = $params{runtimeIndex};

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
                                 'printableName' => __('Compulsory IP Address'),
                                 'class' => 'tcenter',
                                 'size' => '12',
                                 'editable' => 1,
                                 'optional' => 0,
                                ),
         new EBox::Types::IPAddr(
                                 'fieldName' => 'optional_addr',
                                 'printableName' => __('Optional IP Address'),
                                 'class' => 'tcenter',
                                 'size' => '12',
                                 'editable' => 1,
                                 'optional' => 1,
                                ),
         new EBox::Types::Boolean(
                                  'fieldName' => 'compulsory_boolean',
                                  'printableName' => __('Compulsory Boolean'),
                                  'class' => 'tcenter',
                                  'size' => '1',
                                  'editable' => 1,
                                  'optional' => 0,
                                ),
         new EBox::Types::Boolean(
                                  'fieldName' => 'optional_boolean',
                                  'printableName' => __('Optional Boolean'),
                                  'class' => 'tcenter',
                                  'size' => '1',
                                  'editable' => 1,
                                  'optional' => 1,
                                 ),
         new EBox::Types::Int(
                                  'fieldName' => 'compulsory_int',
                                  'printableName' => __('Compulsory Integer'),
                                  'class' => 'tcenter',
                                  'size' => '1',
                                  'editable' => 1,
                                  'optional' => 0,
                                ),
         new EBox::Types::Int(
                              'fieldName' => 'optional_int',
                              'printableName' => __('Optional Integer'),
                              'class' => 'tcenter',
                              'size' => '1',
                              'editable' => 1,
                              'optional' => 1,
                             ),
         new EBox::Types::Select(
                                 'fieldName' => 'compulsory_select',
                                 'printableName' => __('Compulsory Select'),
                                 'class' => 'tcenter',
                                 'size' => '1',
                                 'editable' => 1,
                                 'optional' => 0,
                                 'populate' => \&compulsoryOptionsCallback,
                                ),
#         new EBox::Types::Select(
#                                 'fieldName' => 'unique_select',
#                                 'printableName' => __('Unique Select'),
#                                 'class' => 'tcenter',
#                                 'size' => '1',
#                                 'editable' => 1,
#                                 'optional' => 1,
#                                 'populate' => \&optionalOptionsCallback,
#                                 'unique' => 1,
#                                 ),
#         new EBox::Types::Select(
#                                 'fieldName'     => 'foreign_select',
#                                 'printableName' => __('Foreign Select Object'),
#                                 'foreignModel'  => \&objectModelCallback,
#                                 'foreignField'  => 'name',
#                                 'class'         => 'tcenter',
#                                 'editable'      => 1,
#                                ),
         new EBox::Types::Text(
                               'fieldName' => 'compulsory_text',
                               'printableName' => __('Compulsory Text'),
                               'class' => 'tcenter',
                               'size' => '10',
                               'editable' => 1,
                               'optional' => 0,
                              ),
         new EBox::Types::Text(
                               'fieldName' => 'optional_text',
                               'printableName' => __('Optional Text'),
                               'class' => 'tcenter',
                               'size' => '10',
                               'editable' => 1,
                               'optional' => 1,
                              ),
         new EBox::Types::MACAddr(
                               'fieldName' => 'compulsory_mac',
                               'printableName' => __('Compulsory MAC Address'),
                               'class' => 'tcenter',
                               'size' => '10',
                               'editable' => 1,
                               'optional' => 0,
                              ),
         new EBox::Types::MACAddr(
                               'fieldName' => 'optional_mac',
                               'printableName' => __('Optional MAC address'),
                               'class' => 'tcenter',
                               'size' => '10',
                               'editable' => 1,
                               'optional' => 1,
                              ),
         new EBox::Types::Link(
                               'fieldName' => 'optional_link',
                               'printableName' => __('Optional Link'),
                               'class' => 'tcenter',
                               'size' => '1',
                               'optional' => 1,
                               'volatile' => 1,
                               'acquirer' => sub { return '/ebox/Summary/Index' },
                              ),
         new EBox::Types::Password(
                                   'fieldName' => 'compulsory_password',
                                   'printableName' => __('Compulsory Password'),
                                   'class' => 'tcenter',
                                   'size' => '10',
                                   'editable' => 1,
                                   'optional' => 0,
                                   'minLength' => 5,
                                   'maxLength' => 10,
                                  ),
         new EBox::Types::Password(
                                   'fieldName' => 'optional_password',
                                   'printableName' => __('Optional Password'),
                                   'class' => 'tcenter',
                                   'size' => '10',
                                   'editable' => 1,
                                   'optional' => 1,
                                   'maxLength' => 6,
                                  ),
         new EBox::Types::PortRange(
                                   'fieldName' => 'port_range',
                                   'printableName' => __('Port range'),
                                   'class' => 'tcenter',
                                   'size' => '5',
                                   'editable' => 1,
                                   'optional' => 0,
                                  ),
         new EBox::Types::Union(
                                'fieldName'     => 'union',
                                'printableName' => __('Union'),
                                'class'         => 'tcenter',
                                'size'          => 10,
                                'editable'      => 1,
                                'subtypes'      =>
                                [
                                 new EBox::Types::Text(
                                                       'fieldName' => 'foo',
                                                       'printableName' => __('Foo'),
                                                       'editable'      => 1,
                                                      ),
                                 new EBox::Types::PortRange(
                                                            'fieldName' => 'bar',
                                                            'printableName' => __('Bar'),
                                                            'editable'      => 1,
                                                           ),
                                 new EBox::Types::IPAddr(
                                                         'fieldName' => 'baz',
                                                         'printableName' => __('Baz'),
                                                         'editable' => 1,
                                                         ),
                                 new EBox::Types::Union::Text(
                                                              'fieldName' => 'others',
                                                              'printableName' => __('Other option'),
                                                             ),
                                ]
                               ),
         new EBox::Types::InverseMatchSelect(
                                             'fieldName' => 'inverse_select',
                                             'printableName' => __('Inverse Match Select'),
                                             'class' => 'tcenter',
                                             'size' => '11',
                                             'editable' => 1,
                                             'populate' => \&compulsoryOptionsCallback,
                                             'optional' => 0,
                                            ),
         new EBox::Types::InverseMatchUnion(
                                            'fieldName'     => 'inverse_union',
                                            'printableName' => __('Inverse Match Union'),
                                            'class'         => 'tcenter',
                                            'size'          => 10,
                                            'editable'      => 1,
                                            'subtypes'      =>
                                            [
                                             new EBox::Types::Text(
                                                                   'fieldName' => 'inverse_foo',
                                                                   'printableName' => __('Inverse Foo'),
                                                                   'editable'      => 1,
                                                                  ),
                                             new EBox::Types::PortRange(
                                                                        'fieldName' => 'inverse_bar',
                                                                        'printableName' => __('Inverse Bar'),
                                                                        'editable'      => 1,
                                                                       ),
                                             new EBox::Types::IPAddr(
                                                                     'fieldName' => 'inverse_baz',
                                                                     'printableName' => __('Inverse Baz'),
                                                                     'editable' => 1,
                                                                    ),
                                             new EBox::Types::Union::Text(
                                                                          'fieldName' => 'inverse_others',
                                                                          'printableName' => __('Inverse Other option'),
                                                                          'editable' => 1,
                                                                         ),
                                            ]
                                           ),
         new EBox::Types::HasMany(
                                  'fieldName'     => 'member',
                                  'printableName' => __('Members'),
                                  'foreignModel'  => 'MemberTable',
                                  'view'          => '/ebox/Objects/View/MemberTable',
                                  'backView'      => '/ebox/Test/View/TestTable',
                                  'size'          => 1,
                                 ),
         new EBox::Types::Service(
                                  'fieldName'     => 'compulsory_service',
                                  'printableName' => __('Compulsory Service'),
                                  'class'         => 'tcenter',
                                  'editable'      => 1,
                                 ),
        );

    my $dataTable =
        {
            'tableName' => 'TestTable',
            'printableTableName' => __('Test model'),
	    'defaultController' => '/ebox/Test/Controller/TestTable',
            'defaultActions' => [ 'add', 'del', 'editField', 'changeView' ],
            'tableDescription' => \@tableHead,
            'modelDomain' => 'Logs',
            'class' => 'dataTable',
            'order' => 0,
            'help' => __('Test model to test types'),
            'rowUnique' => 0,
            'printableRowName' => __('row'),
        };

    return $dataTable;
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

    return $self->{runtimeIndex} if ( defined ( $self->{runtimeIndex} ));
    return '';

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
              { value => 'a', printableValue => __('A') },
              { value => 'b', printableValue => __('B') },
              { value => 'c', printableValue => __('C') },
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

      if ( EBox::Global->modExists('objects') ) {
          return EBox::Global->modInstance('objects')->models()->[0];
      } else {
          return undef;
      }

  }

1;
