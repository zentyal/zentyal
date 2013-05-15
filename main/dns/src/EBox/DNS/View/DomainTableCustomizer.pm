# Copyright (C) 2010-2013 Zentyal S.L.
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

# Class: EBox::DNS::View::GatewayTableCustomizer
#
#   This class is used to override the EBox::View::Customizer method
#   that allows modification on the fields of the DomainTable mode.
#
#   We hide the dynamic attribute in add new form
#
use strict;
use warnings;

package EBox::DNS::View::DomainTableCustomizer;

use base 'EBox::View::Customizer';

# Group: Public methods

# Method: initHTMLStateField
#
#   Given a field, it returns if the field has to be shown. hidden, or disabled
#   TODO This method should be deleted when the hiddenOnSetter attribute of the
#        domain field will work ok
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

    if (defined($fieldName) and ($fieldName eq 'type')) {
        return 'hide';
    } else {
        return $self->SUPER::initHTMLStateField($fieldName, $fields);
    }

}

1;
