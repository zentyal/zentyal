# Copyright (C) 2010 eBox technologies S.L.
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
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA

# Class: EBox::Network::View::GatewayTableCustomizer
#
#   This class is used to override the EBox::View::Customizer method
#   that allows modification on the fields of the GatewayTable mode.
#   We make the interface field non-editable for automatic rows.
#
package EBox::Network::View::GatewayTableCustomizer;

use base 'EBox::View::Customizer';

use strict;
use warnings;

# Group: Public methods

# Method: initHTMLStateField
#
#   Given a field, it returns if the field has to be shown. hidden, or disabled
#
# Parameters:
#
#    (Positional)
#
#   fieldName - string containing the field name
#   fields - array ref of instancied types with their current values
#
# Returns:
#
#   One of these strings:
#
#          show
#          hide
#          disable
#
sub initHTMLStateField
{
    my ($self, $fieldName, $fields) = @_;

    # We look for the auto field when we are deciding the state of
    # the interface field, if auto = 1, the interface select is disabled
    # In any other case the method from the parent class is invoked

    if (defined($fieldName) and ($fieldName eq 'interface')) {
        foreach my $field (@{$fields}) {
            next unless $field->fieldName() eq 'auto';
            if ($field->value()) {
                return 'disable';
            } else {
                last;
            }
        }
    }

    return $self->SUPER::initHTMLStateField($fieldName, $fields);
}

1;
