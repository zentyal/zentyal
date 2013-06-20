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

# Class: EBox::Samba::GPO
#
package EBox::Samba::GPO;

use base 'EBox::Samba::LdbObject';

use EBox::Gettext;
use EBox::Samba::SmbClient;
use EBox::Exceptions::Internal;

use Data::UUID;

use constant STATUS_ENABLED                 => 0x00;
use constant STATUS_USER_CONF_DISABLED      => 0x01;
use constant STATUS_COMPUTER_CONF_DISABLED  => 0x02;
use constant STATUS_ALL_DISABLED            => 0x03;

# Method: new
#
#   Class constructor
#
# Parameters:
#
#      displayName
#
sub new
{
    my ($class, %params) = @_;

    my $self = {};
    if ($params{displayName}) {
        $self->{displayName} = $params{displayName};
    } else {
        $self = $class->SUPER::new(%params);
    }
    bless ($self, $class);

    return $self;
}


# Method: _entry
#
#   Return Net::LDAP::Entry entry for the GPO
#
sub _entry
{
    my ($self) = @_;

    unless ($self->{entry}) {
        if (defined $self->{displayName}) {
            my $attrs = {
                base => $self->_ldap->dn(),
                filter => "(&(objectClass=GroupPolicyContainer)(diplayName=$self->{displayName}))",
                scope => 'sub',
                attrs => ['*'],
            };
            my $result = $self->_ldap->search($attrs);
            if ($result->count() > 1) {
                throw EBox::Exceptions::Internal(
                    __x('Found {count} results for, expected only one.',
                        count => $result->count()));
            }
            $self->{entry} = $result->entry(0);
        } else {
            $self->{entry} = $self->SUPER::_entry();
        }
        return undef unless defined $self->{entry};

        my @objectClasses = $self->{entry}->get_value('objectClass');
        unless (grep (/GroupPolicyContainer/i, @objectClasses)) {
            my $dn = $self->{entry}->dn();
            throw EBox::Exceptions::Internal("Object '$dn' is not a Group Policy Container");
        }
    }

    return $self->{entry};
}

# Method: deleteObject
#
#   Deletes this object from the LDAP and remove GPT files
#
# Overrides:
#
#   EBox::Samba::LdbObject::deleteObject
#
sub deleteObject
{
    my ($self) = @_;

    my $gpoName = $self->get('name');
    unless (length $gpoName) {
        throw EBox::Exceptions::Internal("Could not get the GPO name");
    }

    my $defaultNC = $self->_ldap->dn();
    my $dnsDomain = join ('.', grep (/.+/, split (/[,]?DC=/, $defaultNC)));
    unless (length $dnsDomain) {
        throw EBox::Exceptions::Internal("Could not get the DNS domain name");
    }

    my $smb = new EBox::Samba::SmbClient(RID => 500);

    # TODO: Remove all links to this GPO in the domain

    # Remove GPC from LDAP
    $self->SUPER::deleteObject();

    # Remove GTP from sysvol
    $smb->rmdir_recurse("smb://$dnsDomain/sysvol/$dnsDomain/Policies/$gpoName")
        or throw EBox::Exceptions::Internal("Could not remove GPO from sysvol: $!");
}

# Method: status
#
#   Returns the GPO status. Possible values are:
#       0 - Enabled
#       1 - User configuration settings disabled
#       2 - Computer configuration settings disabled
#       3 - All settings disabled
#
sub status
{
    my ($self) = @_;

    my $flags = $self->get('flags');
    return ($flags & 0x03);
}

# Method: setStatus
#
#   Set GPO status
#
sub setStatus
{
    my ($self, $status, $lazy) = @_;

    my $flags = ($status & 0x03);
    $self->set('flags', $flags, $lazy);
}

# Method: path
#
#   Returns the GPO filesystem path in a form ready to be used by
#   EBox::Samba::SmbClient
#
sub path
{
    my ($self) = @_;

    my $path = $self->get('gPCFileSysPath');
    $path =~ s/\\/\//g;

    return "smb:$path";
}

# Method: create
#
#   Creates a new GPO
#
sub create
{
    my ($self, $displayName, $status) = @_;

    my $ug = new Data::UUID();
    my $gpoName = uc('{' . $ug->create_str() . '}');
    my $versionNumber = 0;

    # Get dns domain
    my $defaultNC = $self->_ldap->dn();
    my $dnsDomain = join ('.', grep (/.+/, split (/[,]?DC=/, $defaultNC)));
    unless (length $dnsDomain) {
        throw EBox::Exceptions::Internal("Could not get the DNS domain name");
    }

    my $smb = new EBox::Samba::SmbClient(RID => 500);

    # Create GPT in sysvol
    my $gptContent = "[General]\r\nVersion=$versionNumber\r\n";
    $smb->mkdir("smb://$dnsDomain/sysvol/$dnsDomain/Policies/$gpoName",'0666')
        or throw EBox::Exceptions::Internal("Error mkdir: $!");
    $smb->mkdir("smb://$dnsDomain/sysvol/$dnsDomain/Policies/$gpoName/USER",'0666')
        or throw EBox::Exceptions::Internal("Error mkdir: $!");
    $smb->mkdir("smb://$dnsDomain/sysvol/$dnsDomain/Policies/$gpoName/MACHINE",'0666')
        or throw EBox::Exceptions::Internal("Error mkdir: $!");
    my $fd = $smb->open(">smb://$dnsDomain/sysvol/$dnsDomain/Policies/$gpoName/GPT.INI", 0666)
        or throw EBox::Exceptions::Internal("Can't create file: $!");
    $smb->write($fd, $gptContent)
        or throw EBox::Exceptions::Internal("Can't write file: $!");
    $smb->close($fd);

    # Create the GPC (Group Policy Container)
    my $gpoPath = "\\\\$dnsDomain\\sysvol\\$dnsDomain\\Policies\\$gpoName";

    my $dn = "CN=$gpoName,CN=Policies,CN=System,$defaultNC";
    my $attrs = [];
    push (@{$attrs}, objectClass => ['groupPolicyContainer']);
    push (@{$attrs}, displayName => $displayName);
    push (@{$attrs}, flags => $status);
    push (@{$attrs}, versionNumber => $versionNumber);
    push (@{$attrs}, gPCFunctionalityVersion => 2);
    push (@{$attrs}, gPCFileSysPath => $gpoPath);
    my $result = $self->_ldap->add($dn, { attr => $attrs });

    my $createdGPO = new EBox::Samba::GPO(dn => $dn);

    return $createdGPO;
}

1;
