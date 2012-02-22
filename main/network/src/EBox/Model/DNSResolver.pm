# Copyright (C) 2008-2012 eBox Technologies S.L.
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

use EBox::Gettext;
use EBox::Global;
use EBox::Types::HostIP;

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

    my $helpHostIP = __('IP address of the DNS server that Zentyal'.
                        ' will use to resolve names.');
    my @tableDesc =
      (
       new EBox::Types::HostIP(
                               fieldName     => 'nameserver',
                               printableName => __('Domain Name Server'),
                               editable      => 1,
                               unique        => 1,
                               help          => $helpHostIP
                              ),
      );

    my $dataTable = {
                     tableName          => 'DNSResolver',
                     printableTableName => __('Domain Name Server Resolver List'),
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
    return (__('<p>Here you can add the name server resolvers that Zentyal will ' .
               'use.</p>' .
               '<p>Note that these settings may be overriden if you have any ' .
               'network interface configured via DHCP</p>'));
}

sub syncRows
{
    my ($self, $currentIds) = @_;

    my $modified = 0;
    my $dnsEnabled = 0;
    if (EBox::Global->modExists('dns')) {
        $dnsEnabled = EBox::Global->modInstance('dns')->isEnabled();
    }

    my $localResolver = undef;
    foreach my $id (@{$currentIds}) {
        my $row = $self->row($id);
        if (($row->valueByName('nameserver') eq '127.0.0.1') and $row->readOnly()) {
            $localResolver = $id;
            last;
        }
    }

    if ($dnsEnabled and (scalar @{$currentIds} > 0)) {
        my $firstRow = pop (@{$currentIds});
        return 0 if ($localResolver eq $firstRow);
    }

    if (defined $localResolver) {
        $self->removeRow($localResolver);
        $modified = 1;
    }

    if ($dnsEnabled) {
        $self->table->{'insertPosition'} = 'front';
        $self->addRow((nameserver => '127.0.0.1', readOnly => 1));
        $self->table->{'insertPosition'} = 'back';
        $modified = 1;
    }

    return $modified;
}

1;
