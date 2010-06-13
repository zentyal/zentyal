# Copyright (C) 2009-2010 eBox Technologies S.L.
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

# Class: EBox::EGroupware::Model::PermissionTemplates
#
#   TODO: Document class
#

package EBox::EGroupware::Model::PermissionTemplates;

use EBox::Gettext;
use EBox::Validate qw(:all);
use Error qw(:try);

use EBox::Types::Text;
use EBox::Types::HasMany;
use EBox::Config;
use EBox::Sudo;
use EBox::Exceptions::External;

use strict;
use warnings;

use base 'EBox::Model::DataTable';


sub new
{
        my $class = shift;
        my %parms = @_;

        my $self = $class->SUPER::new(@_);
        bless($self, $class);

        return $self;
}

# Method: headTitle
#
#   Override <EBox::Model::DataTable::headTitle>
sub headTitle
{
    return undef;
}


sub _table
{

    my @tableHead =
    (
        new EBox::Types::Text(
            'fieldName' => 'name',
            'printableName' => __('Name'),
            'unique' => 1,
            'editable' => 1,
        ),
        new EBox::Types::HasMany(
            'fieldName' => 'applications',
            'printableName' => __('Allowed Applications'),
            'foreignModel' => 'Applications',
            'view' => '/ebox/EGroupware/View/Applications',
        ),
    );

    my $dataTable =
    {
        'tableName' => 'PermissionTemplates',
        'printableTableName' => __('User Defined Permission Templates'),
        'modelDomain' => 'EGroupware',
        'defaultActions' => [ 'add', 'del', 'editField', 'changeView' ],
        'tableDescription' => \@tableHead,
        'printableRowName' => __('template'),
        'help' => __('Edit the permission templates with the allowed applications that can be assigned to users or groups.'),
    };

    return $dataTable;
}

1;
