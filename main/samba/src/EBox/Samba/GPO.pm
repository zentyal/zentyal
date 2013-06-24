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
use EBox::Sudo;
use EBox::Samba::SmbClient;
use EBox::Exceptions::Internal;

use Encode qw(encode decode);
use Parse::RecDescent;
use Data::UUID;

use constant STATUS_ENABLED                 => 0x00;
use constant STATUS_USER_CONF_DISABLED      => 0x01;
use constant STATUS_COMPUTER_CONF_DISABLED  => 0x02;
use constant STATUS_ALL_DISABLED            => 0x03;

use constant GPT_INI_GRAMMAR => q{
IniFile: WhiteSpace Section(s) WhiteSpace /\Z/
{
    my $ret = {};
    foreach my $hash (@{$item[2]}) {
        foreach my $key (keys %{$hash}) {
            $ret->{$key} = $hash->{$key};
        }
    }
    $return = $ret;
}
WhiteSpaceClass: "\t" | " "
WhiteSpace: WhiteSpaceClass(s?)
LineBreak: "\r" | "\n"

Section: SectionId Key(s)
{
    $return = {
        $item[1] => $item[2],
    };
}

SectionId: "[" SectionName "]" WhiteSpace LineBreak(s)
{
    $return = $item[2];
}
SectionName: /[a-zA-Z0-9_ \t]+/
Key:    /[^=\[\]]+/ WhiteSpace "=" WhiteSpace /[^\r\n]+/
        WhiteSpace LineBreak(s?)
        {
            $return = {
                key => $item[1],
                value => $item[5],
            };
        }

startrule: IniFile
};

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
    my $gpoDN = $self->get('distinguishedName');
    unless (length $gpoName) {
        throw EBox::Exceptions::Internal("Could not get the GPO name");
    }

    my $defaultNC = $self->_ldap->dn();
    my $dnsDomain = join ('.', grep (/.+/, split (/[,]?DC=/, $defaultNC)));
    unless (length $dnsDomain) {
        throw EBox::Exceptions::Internal("Could not get the DNS domain name");
    }

    my $smb = new EBox::Samba::SmbClient(RID => 500);
    my $path = $self->path();

    # TODO: Remove all links to this GPO in the domain

    # Remove subcontainers
    my $userDN = "CN=User,$gpoDN";
    my $machineDN = "CN=Machine,$gpoDN";
    my $result;
    $result = $self->_ldap->delete($userDN);
    if ($result->is_error()) {
        my $msg = $result->error_desc();
        throw EBox::Exceptions::Internal(
            "Can not create GPO. LDAP error: $msg");
    }
    $result = $self->_ldap->delete($machineDN);
    if ($result->is_error()) {
        my $msg = $result->error_desc();
        throw EBox::Exceptions::Internal(
            "Can not create GPO. LDAP error: $msg");
    }

    # Remove GPC from LDAP
    $self->SUPER::deleteObject();

    # Remove GTP from sysvol
    $smb->rmdir_recurse($path) or throw EBox::Exceptions::Internal(
        "Could not remove GPO from sysvol: $!");
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

    # Create the GPC (Group Policy Container)
    my $gpoPath = "\\\\$dnsDomain\\SysVol\\$dnsDomain\\Policies\\$gpoName";
    my $gpoDN = "CN=$gpoName,CN=Policies,CN=System,$defaultNC";
    my $attrs = [];
    push (@{$attrs}, objectClass => ['groupPolicyContainer']);
    push (@{$attrs}, displayName => $displayName);
    push (@{$attrs}, flags => $status);
    push (@{$attrs}, versionNumber => $versionNumber);
    push (@{$attrs}, gPCFunctionalityVersion => 2);
    push (@{$attrs}, gPCFileSysPath => $gpoPath);
    my $result = $self->_ldap->add($gpoDN, { attr => $attrs });
    if ($result->is_error()) {
        my $msg = $result->error_desc();
        throw EBox::Exceptions::Internal(
            "Can not create GPO. LDAP error: $msg");
    }

    # Create user subcontainer
    my $userDN = "CN=User,$gpoDN";
    my $userAttrs = [];
    push (@{$userAttrs}, objectClass => ['container']);
    $result = $self->_ldap->add($userDN, { attr => $userAttrs });
    if ($result->is_error()) {
        my $msg = $result->error_desc();
        throw EBox::Exceptions::Internal(
            "Can not create GPO user container. LDAP error: $msg");
    }

    # Create machine subcontainer
    my $machineDN = "CN=Machine,$gpoDN";
    my $machineAttrs = [];
    push (@{$machineAttrs}, objectClass => ['container']);
    $result = $self->_ldap->add($machineDN, { attr => $machineAttrs });
    if ($result->is_error()) {
        my $msg = $result->error_desc();
        throw EBox::Exceptions::Internal(
            "Can not create GPO machine container. LDAP error: $msg");
    }

    $result = $self->_ldap->search({base => $gpoDN,
                                    scope => 'one',
                                    filter => '(objectClass=*)',
                                    attrs => ['nTSecurityDescriptor']});
    if ($result->is_error()) {
        my $msg = $result->error_desc();
        throw EBox::Exceptions::Internal(
            "Can not create GPO. LDAP error: $msg");
    }
    my $entry = $result->entry(0);
    unless (defined $entry) {
        throw EBox::Exceptions::Internal(
            "Can not retrieve LDAP created GPO entry");
    }
    my $ntSecurityDescriptor = $entry->get_value('ntSecurityDescriptor');
    unless (defined $ntSecurityDescriptor) {
        throw EBox::Exceptions::Internal(
            "Can not retrieve NT Security Descriptor from GPO LDAP entry");
    }

    # Create GPT in sysvol
    my $smb = new EBox::Samba::SmbClient(RID => 500);
    my $gptContent = "[General]\r\nVersion=$versionNumber\r\n";
    $gptContent = encode('UTF-8', $gptContent);
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

    # TODO Set NT security Descriptor instead sysvolreset
    EBox::Sudo::root("samba-tool ntacl sysvolreset");

    my $createdGPO = new EBox::Samba::GPO(dn => $gpoDN);
    return $createdGPO;
}

