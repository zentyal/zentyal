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

use strict;
use warnings;

# Class: EBox::Samba::Model::GPOScriptsLogin
#
#
package EBox::Samba::Model::GPOScriptsLogin;

use base 'EBox::Samba::Model::GPOScripts';

use EBox::Gettext;

sub _table
{
    my ($self) = @_;

    my $dataTable = $self->SUPER::_table();
    $dataTable->{tableName}          = 'GPOScriptsLogin',
    $dataTable->{printableTableName} = __('Login Scripts'),
    $dataTable->{printableRowName}   = __('login script'),
    return $dataTable;
}

1;
