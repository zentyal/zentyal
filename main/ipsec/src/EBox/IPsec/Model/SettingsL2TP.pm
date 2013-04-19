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
package EBox::IPsec::Model::SettingsL2TP;
use base 'EBox::IPsec::Model::SettingsBase';

use strict;
use warnings;

use EBox::Gettext;

use EBox::Types::HostIP;

# Group: Public methods

# Method: validateTypedRow
#
#      Check the row to add or update if contains a valid configuration.
#
# Overrides:
#
#      <EBox::Model::DataTable::validateTypedRow>
#
# Exceptions:
#
#      <EBox::Exceptions::InvalidData> - thrown if the configuration is not valid.
#
sub validateTypedRow
{
    my ($self, $action, $changedFields) = @_;

    $self->SUPER::validateTypedRow(@_);

#    if ( exists $changedFields->{'ike-auth'} ) {
#        my $ikeenc = $changedFields->{'ike-enc'};
#        $ikeenc = $self->row()->valueByName('ike-enc') unless $ikeenc;
#        if ( $changedFields->{'ike-auth'}->value() eq 'any' and $ikeenc ne 'any') {
#                throw EBox::Exceptions::InvalidData(
#                          'data'  => __('IKE Authentication'),
#                          'value' => $changedFields->{'ike-auth'}->value(),
#                      );
#
#        }
#    }
}

# Group: Private methods

# Method: _table
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
sub _table
{
    my ($self) = @_;

    my $dataTable = $self->SUPER::_table(@_);

    my $field = new EBox::Types::HostIP(
        fieldName => 'localIP',
        printableName => __('Local IP'),
        editable => 1,
    );

    splice $dataTable->{tableDescription}, 0, 0, $field;
    $dataTable->{tableName} = 'SettingsL2TP';

    return $dataTable;
}

1;
