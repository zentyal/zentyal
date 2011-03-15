# Copyright (C) 2008-2010 eBox Technologies S.L.
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
#

#
package EBox::OpenVPN::Model::ExposedNetworks;
use base 'EBox::Model::DataTable';

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Exceptions::External;
use EBox::Exceptions::DataExists;

use EBox::Types::IPAddr;

# Group: Public methods

sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

sub name
{
    __PACKAGE__->nameFromClass(),
}

# Group: Protected methods

sub _table
{
    my @tableHead =
        (
          new EBox::Types::IPAddr(
                                     fieldName => 'network',
                                     printableName => __('Advertised network'),
                                     unique => 1,
                                     editable => 1,
                                    ),
          );

    my $dataTable =
        {
            'tableName'              => __PACKAGE__->name(),
            'printableTableName' => __('List of Advertised Networks'),
            'automaticRemove' => 1,
            'defaultController' => '/ebox/OpenVPN/Controller/ExposedNetworks',
            'defaultActions' => ['add', 'del', 'editField',  'changeView' ],
            'tableDescription' => \@tableHead,
            'class' => 'dataTable',
            'printableRowName' => __('Advertised network'),
            'sortedBy' => 'network',
            'modelDomain' => 'OpenVPN',
            'help'  => _help(),
        };

    return $dataTable;
}



sub validateTypedRow
{
    my ($self, $action, $changedFields) = @_;

    if (not exists $changedFields->{network}) {
        return;
    }

    my $net = $changedFields->{network}->printableValue();
    my $serverConf = 
  $self->parentRow()->elementByName('configuration')->foreignModelInstance();
    my $vpn = $serverConf->row()->elementByName('vpn')->printableValue();

    if ($net eq $vpn) {
        throw EBox::Exceptions::External(
__('The advertised network address could not be the same than the VPN address' )
                                        );
    }

}



# Method: pageTitle
#
#   Overrides <EBox::Model::DataTable::pageTitle>
#   to show the name of the domain
sub pageTitle
{
        my ($self) = @_;

        return $self->parentRow()->printableValueByName('name');
}


# Group: Private methods

# Return the help message
sub _help
{
    return __x('{openpar}You can add here those networks which you want to make ' .
              'available to clients connecting to this VPN.{closepar}' .
              '{openpar}Typically, you will allow access to your LAN by advertising' .
              ' its network address here{closepar}',
              openpar => '<p>', closepar => '</p>');
}

1;
