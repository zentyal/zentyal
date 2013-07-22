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

# Class: EBox::Samba::Security::ACE::AccessAllowedObject
#
#   The ACCESS_ALLOWED_OBJECT_ACE structure defines an ACE that controls
#   allowed access to an object, a property set, or property. The ACE contains
#   a set of access rights, a GUID that identifies the type of object, and a
#   SID that identifies the trustee to whom the system will grant access. The
#   ACE also contains a GUID and a set of flags that control inheritance of
#   the ACE by child objects.
#
# Documentation:
#
#   [MS-DTYP] — v20130118
#       Windows Data Types
#       Copyright © 2013 Microsoft Corporation.
#
package EBox::Samba::Security::ACE::AccessAllowedObject;

use base 'EBox::Samba::Security::ACE';

use EBox::Samba::Security::SID;

use constant ACE_OBJECT_TYPE_PRESENT           => 0x00000001;
use constant ACE_INHERITED_OBJECT_TYPE_PRESENT => 0x00000002;

sub new
{
    my ($class, %params) = @_;

    my $self = {};
    bless ($self, $class);

    if (defined $params{blob}) {
        $self->_decode($params{blob}, $params{blobOffset});
    }

    return $self;
}

sub _decode
{
    my ($self, $blob, $blobOffset) = @_;

    $blobOffset = 0 unless defined $blobOffset;

    my $aceType;
    my $aceFlags;
    my $aceSize;
    my $mask;
    my $flags;
    my $objectType;
    my $inheritedObjectType;
    my $sidBlob;

    my $fmt = "\@$blobOffset(C C S L L)";
    ($aceType, $aceFlags, $aceSize, $mask, $flags) = unpack($fmt, $blob);
    $blobOffset += 12;

    EBox::debug("AceType:   <$aceType>");
    EBox::debug("AceFlags:  <$aceFlags>");
    EBox::debug("AceSize:   <$aceSize>");
    EBox::debug("Mask:      <$mask>");
    EBox::debug("Flags:     <$flags>");
    $self->{aceType} = $aceType;
    $self->{aceFlags} = $aceFlags;
    $self->{aceSize} = $aceSize;
    $self->{mask} = $mask;
    $self->{flags} = $flags;

    if ($flags & ACE_OBJECT_TYPE_PRESENT) {
        my $fmt = "\@$blobOffset(a16)";
        ($objectType) = unpack($fmt, $blob);
        $blobOffset += 16;
        $self->{objectType} = $objectType;
    }

    if ($flags & ACE_INHERITED_OBJECT_TYPE_PRESENT) {
         my $fmt = "\@$blobOffset(a16)";
        ($inheritedObjectType) = unpack($fmt, $blob);
        $blobOffset += 16;
        $self->{inheritedObjectType} = $inheritedObjectType;
    }

    $fmt = "\@$blobOffset(a*)";
    ($sidBlob) = unpack($fmt, $blob);
    $self->{sid} = new EBox::Samba::Security::SID(blob => $sidBlob);
}

1;
