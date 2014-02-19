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

# Class:
#
#   <EBox::DNS::Model::Record>
#
#   This class inherits from <EBox::Model::DataTable> and represents
#   the record with the common methods used by several records in DNS
#
use strict;
use warnings;

package EBox::DNS::Model::Record;

use base 'EBox::Model::DataTable';

use EBox::Exceptions::NotImplemented;
use TryCatch::Lite;

# Method: pageTitle
#
# Overrides:
#
#     <EBox::Model::Component::pageTitle>
#
sub pageTitle
{
    my ($self) = @_;

    my $row = $self->parentRow();
    my $parentModel = $row->model();
    if ($parentModel->isa('EBox::DNS::Model::Record')) {
        $row = $row->parentRow();
    }

    return $row->printableValueByName('domain');
}

# Group: Protected methods

# Method: _table
#
# Overrides:
#
#     <EBox::Model::DataForm::_table>
#
sub _table
{
    throw EBox::Exceptions::NotImplemented('_table', __PACKAGE__);
}

# Group: Private methods

# Add the RR to the deleted list
sub _addToDelete
{
    my ($self, $zone, $record) = @_;

    # TODO Do nothing if domain is not dynamic
    my $mod = $self->{confmodule};
    my $key = EBox::DNS::DELETED_RR_KEY();

    my $data = $mod->st_get($key, {});
    $data->{$zone} = [] unless exists $data->{$zone};
    push (@{$data->{$zone}}, $record);
    $mod->st_set($key, $data);
}

1;