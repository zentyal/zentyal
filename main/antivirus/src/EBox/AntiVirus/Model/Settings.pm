# Copyright (C) 2018 Zentyal S.L.
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

# Class: EBox::Antivirus::Model::Settings
#

use strict;
use warnings;

package EBox::AntiVirus::Model::Settings;

use base 'EBox::Model::DataForm';

use EBox::Gettext;
use EBox::Types::Boolean;

# Method: _table
#
#       Overrides <EBox::Model::DataForm::_table to change its name
#
sub _table
{
    my ($self) = @_;
    my $users = $self->parentModule();
    my @tableDesc = ();

    push (@tableDesc,
            new EBox::Types::Boolean(
                fieldName => 'onAccess',
                printableName => __('Enable On-Access Prevention'),
                defaultValue => 0,
                editable => 1,
                help => __('Deny access to infected files in the included paths above.')
                )
         );

    my $dataForm = {
        tableName           => 'Settings',
        printableTableName  => __('On-Access Scan'),
        defaultActions      => [ 'editField', 'changeView' ],
        tableDescription    => \@tableDesc,
        modelDomain         => 'AntiVirus',
    };

    return $dataForm;
}

1;
