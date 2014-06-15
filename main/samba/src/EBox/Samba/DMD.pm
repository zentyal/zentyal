# Copyright (C) 2014 Zentyal S.L.
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

# Class: EBox::Samba::DMD
#
#   Directory Management Domain, stored in LDB
#
package EBox::Samba::DMD;
use base 'EBox::Samba::LdapObject';

# Method: mainObjectClass
#
sub mainObjectClass
{
    return 'dMD';
}

# Method: name
#
#   Return the name of this container.
#
sub name
{
    my ($self) = @_;

    return $self->get('cn');
}

# Method: objectVersion
#
#   Return the schema version.
#
# Known values:
#
#   13 -> Windows 2000 Server
#   30 -> Windows Server 2003
#   31 -> Windows Server 2003 R2
#   44 -> Windows Server 2008
#   47 -> Windows Server 2008 R2
#   56 -> Windows Server 2012
#   69 -> Windows Server 2012 R2
#
sub objectVersion
{
    my ($self) = @_;

    return $self->get('objectVersion');
}

# Method: ownedByZentyal
#
#   Return whether Zentyal owns the schema handling for this domain.
#
sub ownedByZentyal
{
    my ($self) = @_;

    my $usersMod = EBox::Global->modInstance('samba');
    my $ldap = $usersMod->ldap();
    my $sysinfoMod = EBox::Global->modInstance('sysinfo');

    my $schemaRole = $self->get('fSMORoleOwner');
    my $rootDN = $ldap->dn();
    my $hostName = $sysinfoMod->hostName();
    my $ownRole = "CN=NTDS Settings,CN=$hostName,CN=Servers,CN=Default-First-Site-Name,CN=Sites,CN=Configuration,$rootDN";
    if (lc $schemaRole eq lc $ownRole) {
        return 1;
    } else {
        return 0;
    }
}

sub set
{
    throw EBox::Exceptions::UnwillingToPerform(reason => 'Core objects cannot be modified');
}

sub delete
{
    throw EBox::Exceptions::UnwillingToPerform(reason => 'Core objects cannot be modified');
}

sub save
{
    throw EBox::Exceptions::UnwillingToPerform(reason => 'Core objects cannot be modified');
}

sub deleteObject
{
    throw EBox::Exceptions::UnwillingToPerform(reason => 'Core objects cannot be modified');
}

1;
