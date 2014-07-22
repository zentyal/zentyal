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

package EBox::Samba::FSMO;

use base 'EBox::Ldap';

use EBox::Exceptions::Internal;
use EBox::Sudo;
use Net::LDAP::Util qw(ldap_explode_dn canonical_dn);
use Net::Ping;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::instance();

    bless ($self, $class);
    return $self;
}

sub getInfrastructureMaster
{
    my ($self) = @_;

    my $rootDse = $self->rootDse();
    my $defaultNC = $rootDse->get_value('defaultNamingContext');
    my $params = {
        base => "CN=Infrastructure,$defaultNC",
        scope => 'base',
        filter => '(objectClass=*)',
        attrs => ['fSMORoleOwner'],
    };
    my $result = $self->search($params);
    if ($result->count() != 1) {
        throw EBox::Exceptions::Internal("Expected one entry");
    }
    my $entry = $result->entry(0);
    my $owner = $entry->get_value('fSMORoleOwner');
    return $owner;
}

sub getRidAllocationMaster
{
    my ($self) = @_;

    my $rootDse = $self->rootDse();
    my $defaultNC = $rootDse->get_value('defaultNamingContext');
    my $params = {
        base => "CN=RID Manager\$,CN=System,$defaultNC",
        scope => 'base',
        filter => '(objectClass=*)',
        attrs => ['fSMORoleOwner'],
    };
    my $result = $self->search($params);
    if ($result->count() != 1) {
        throw EBox::Exceptions::Internal("Expected one entry");
    }
    my $entry = $result->entry(0);
    my $owner = $entry->get_value('fSMORoleOwner');
    return $owner;
}

sub getPdcEmulationMaster
{
    my ($self) = @_;

    my $rootDse = $self->rootDse();
    my $defaultNC = $rootDse->get_value('defaultNamingContext');
    my $params = {
        base => "$defaultNC",
        scope => 'base',
        filter => '(objectClass=*)',
        attrs => ['fSMORoleOwner'],
    };
    my $result = $self->search($params);
    if ($result->count() != 1) {
        throw EBox::Exceptions::Internal("Expected one entry");
    }
    my $entry = $result->entry(0);
    my $owner = $entry->get_value('fSMORoleOwner');
    return $owner;
}

sub getDomainNamingMaster
{
    my ($self) = @_;

    my $rootDse = $self->rootDse();
    my $configurationNC = $rootDse->get_value('configurationNamingContext');
    my $params = {
        base => "CN=Partitions,$configurationNC",
        scope => 'base',
        filter => '(objectClass=*)',
        attrs => ['fSMORoleOwner'],
    };
    my $result = $self->search($params);
    if ($result->count() != 1) {
        throw EBox::Exceptions::Internal("Expected one entry");
    }
    my $entry = $result->entry(0);
    my $owner = $entry->get_value('fSMORoleOwner');
    return $owner;
}

sub getSchemaMaster
{
    my ($self) = @_;

    my $rootDse = $self->rootDse();
    my $schemaNC = $rootDse->get_value('schemaNamingContext');
    my $params = {
        base => $schemaNC,
        scope => 'base',
        filter => '(objectClass=*)',
        attrs => ['fSMORoleOwner'],
    };
    my $result = $self->search($params);
    if ($result->count() != 1) {
        throw EBox::Exceptions::Internal("Expected one entry");
    }
    my $entry = $result->entry(0);
    my $owner = $entry->get_value('fSMORoleOwner');
    return $owner;
}

sub isRoleOwnerOnline
{
    my ($self, $currentOwner) = @_;

    # Current owner is the nTDSDSA. Shift to get the server and query the
    # dns name
    my $parts = ldap_explode_dn($currentOwner);
    shift @{$parts};
    my $dn = canonical_dn($parts);
    my $params = {
        base => $dn,
        scope => 'base',
        filter => '(objectClass=*)',
        attrs => ['dNSHostName'],
    };
    my $result = $self->search($params);
    if ($result->count() != 1) {
        throw EBox::Exceptions::Internal("Expected one entry");
    }
    my $entry = $result->entry(0);
    my $hostname = $entry->get_value('dNSHostName');

    # Check if current master is online pinging EPM port
    my $p = new Net::Ping('tcp', 5);
    $p->service_check(1);
    $p->port_number(135);
    my $online = $p->ping($hostname, 5);
    $p->close();

    return $online;
}

sub transferSchemaMaster
{
    my ($self, $seize) = @_;

    if ($seize) {
        EBox::info("Seizing Schema Master role");
        EBox::Sudo::root('samba-tool fsmo seize --force --role schema');
    } else {
        EBox::info("Transfering Schema Master role");
        EBox::Sudo::root('samba-tool fsmo transfer --role schema');
    }
}

sub transferDomainNamingMaster
{
    my ($self, $seize) = @_;

    if ($seize) {
        EBox::info("Seizing Domain Naming Master role");
        EBox::Sudo::root('samba-tool fsmo seize --force --role naming');
    } else {
        EBox::info("Transfering Domain Naming Master role");
        EBox::Sudo::root('samba-tool fsmo transfer --role naming');
    }
}

sub transferPdcEmulationMaster
{
    my ($self, $seize) = @_;

    if ($seize) {
        EBox::info("Seizing PDC Emulation Master role");
        EBox::Sudo::root('samba-tool fsmo seize --force --role pdc');
    } else {
        EBox::info("Transfering PDC Emulation Master role");
        EBox::Sudo::root('samba-tool fsmo transfer --role pdc');
    }
}

sub transferInfrastructureMaster
{
    my ($self, $seize) = @_;

    if ($seize) {
        EBox::info("Seizing Infrastructure Master role");
        EBox::Sudo::root('samba-tool fsmo seize --force --role infrastructure');
    } else {
        EBox::info("Transfering Infrastructure Master role");
        EBox::Sudo::root('samba-tool fsmo transfer --role infrastructure');
    }
}

sub transferRidAllocationMaster
{
    my ($self, $seize) = @_;

    if ($seize) {
        EBox::info("Seizing Rid Allocation Master role");
        EBox::Sudo::root('samba-tool fsmo seize --force --role rid');
    } else {
        EBox::info("Transfering Rid Allocation Master role");
        EBox::Sudo::root('samba-tool fsmo transfer --role rid');
    }
}

1;
