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
use strict;
use warnings;

package EBox::OpenVPN::Model::ClientExposedNetworks;

use base 'EBox::OpenVPN::Model::ExposedNetworks';

use EBox::Gettext;

sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

sub _table
{
    my ($self) = @_;

    my $tableHead = $self->_tableHead();

    my $dataTable =
        {
            'tableName'              => 'ClientExposedNetworks',
            'printableTableName' => __('List of advertised networks to tunnel server'),
            'automaticRemove' => 1,
            'defaultController' => '/OpenVPN/Controller/ClientExposedNetworks',
            'defaultActions' => ['add', 'del', 'editField',  'changeView' ],
            'tableDescription' => $tableHead,
            'class' => 'dataTable',
            'printableRowName' => __('Advertised network'),
            'sortedBy' => 'object',
            'modelDomain' => 'OpenVPN',
            'help'  => _help(),
        };

    return $dataTable;
}

sub _help
{
    return __x('{openpar}You can add here those networks which you want to make ' .
              'available to clients connecting to this VPN.{closepar}' .
              '{openpar}Typically, you will allow access to your LAN by advertising' .
              ' its network address here.{closepar}' .
              '{openpar}If an advertised network address is the same as the VPN' .
              ' network address, the advertised network will be ignored.{closepar}',
              openpar => '<p>', closepar => '</p>');
}

sub precondition
{
    my ($self) = @_;
    return not $self->_tun();
}

sub preconditionFailMsg
{
    return __('Advestised routes for clients over a TUN interface are not supported');
}

# Method: networks
#
#   overrided to not use advertised networks for clients over TUN
#
# Overrides:
#
#     <EBox::OpenVPN::Model::ExposedNetworksBase::networks>
#
sub networks
{
    my ($self) = @_;
    # for now is not supported for TUN tunnels
    if ($self->_tun()) {
        return [];
    }

    return $self->SUPER::networks(1);
}

sub _tun
{
    my ($self) = @_;
    my $configuration = $self->parentRow()->subModel('configuration');
    return $configuration->value('tunInterface');
}

1;
