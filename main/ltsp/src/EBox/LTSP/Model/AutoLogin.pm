# Copyright (C) 2012-2013 Zentyal S.L.
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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

# Class: EBox::LTSP::Model::AutoLogin
#
#   TODO: Document class
#

use strict;
use warnings;

package EBox::LTSP::Model::AutoLogin;

use base 'EBox::Model::DataTable';

use EBox::Gettext;
use EBox::Validate qw(:all);

use EBox::Types::MACAddr;
use EBox::Types::Text;
use EBox::Types::Password;

sub new
{
        my $class = shift;
        my %parms = @_;

        my $self = $class->SUPER::new(@_);
        bless($self, $class);

        return $self;
}

sub _table
{

    my @fields =
    (
        new EBox::Types::MACAddr(
            'fieldName' => 'mac',
            'printableName' => __('Client MAC'),
#            'unique' => 1,
            'editable' => 1,
        ),
        new EBox::Types::Text(
            'fieldName' => 'user',
            'printableName' => __('User'),
#            'unique' => 1,
            'editable' => 1,
        ),
        new EBox::Types::Password(
            'fieldName' => 'password',
            'printableName' => __('Password'),
            'confirmPrintableName' => __('Confirm Password'),
            'editable' => 1,
            'confirm' => 1,
        ),
    );

    my $dataTable =
    {
        'tableName' => 'AutoLogin',
        'printableTableName' => __('AutoLogin'),
        'printableRowName' => __('user and pass'),
        'modelDomain' => 'LTSP',
        'defaultActions' => ['add', 'del', 'editField', 'changeView' ],
        'tableDescription' => \@fields,
        'sortedBy' => 'mac',
        'enableProperty' => 1,
        'defaultEnabledValue' => 1,
        'help' => __('This configuration is only useful when \'AutoLogin\' '
                     . 'or \'Guest Login\' is enabled for the client.'),
    };

    return $dataTable;
}

1;
