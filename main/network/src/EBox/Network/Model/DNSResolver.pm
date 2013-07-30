# Copyright (C) 2008-2013 Zentyal S.L.
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
use strict;
use warnings;

package EBox::Network::Model::DNSResolver;

use base 'EBox::Model::DataTable';

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

sub replace
{
    my ($self, $pos, $newIP) = @_;

    my @ids = @{ $self->ids() };
    if ($pos >= scalar @ids) {
        throw EBox::Exceptions::Internal("Inexistent DNS resolver position $pos");
    }

    my $id = $ids[$pos];
    my $row = $self->row($id);
    $row->elementByName('nameserver')->setValue($newIP);
    $row->store();

}

# Method: syncRows
#
#   Overrided to set localhost as primary nameserver if the DNS module is
#   enabled.  This works because DNS module modChange network in enableService
#
sub syncRows
{
    my ($self, $currentIds) = @_;
    my $global = $self->global();
    my $changed = 0;

    my $add = 0;

    my $firstId  = @{$currentIds}[0];
    my $firstRow = $self->row($firstId);

    # Set localhost as primary resolver if DNS is installed and enabled
    if ($global->modExists('dns')) {
        my $dnsModule = $global->modInstance('dns');
        $add = 1 if $dnsModule->isEnabled();
    }

    # Do not set readonly on primary resolver if users is configured to
    # authenticate users against external AD, the AD server must be used
    # as primary resolver instead localhost
    if ($global->modExists('users')) {
        my $users = $global->modInstance('users');
        if ($users->isEnabled()) {
            my $mode = $users->mode();
            if ($mode eq $users->EXTERNAL_AD_MODE()) {
                $add = 0;
            }
        }
    }

    unless ($add) {
        # Remove if it is configured as primary
        if (defined $firstRow and $firstRow->valueByName('nameserver') eq '127.0.0.1') {
            $self->removeRow($firstId);
            $changed = 1;
        }
    }

    if ($add and defined $firstRow and $firstRow->valueByName('nameserver') ne '127.0.0.1') {
        # First delete to avoid duplicated value exception
        foreach my $id (@{$currentIds}) {
            my $row = $self->row($id);
            if ($row->valueByName('nameserver') eq '127.0.0.1') {
                $self->removeRow($id);
                $changed = 1;
            }
        }
        $self->table->{'insertPosition'} = 'front';
        $self->addRow((nameserver => '127.0.0.1', readOnly => 1));
        $self->table->{'insertPosition'} = 'back';
        $changed = 1;
    }

    return $changed;
}

1;
