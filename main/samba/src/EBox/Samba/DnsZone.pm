# Copyright (C) 2013 eBox Technologies S.L.
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

package EBox::Samba::DnsZone;

use EBox::Global;
use EBox::Exceptions::MissingArgument;
use EBox::Samba::DnsNode;

sub new
{
    my ($class, %params) = @_;

    throw EBox::Exceptions::MissingArgument('entry')
        unless defined $params{entry};

    my $self = {};
    bless ($self, $class);
    $self->{entry} = $params{entry};
    return $self;
}

sub name
{
    my ($self) = @_;

    return $self->{entry}->get_value('name');
}

sub nodes
{
    my ($self) = @_;

    my $nodes = [];
    my $ldb = EBox::Global->modInstance('samba')->ldb();
    my $result = $ldb->search({base => $self->{entry}->dn(),
                              scope => 'sub',
                              filter => '(objectClass=dnsNode)',
                              attrs => ['*']});
    foreach my $entry ($result->entries()) {
        push (@{$nodes}, new EBox::Samba::DnsNode(entry => $entry));
    }
    return $nodes;
}

1;
