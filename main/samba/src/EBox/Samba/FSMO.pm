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

package EBox::Samba::FSMO;

use strict;
use warnings;

use base 'EBox::LDB';

use EBox::Exceptions::Internal;
use EBox::Sudo;

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

sub transferSchemaMaster
{
    my ($self) = @_;

    EBox::info("Transfering Schema Master role");
    EBox::Sudo::root('samba-tool fsmo transfer --role schema');
}

sub transferDomainNamingMaster
{
    my ($self) = @_;

    EBox::info("Transfering Domain Naming Master role");
    EBox::Sudo::root('samba-tool fsmo transfer --role naming');
}

sub transferPdcEmulationMaster
{
    my ($self) = @_;

    EBox::info("Transfering PDC Emulation Master role");
    EBox::Sudo::root('samba-tool fsmo transfer --role pdc');
}

sub transferInfrastructureMaster
{
    my ($self) = @_;

    EBox::info("Transfering Infrastructure Master role");
    EBox::Sudo::root('samba-tool fsmo transfer --role infrastructure');
}

sub transferRidAllocationMaster
{
    my ($self) = @_;

    EBox::info("Transfering Rid Allocation Master role");
    EBox::Sudo::root('samba-tool fsmo transfer --role rid');
}

1;
