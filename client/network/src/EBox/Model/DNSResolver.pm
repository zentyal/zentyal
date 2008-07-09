# Copyright (C) 2008 Warp Networks S.L.
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

# Class: EBox::Network::Model::DNSResolver
#
# This model configures the DNS resolvers for the host. It allows to
# set as many name servers as you want. The single field available is
# the following one:
#
#    - nameserver
#
package EBox::Network::Model::DNSResolver;

use base 'EBox::Model::DataTable';

use strict;
use warnings;

# eBox uses
use EBox::Gettext;
use EBox::Global;
use EBox::Types::IPAddr;
use EBox::Types::HostIP;
use EBox::Types::Text;

# Dependencies

# Group: Public methods

# Constructor: new
#
#     Create the new DNS resolver table
#
# Overrides:
#
#     <EBox::Model::DataTable::new>
#
# Returns:
#
#     <EBox::Network::Model::DNSResolver> - the newly created object
#     instance
#
sub new
{

      my ($class, %opts) = @_;
      my $self = $class->SUPER::new(%opts);
      bless ( $self, $class);

      return $self;

}

# Group: Protected methods

# Method: _table
#
# Overrides:
#
#     <EBox::Model::DataTable::_table>
#
sub _table
{
    my ($self) = @_;

    my $helpHostIP = __('IP address of the DNS server that eBox'.
                        ' will use to resolve names'); 
    my @tableDesc =
      (
       new EBox::Types::HostIP(
                               fieldName     => 'nameserver',
                               printableName => __('Name server'),
                               editable      => 1,
                               unique        => 1,
                               help          => $helpHostIP
                              ),
      );

    my $dataTable = {
                     tableName          => 'DNSResolver',
                     printableTableName => __('Name server resolver list'),
                     pageTitle          => __('Name server resolver'),
                     modelDomain        => 'Network',
                     defaultActions     => [ 'add', 'del', 'move', 'editField', 'changeView' ],
                     tableDescription   => \@tableDesc,
                     class              => 'dataTable',
                     help               => _help(), 
                     printableRowName   => __('name server'),
                     order              => 1,
                     insertPosition     => 'back',
                    };

      return $dataTable;


}

sub _help
{
    return (__('<p>Here you can add the name server resolvers that eBox will ' .
               'use.</p>' .
               '<p>Note that these settings may be overriden if you have any ' .
               'network interface configured via DHCP</p>'));
}

1;