sub _updateExtensionNames
{
    my ($self, $current, $cseGUID, $toolGUID) = @_;

    my @pairs = ($current =~ /\[([^\[\]]+)\]/igs);
    my @newPairs;
    my $found = 0;
    push (@newPairs, "${cseGUID}${toolGUID}");
    foreach my $pair (@pairs) {
        my ($cse, $tool) = ($pair =~ /({[^}]+})({[^}]+})/g);
        if (lc $cse eq lc $cseGUID and lc $tool eq lc $toolGUID) {
            next;
        }
        push (@newPairs, "${cse}${tool}");
    }

    my $newValue;
    foreach my $pair (@newPairs) {
        $newValue .= '[' . $pair . ']';
    }
    return $newValue;
}

# Method: extensionUpdate
#
#   This is triggered whenever an administrator uses a Group Policy Extension's
#   Policy Administration protocol to change a Group Policy Extension's
#   settings in a GPO.
#
#   This triggers the processing rule 3.3.5.2 GPO Extension Update.
#
# Parameters:
#
#   isUser - A Boolean value to indicate that this update is for user policy
#            mode. If FALSE, this update is for computer policy mode.
#   cseGUID - The Client-side extension's GUID.
#   toolGUID - The Administrative extension plug-in's GUID.
#
sub extensionUpdate
{
    my ($self, $isUser, $cseGUID, $toolGUID) = @_;

    # Read version number in the GPT.INI and increment it
    my $gptIniPath = $self->path() . '/GPT.INI';
    my $smb = new EBox::Samba::SmbClient(RID => 500);
    my $buffer = $smb->read_file($gptIniPath);
    $buffer = decode('UTF-8', $buffer);

    my $parser = $self->_gptIniParser();
    my $data = $parser->startrule($buffer);
    my $version = undef;
    my $versionPointer = undef;
    foreach my $key (keys %{$data}) {
        if (lc $key eq 'general') {
            foreach my $pair (@{$data->{$key}}) {
                if (lc $pair->{key} eq 'version') {
                    $versionPointer = $pair;
                    $version = $pair->{value};
                    last;
                }
            }
        }
        last if (defined $version);
    }
    unless (defined $version and $versionPointer) {
        throw EBox::Exceptions::Internal(
            "Can not read GPO version number from GPT.INI");
    }

    # Version is a 32bits integer value. Higher 16 bits are user scope GPO
    # version and lower 16 bits machine GPO version
    my $userVersion = $version >> 16;
    my $machineVersion = ($version & 0xFFFF);

    # Increment version number and update data
    if ($isUser) {
        $userVersion++;
    } else {
        $machineVersion++;
    }
    $versionPointer->{value} = ($userVersion << 16) | $machineVersion;

    # Update LDAP version number and extension names
    $self->set('versionNumber', $versionPointer->{value});
    if ($isUser) {
        my $userExtensions = $self->get('gPCUserExtensionNames');
        $userExtensions = $self->_updateExtensionNames($userExtensions,
            $cseGUID, $toolGUID);
        $self->set('gPCUserExtensionNames', $userExtensions);
    } else {
        my $machineExtensions = $self->get('gPCMachineExtensionNames');
        $machineExtensions = $self->_updateExtensionNames($machineExtensions,
            $cseGUID, $toolGUID);
        $self->set('gPCMachineExtensionNames', $machineExtensions);
    }

    # Update GPT.INI file
    my $fd = $smb->open(">$gptIniPath", 0666);
    unless ($fd) {
        throw EBox::Exceptions::Internal("Can not open $gptIniPath: $!");
    }
    foreach my $section (keys %{$data}) {
        my $wrote;
        $wrote = $smb->write($fd, "[$section]\r\n");
        unless ($wrote) {
            throw EBox::Exceptions::Internal(
                "Can not write on $gptIniPath: $!");
        }
        foreach my $pair (@{$data->{$section}}) {
            $wrote = $smb->write($fd, "$pair->{key}=$pair->{value}\r\n");
            unless ($wrote) {
                throw EBox::Exceptions::Internal(
                    "Can not write on $gptIniPath: $!");
            }
        }
        last if (defined $version);
    }
    $smb->close($fd);
}

sub _gptIniParser
{
    my ($self) = @_;

    unless (defined $self->{gptIniParser}) {
        $Parse::RecDescent::skip = '';
        $self->{gptIniParser} = new Parse::RecDescent(GPT_INI_GRAMMAR) or
            throw EBox::Exceptions::Internal(__("Bad grammar"));
    }
    return $self->{gptIniParser};
}

1;
