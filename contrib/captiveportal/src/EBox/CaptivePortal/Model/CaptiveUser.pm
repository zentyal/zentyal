# Copyright 2012-2013 Zentyal S.L.
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

# Class: EBox::CaptivePortal::Model::CaptiveUser
#
#   Model for Captive Portal user addon, it allows to configure
#   user quotas
#

use strict;
use warnings;

package EBox::CaptivePortal::Model::CaptiveUser;

use EBox::Gettext;
use EBox::Types::Boolean;
use EBox::Types::Int;

use base 'EBox::Model::DataForm';

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
    my @tableHead = (
            new EBox::Types::Union(
                fieldName => 'defaultQuota',
                printableName => __('Bandwidth quota'),
                help => __('Default external bandwidth usage limit'),
                subtypes => [
                    new EBox::Types::Union::Text(
                        fieldName => 'defaultQuota_default',
                        printableName => __('Use default'),
                    ),
                    new EBox::Types::Union::Text(
                        fieldName => 'defaultQuota_disabled',
                        printableName => __('No limit'),
                    ),
                    new EBox::Types::Int(
                        fieldName => 'defaultQuota_size',
                        printableName => __('Limited to'),
                        defaultValue => 1000,
                        trailingText => __('Mb'),
                        size => 7,
                        editable => 1,
                    ),
                ],
            ),
        );

    my $dataTable =
    {
        tableName => 'CaptiveUser',
        printableTableName => __('Captive Portal'),
        pageTitle => undef,
        modelDomain => 'CaptivePortal',
        defaultActions => [ 'editField', 'changeView' ],
        tableDescription => \@tableHead,
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
