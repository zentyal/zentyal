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

# Class: EBox::Test::StaticForm
#
#   This class is used as an example for EBox::Model::DataForm
#
#   It subclasses <EBox::Model::DataForm>
#

package EBox::Test::StaticForm;

use base 'EBox::Model::DataForm::ReadOnly';

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
                                 'defaultValue' => '192.168.45.1/32',
                                ),
         new EBox::Types::Boolean(
                                  'fieldName' => 'compulsory_boolean',
                                  'printableName' => 'Compulsory Boolean',
                                  'defaultValue' => 1,
                                ),
         new EBox::Types::Int(
                              'fieldName' => 'compulsory_int',
                              'printableName' => 'Compulsory Integer',
                              'defaultValue' => 11,
                             ),
         new EBox::Types::Text(
                               'fieldName' => 'compulsory_text',
                               'printableName' => 'Compulsory Text',
                               'defaultValue' => 'foo',
                              ),
         new EBox::Types::MACAddr(
                               'fieldName' => 'compulsory_mac',
                               'printableName' => 'Compulsory MAC Address',
                               'defaultValue' => '00:0C:29:AD:B4:60',
                              ),
         new EBox::Types::Password(
                                   'fieldName' => 'compulsory_password',
                                   'printableName' => 'Compulsory Password',
                                   'minLength' => 5,
                                   'maxLength' => 10,
                                   'defaultValue' => 'foobar',
                                  ),
         new EBox::Types::PortRange(
                                    'fieldName' => 'port_range',
                                    'printableName' => 'Port range',
                                    'defaultValue' => '2132',
                                   ),
         new EBox::Types::Service(
                                  'fieldName'     => 'compulsory_service',
                                  'printableName' => 'Compulsory Service',
                                  'defaultValue'  => '1010/udp',
                                 ),
        );

    my $dataTable =
        {
            'tableName' => 'StaticTestForm',
            'printableTableName' => 'Read only test form',
	    'defaultController' => '/ebox/Test/Controller/StaticTestForm',
            'defaultActions' => [ 'changeView' ],
            'tableDescription' => \@tableHead,
            'modelDomain' => 'Logs',
            'class' => 'dataForm',
            'help' => 'Static test form',
        };

    return $dataTable;
}

# Method: _content
#
# Overrides:
#
#     <EBox::Model::DataForm::ReadOnly::_content>
#
sub _content
{
    return {
            compulsory_addr     => '10.0.0.0/24',
            compulsory_boolean  => 0,
            compulsory_int      => 12,
            compulsory_text     => 'bar',
            compulsory_service  => 'icmp',
            compulsory_mac      => '00:00:00:FA:BA:DA',
            compulsory_password => 'fabada',
            port_range          => '20:2000',
           };
}

1;
