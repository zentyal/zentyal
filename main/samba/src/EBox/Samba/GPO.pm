# Copyright (C) 2013-2014 Zentyal S.L.
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

use base 'EBox::Samba::LdapObject';

use EBox::Gettext;
use EBox::Sudo;
use EBox::Samba::SmbClient;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::External;
use EBox::Samba::LDAP::Control::SDFlags;

use Encode qw(encode decode);
use Parse::RecDescent;
use Data::UUID;
use Fcntl;
use TryCatch::Lite;
use Net::LDAP::Control;
use Samba::Smb qw(NTCREATEX_DISP_OVERWRITE_IF FILE_ATTRIBUTE_NORMAL);
use Samba::Security::Descriptor;

use constant STATUS_ENABLED                 => 0x00;
use constant STATUS_USER_CONF_DISABLED      => 0x01;
use constant STATUS_COMPUTER_CONF_DISABLED  => 0x02;
use constant STATUS_ALL_DISABLED            => 0x03;

use constant LINK_ENABLED   => 0x00000000;
use constant LINK_DISABLED  => 0x00000001;
use constant LINK_ENFORCED  => 0x00000002;

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
#   Instance an object readed from LDAP.
#
#   Parameters:
#
#      dn - Full dn for the user
#  or
#      ldif - Reads the entry from LDIF
#  or
#      entry - Net::LDAP entry for the user
#  or
#      objectGUID - The LDB's objectGUID.
#  or
#      displayName
#
sub new
{
    my ($class, %params) = @_;

    my $self = {};
    bless ($self, $class);
    if ($params{displayName}) {
        $self->{displayName} = $params{displayName};
    } else {
        try {
            $self = $class->SUPER::new(%params);
        } catch (EBox::Exceptions::MissingArgument $e) {
            throw EBox::Exceptions::MissingArgument("$e|displayName");
        }
    }
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
        if (length ($self->{displayName})) {
            my $attrs = {
                base => "CN=Policies,CN=System," . $self->_ldap->dn(),
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
        } elsif (length ($self->{dn})) {
            my $attrs = {
                base => $self->{dn},
                filter => "(&(objectClass=GroupPolicyContainer)(distinguishedName=$self->{dn}))",
                scope => 'base',
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
#   EBox::Samba::LdapObject::deleteObject
#
sub deleteObject
{
    my ($self) = @_;

    my $host = $self->_ldap->rootDse->get_value('dnsHostName');
    unless (defined $host and length $host) {
        throw EBox::Exceptions::Internal('Could not get DNS hostname');
    }

    my $smb = new EBox::Samba::SmbClient(
        target => $host, service => 'sysvol', RID => 500);

    # TODO: Remove all links to this GPO in the domain

    # Remove GPC from LDAP
    $self->SUPER::deleteObject();

    # Remove GTP from sysvol
    my $path = $self->path();
    $smb->deltree($path);
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
#   Samba::Smb
#
sub path
{
    my ($self) = @_;

    my $defaultNC = $self->_ldap->dn();
    my $dnsDomain = join ('.', grep (/.+/, split (/[,]?DC=/, $defaultNC)));
    unless (length $dnsDomain) {
        throw EBox::Exceptions::Internal("Could not get the DNS domain name");
    }
    my $gpoName = $self->get('name');
    unless (length $gpoName) {
        throw EBox::Exceptions::Internal("Could not get the GPO name");
    }
    return "/$dnsDomain/Policies/$gpoName";
}

# Method: ntSecurityDescriptor
#
#   This functions reads the ntSecurityDescriptor attribute from LDAP and
#   builds a Samba::Security::Descriptor instance to be applied to GPT
#
sub ntSecurityDescriptor
{
    my ($self) = @_;

    my $control = new EBox::Samba::LDAP::Control::SDFlags(
        flags => (SECINFO_OWNER | SECINFO_GROUP | SECINFO_DACL),
        critical => 1);
    unless ($control->valid()) {
        throw EBox::Exceptions::Internal("Error building LDAP search control");
    }

    my $params = {
        base => $self->dn(),
        scope => 'base',
        filter => '(objectClass=groupPolicyContainer)',
        attrs => ['ntSecurityDescriptor'],
        control => [$control]};
    my $result = $self->_ldap->search($params);
    if ($result->is_error()) {
        throw EBox::Exceptions::Internal(
            __x("Error getting GPO entry from LDAP: {x}",
                x => $result->error_text()));
    }
    my $entry = $result->entry(0);
    unless (defined $entry) {
        throw EBox::Exceptions::Internal(
            "Error getting GPO entry from LDAP result");
    }

    my $ntSecDesc = $entry->get_value('ntSecurityDescriptor');
    unless (defined $ntSecDesc) {
        throw EBox::Exceptions::Internal(
            "Error getting ntSecurityDescriptor attribute");
    }

    my $sd = new Samba::Security::Descriptor();
    unless ($sd->unmarshall($ntSecDesc, length($ntSecDesc)) == 1) {
        throw EBox::Exceptions::Internal(
            "Error unpacking ntSecurityDescriptor attribute");
    }

    unless ($sd->to_fs_sd() == 1) {
        throw EBox::Exceptions::Internal(
            "Error transforming DS security descriptor " .
            "to FS security descriptor");
    }

    my $type = $sd->type();
    $type = $type & ~SEC_DESC_OWNER_DEFAULTED;
    $type = $type & ~SEC_DESC_GROUP_DEFAULTED;
    $sd->type($type);

    return $sd;
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

    # Get dns host name
    my $host = $self->_ldap->rootDse->get_value('dnsHostName');
    unless (defined $host and length $host) {
        throw EBox::Exceptions::Internal("Could not get the DNS host name");
    }

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

    # At this point, we can instantiate the created GPO. If anything goes
    # wrong after, we can delete the object from LDAP
    my $createdGPO = new EBox::Samba::GPO(dn => $gpoDN);

    # Create the GPT in the sysvol share
    try {
        my $gptContent = "[General]\r\nVersion=$versionNumber\r\n";
        $gptContent = encode('UTF-8', $gptContent);

        my $smb = new EBox::Samba::SmbClient(
            target => $host, service => 'sysvol', RID => 500);

        my $path = "\\$dnsDomain\\Policies\\$gpoName";
        $smb->mkdir($path);

        # Get the NT security descriptor to set
        my $sd = $createdGPO->ntSecurityDescriptor();
        my $sinfo = SECINFO_OWNER |
                    SECINFO_GROUP |
                    SECINFO_DACL |
                    SECINFO_PROTECTED_DACL;
        $smb->set_sd($path, $sd, $sinfo);

        $smb->mkdir("$path\\USER");
        $smb->mkdir("$path\\MACHINE");
        my $openParams = {
            open_disposition => NTCREATEX_DISP_OVERWRITE_IF,
            access_mask => SEC_RIGHTS_FILE_ALL,
            file_attr => FILE_ATTRIBUTE_NORMAL,
        };
        my $fd = $smb->open("$path\\GPT.INI", $openParams);
        $smb->write($fd, $gptContent, length($gptContent));
        $smb->close($fd);
    } catch ($e) {
        $createdGPO->deleteObject();
        $e->throw();
    }

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

    my $host = $self->_ldap->rootDse->get_value('dnsHostName');
    unless (defined $host and length $host) {
        throw EBox::Exceptions::Internal('Could not get DNS hostname');
    }

    my $smb = new EBox::Samba::SmbClient(
        target => $host, service => 'sysvol', RID => 500);

    # Read version number in the GPT.INI and increment it
    my $gptIniPath = $self->path() . '/GPT.INI';

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
    my $openParams = {
        open_disposition => NTCREATEX_DISP_OVERWRITE_IF,
        access_mask => SEC_RIGHTS_FILE_ALL,
        file_attr => FILE_ATTRIBUTE_NORMAL,
    };
    if ($smb->chkpath($gptIniPath)) {
        my $finfo = $smb->getattr($gptIniPath);
        $openParams->{file_attr} = $finfo->{mode};
    }
    my $fd = $smb->open($gptIniPath, $openParams);
    my $gptContent;
    foreach my $section (keys %{$data}) {
        my $wrote;
        $gptContent .= "[$section]\r\n";
        foreach my $pair (@{$data->{$section}}) {
            $gptContent .= "$pair->{key}=$pair->{value}\r\n";
        }
        last if (defined $version);
    }
    $gptContent = encode('UTF-8', $gptContent);
    $smb->write($fd, $gptContent, length($gptContent));
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

sub link
{
    my ($self, $containerDN, $linkEnabled, $enforced) = @_;

    # Get our DN
    my $gpoDN = $self->dn();

    # Instantiate container object
    my $container = new EBox::Samba::LdapObject(dn => $containerDN);
    unless ($container->exists()) {
        throw EBox::Exceptions::Internal(
            "Container $containerDN not found.");
    }
    my $gpLinkAttr = $container->get('gPLink');
    $gpLinkAttr = decode('UTF-8', $gpLinkAttr);

    # Check this GPO is not already linked
    my @linkedGPOs = grep (/.+/, split (/\[([^\[\]]+)\]/, $gpLinkAttr));
    foreach my $link (@linkedGPOs) {
        my ($linkedDN, $linkOptions) = split(/;/, $link);
        $linkedDN =~ s/ldap:\/\///ig;
        if (lc $linkedDN eq lc $gpoDN) {
            throw EBox::Exceptions::External(__x(
                "GPO {x} is already linked to this container",
                    x => $self->get('displayName')));
        }
    }

    # Build link options
    my $linkOptions = $linkEnabled ? LINK_ENABLED : LINK_DISABLED;
    if ($enforced) {
        $linkOptions |= LINK_ENFORCED;
    }

    # Add the link to array
    my $newLink = "LDAP://$gpoDN;$linkOptions";
    unshift (@linkedGPOs, $newLink);

    # Build new gpLink attribute
    $gpLinkAttr = '';
    foreach my $link (@linkedGPOs) {
        $gpLinkAttr .= "[$link]";
    }
    $gpLinkAttr = encode('UTF-8', $gpLinkAttr);

    # Write GPLink attribute
    $container->set('gPLink', $gpLinkAttr);
}

sub unlink
{
    my ($self, $containerDN, $linkIndex) = @_;

    # Instance the container and get the gpLink attribute
    my $container = new EBox::Samba::LdapObject(dn => $containerDN);
    unless ($container->exists()) {
        throw EBox::Exceptions::Internal(
            "Container $containerDN does not exists");
    }

    my $gpLinkAttr = $container->get('gPLink');
    $gpLinkAttr = decode('UTF-8', $gpLinkAttr);

    # Split linked GPOs
    my @linkedGPOs = grep (/.+/, reverse split (/\[([^\[\]]+)\]/, $gpLinkAttr));

    # Check linked GPO at given index is myself
    my $target = $linkedGPOs[$linkIndex - 1];
    my ($gpoPath, $linkOptions) = split(/;/, $target);
    $gpoPath =~ s/ldap:\/\///ig;
    if (lc $gpoPath ne lc $self->get('distinguishedName')) {
        throw EBox::Exceptions::Internal("Index does not match");
    }

    # Remove from array
    splice (@linkedGPOs, $linkIndex - 1, 1);

    # Build and set new gpLink attribute
    if (scalar @linkedGPOs) {
        $gpLinkAttr = '';
        foreach my $link (reverse @linkedGPOs) {
            $gpLinkAttr .= "[$link]";
        }
        $gpLinkAttr = encode('UTF-8', $gpLinkAttr);
        $container->set('gpLink', $gpLinkAttr);
    } else {
        $container->delete('gPLink', 0);
    }
}

sub editLink
{
    my ($self, $containerDN, $linkIndex, $linkEnabled, $enforced) = @_;

    # Instance the container and get the gpLink attribute
    my $container = new EBox::Samba::LdapObject(dn => $containerDN);
    unless ($container->exists()) {
        throw EBox::Exceptions::Internal(
            "Container $containerDN does not exists");
    }
    my $gpLinkAttr = $container->get('gPLink');
    $gpLinkAttr = decode('UTF-8', $gpLinkAttr);

    # Split linked GPOs
    my @linkedGPOs = grep (/.+/, reverse split (/\[([^\[\]]+)\]/, $gpLinkAttr));

    # Check linked GPO at given index is ourself
    my $target = $linkedGPOs[$linkIndex - 1];
    my ($gpoPath, $linkOptions) = split(/;/, $target);
    $gpoPath =~ s/ldap:\/\///ig;
    if (lc $gpoPath ne lc $self->get('distinguishedName')) {
        throw EBox::Exceptions::Internal("Index does not match");
    }

    # Build new link options
    my $newLinkOptions = $linkEnabled ? LINK_ENABLED : LINK_DISABLED;
    if ($enforced) {
        $newLinkOptions |= LINK_ENFORCED;
    }

    my $newLink = "LDAP://" . $self->dn() . ";$newLinkOptions";
    $linkedGPOs[$linkIndex - 1] = $newLink;

    # Build new gpLink attribute
    $gpLinkAttr = '';
    foreach my $link (reverse @linkedGPOs) {
        $gpLinkAttr .= "[$link]";
    }
    $gpLinkAttr = encode('UTF-8', $gpLinkAttr);

    # Write GPLink attribute
    $container->set('gPLink', $gpLinkAttr);
}

1;
