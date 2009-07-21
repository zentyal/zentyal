# Copyright (C) 2007 Warp Networks S.L.
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


package EBox::Asterisk::Model::NAT;

# Class: EBox::Asterisk::Model::NAT
#
#       Form to set the NAT configuration for the Asterisk server
#

use base 'EBox::Model::DataForm';

use strict;
use warnings;

use EBox::Gettext;
use EBox::Global;
use EBox::Types::Union;
use EBox::Types::Union::Text;
use EBox::Types::Host;
use EBox::Types::DomainName;

# Group: Public methods

# Constructor: new
#
#       Create the new NAT model
#
# Overrides:
#
#       <EBox::Model::DataForm::new>
#
# Returns:
#
#       <EBox::Asterisk::Model::NAT> - the recently created model
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless ( $self, $class );

    return $self;
}


# Method: getNATType
#
#  Returns:
#
sub getNATType
{
    my ($self) = @_;

    my $nat = $self->row()->elementByName('behindNAT');
    if ($nat->selectedType() eq 'no') {
        return undef;
    }

    my $type = $nat->selectedType();
    my $value = $nat->printableValue();
    return [$type, $value];
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

    my @tableHeader =
      (
       new EBox::Types::Union(
                                fieldName     => 'behindNAT',
                                printableName => __('eBox is behind NAT'),
                                editable      => 1,
                                subtypes => [
                                    new EBox::Types::Union::Text(
                                        fieldName => 'no',
                                        printableName => __('No'),
                                    ),
                                    new EBox::Types::Host(
                                        fieldName => 'fixedIP',
                                        printableName => 'Fixed IP address',
                                        editable => 1,
                                    ),
                                    new EBox::Types::DomainName(
                                        fieldName => 'dynamicHost',
                                        printableName => 'Dynamic hostname',
                                        editable => 1,
                                    ),
                                ]
                             ),
      );

    my $dataTable =
    {
        tableName          => 'NAT',
        printableTableName => __('NAT configuration'),
        defaultActions     => [ 'editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        class              => 'dataForm',
        help               => __("NAT Asterisk server configuration"),
        messages           => {
                                  update => __('NAT Asterisk server configuration updated'),
                              },
        modelDomain        => 'Asterisk',
    };

    return $dataTable;

}

1;
