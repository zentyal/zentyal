# Copyright (C) 2017 Zentyal S.L.
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

package EBox::SysInfo::Model::Edition;

# Class: EBox::SysInfo::Model::Edition
#
#     Model to perform all operations related to subscription
#

use base 'EBox::Model::DataForm';

use EBox::Gettext;
use EBox::Types::Text;
use EBox::Exceptions::External;

sub _table
{
    my ($self) = @_;

    my @tableHead = (new EBox::Types::Text( fieldName     => 'key',   # TODO: 4 separate fields for more usability?
                                            printableName => __('License Key'),
                                            size          => 24,
                                            editable      => 1));

    my $dataTable =
    {
        'tableName' => 'Edition',
        'printableTableName' => __('License Validation'),
        'printableActionName' => __('Validate'),
        'modelDomain' => 'SysInfo',
        'defaultActions' => [ 'editField' ],
        'tableDescription' => \@tableHead,
    };

    return $dataTable;
}

sub validateTypedRow
{
    my ($self, $action, $changed, $all) = @_;

    my $key = defined $changed->{key} ? $changed->{key}->value() : $all->{key}->value();
    EBox::Sudo::silentRoot("wget --user=$key --password=lk archive.zentyal.com/zentyal-qa/ -O- | grep Index");
    if ($? != 0) {
        throw EBox::Exceptions::External(__("License key cannot be validated. Please try again or check your Internet connection."));
    }
}

sub updatedRowNotify
{
    my ($self, $row, $oldRow, $force) = @_;
    if ($row->isEqualTo($oldRow)) {
        return;
    }

    my $key = $self->row->valueByName('key');

    EBox::Sudo::root("echo '$key' > /var/lib/zentyal/.license");
    EBox::Global->modInstance('webadmin')->setAsChanged();
}

1;
