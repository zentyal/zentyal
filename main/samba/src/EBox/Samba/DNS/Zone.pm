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

package EBox::Samba::DNS::Zone;

use EBox::Global;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::Internal;
use EBox::Samba::DNS::Node;

sub new
{
    my ($class, %params) = @_;

    throw EBox::Exceptions::MissingArgument('entry | dn')
        unless defined $params{entry} or defined $params{dn};

    my $self = {};
    bless ($self, $class);
    if (defined $params{entry}) {
        $self->{entry} = $params{entry};
    } else {
        my $dn = $params{dn};
        my $ldap = EBox::Global->modInstance('samba')->ldap();
        my $params = {
            base => $dn,
            scope => 'base',
            filter => '(objectClass=dnsZone)',
            attrs => ['*']
        };
        my $res = $ldap->search($params);
        throw EBox::Exceptions::Internal("Zone $dn could not be found")
            unless ($res->count() > 0);
        throw EBox::Exceptions::Internal("Expected only one entry")
            unless ($res->count() == 1);
        $self->{entry} = $res->entry(0);
    }
    return $self;
}

sub dn
{
    my ($self) = @_;

    return $self->{entry}->dn();
}

sub name
{
    my ($self) = @_;

    my $name = $self->{entry}->get_value('name');
    $name = lc ($name) if $name;
    return $name;
}

sub nodes
{
    my ($self) = @_;

    my $nodes = [];
    my $ldap = EBox::Global->modInstance('samba')->ldap();
    my $result = $ldap->search({base => $self->{entry}->dn(),
                              scope => 'sub',
                              filter => '(objectClass=dnsNode)',
                              attrs => ['*']});
    foreach my $entry ($result->entries()) {
        push (@{$nodes}, new EBox::Samba::DNS::Node(entry => $entry));
    }
    return $nodes;
}

1;
