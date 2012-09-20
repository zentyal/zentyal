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
use strict;
use warnings;

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

use EBox::Gettext;
use EBox::Global;
use EBox::Types::HostIP;
use EBox::Html;
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
                     noDataMsg          => ''
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


sub syncRowsDisabled
{
    my ($self) = @_;
    my $modified = 0;

    my $global = $self->global();
    if (not $global->modExists('dns')) {
        return $modified;
    }
    my $dns = $global->modInstance('dns');
    my $needLocalhost = $dns->isEnabled();
    my @localhostIds = @{ $self->findAll(nameserver => '127.0.0.1') };
    if ($needLocalhost and not @localhostIds) {
        $self->table->{'insertPosition'} = 'front';
        $self->addRow((nameserver => '127.0.0.1', readOnly => 1));
        $self->table->{'insertPosition'} = 'back';
        $modified = 1;
    } elsif (not $needLocalhost and @localhostIds) {
        my @removeIds = grep {
            my $row = $self->row($_);
            # read only rows has been added by us
            return $row->readOnly();
        } @localhostIds;
        foreach my $id (@removeIds) {
            $self->removeRow($id, 1);
            $modified = 1;
        }
    }

    return $modified;
}

sub replace
{
    my ($self, $pos, $newIP) = @_;
    my @ids = @{ $self->ids() };
    print "IDS @ids";
    if ($pos >= scalar @ids) {
        throw EBox::Exceptions::Internal("Inexistent DNS resolver position $pos");
    }

    my $id = $ids[$pos];
    my $row = $self->row($id);
    $row->elementByName('namserver')->setValue($newIP);
    $row->store();

}

sub _noResolversMessage
{
    my ($self) = @_;
    my $network = $self->parentModule();
    my @dhcpIfaces = grep {
        $network->ifaceMethod($_) eq 'dhcp'
    } @{ $network->allIfaces() };
    my ($search, @dns) = @{$network->_readResolv()};
    my $msg = EBox::Html::makeHtml('network/noDnsResolver.mas',
                                   dhcpIfaces => \@dhcpIfaces,
                                   search     => $search,
                                   dns        => \@dns

                                  );
    return $msg;
}

sub viewCustomizer
{
    my ($self) = @_;
    my $customizer = new EBox::View::Customizer();
    $customizer->setModel($self);
    unless ( $self->size() > 0) {
        $customizer->setPermanentMessage($self->_noResolversMessage());
    }
    return $customizer;
}

1;
