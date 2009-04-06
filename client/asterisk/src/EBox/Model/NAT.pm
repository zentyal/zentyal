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
#       Form to set the NAT configuration settings for the Asterisk server
#

use base 'EBox::Model::DataForm';

use strict;
use warnings;

use EBox::Gettext;
use EBox::Global;
use EBox::Types::HostIP;
use EBox::Types::Boolean;

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
       new EBox::Types::Boolean(
                                fieldName     => 'behindNAT',
                                printableName => __('Asterisk is behind NAT'),
                                editable      => 1,
                                defaultValue  => 0,
                               ),
       new EBox::Types::HostIP(
                                fieldName     => 'externalIP',
                                printableName => __('External IP address'),
                                editable      => 1,
                               ),
      );

    my $dataTable =
    {
        tableName          => 'NAT',
        printableTableName => __('NAT settings'),
        defaultActions     => [ 'editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        class              => 'dataForm',
        help               => __('NAT Asterisk server configuration'),
        messages           => {
                                  update => __('NAT Asterisk server configuration updated'),
                              },
        modelDomain        => 'Asterisk',
    };

    return $dataTable;

}

1;
