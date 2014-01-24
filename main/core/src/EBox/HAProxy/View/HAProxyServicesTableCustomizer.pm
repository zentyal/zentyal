# Copyright (C) 2014 Zentyal S.L.
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
use strict;
use warnings;

# Class: EBox::HAProxy::View::HAProxyServicesTableCustomizer
#
#   This class is used to override the EBox::View::Customizer method
#   that allows modification on the fields of the HAProxyServices model.
#   We make the port edition blocked per row based on its settings.
#
package EBox::HAProxy::View::HAProxyServicesTableCustomizer;
use base 'EBox::View::Customizer';

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

    if (defined $fieldName) {
        if (($fieldName eq 'port') or ($fieldName eq 'defaultPort')) {
            foreach my $field (@{$fields}) {
                next unless $field->fieldName() eq 'blockPort';
                if ($field->value()) {
                    return 'disable';
                } else {
                    last;
                }
            }
        } elsif (($fieldName eq 'sslPort') or ($fieldName eq 'defaultSSLPort')) {
            foreach my $field (@{$fields}) {
                next unless $field->fieldName() eq 'blockSSLPort';
                if ($field->value()) {
                    return 'disable';
                } else {
                    last;
                }
            }
        }
    }

    return $self->SUPER::initHTMLStateField($fieldName, $fields);
}

1;
