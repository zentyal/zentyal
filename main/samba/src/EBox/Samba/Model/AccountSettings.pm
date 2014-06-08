# Copyright (C) 2011-2013 Zentyal S.L.
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

# Class: EBox::Samba::Model::AccountSettings
#
#   This model is used to configure the default settings of the user accounts
#

use strict;
use warnings;

package EBox::Samba::Model::AccountSettings;

use base 'EBox::Model::DataForm';

use EBox::Gettext;
use EBox::Global;
use EBox::Types::Int;
use EBox::Types::Select;
use EBox::Types::Union;
use EBox::Types::Union::Text;

use constant DEFAULTQUOTA => 500;

sub new
{
    my ($class, %params) = @_;

    my $self = $class->SUPER::new(%params);
    bless($self, $class);

    return $self;
}

sub _table
{
    my @tableDescription = (
        new EBox::Types::Union(
            'fieldName' => 'defaultQuota',
            'printableName' => __('Default user quota'),
            'subtypes' => [
                new EBox::Types::Int(
                    'fieldName' => 'defaultQuota_size',
                    'printableName' => __('Limited to'),
                    'defaultValue' => DEFAULTQUOTA,
                    'trailingText' => __('Mb'),
                    'size' => 7,
                    'editable' => 1,
                ),
                new EBox::Types::Union::Text(
                    'fieldName' => 'defaultQuota_disabled',
                    'printableName' => __('Disabled'),
                ),
            ],
        ),
    );

    my $dataTable = {
        'tableName' => 'AccountSettings',
        'printableTableName' => __('Default account settings'),
        'modelDomain' => 'Samba',
        # FIXME: what default actions should be used?
        'defaultActions' => [ 'editField', 'changeView' ],
        'tableDescription' => \@tableDescription,
        'help' => __('On this page you can configure the default settings ' .
            'for user accounts'),
    };

    return $dataTable;
}

sub formSubmitted
{
    my ($self) = @_;
    my $row = $self->row();

    my $defaultQuota = $row->elementByName('defaultQuota');
    if ($defaultQuota->selectedType() eq 'defaultQuota_size') {
        my $value = $defaultQuota->value();
        if ($value == 0) {
            $self->setMessage(
__('Setting default quota to zero is equivalent to disable it')
               );
        }
    }
}

1;
