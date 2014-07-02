# Copyright (C) 2013 Zentyal S.L.
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

# Class: EBox::SysInfo::Model::Debug
#
#   This model is used to enable/disable apport bug reports
#

use strict;
use warnings;

package EBox::SysInfo::Model::Debug;

use File::Slurp;

use EBox::Gettext;
use EBox::Types::Boolean;

use base 'EBox::Model::DataForm';

sub _table
{
    my ($self) = @_;

    my @tableHead = (new EBox::Types::Boolean(fieldName     => 'enabled',
                                              printableName => __('Enable bug report for daemon crashes'),
                                              editable      => 1,
                                              defaultValue  => 1));

    my $dataTable =
    {
        'tableName' => 'Debug',
        'printableTableName' => __('Debug'),
        'modelDomain' => 'SysInfo',
        'defaultActions' => [ 'editField' ],
        'tableDescription' => \@tableHead,
    };

    return $dataTable;
}

sub _formSubmitted
{
    EBox::Global->modChange('webadmin');
}

1;
