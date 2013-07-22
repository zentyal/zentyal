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

# Class: EBox::Samba::Security::ACE::AccessAllowed
#
#   The ACCESS_ALLOWED_ACE structure defines an ACE for the discretionary
#   access control list (DACL) that controls access to an object.
#
#   An access-allowed ACE allows access to an object for a
#   specific trustee identified by a security identifier (SID).
#
# Documentation:
#
#   [MS-DTYP] — v20130118
#       Windows Data Types
#       Copyright © 2013 Microsoft Corporation.
#
package EBox::Samba::Security::ACE::AccessAllowed;

use base 'EBox::Samba::Security::ACE';

use EBox::Samba::Security::SID;

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

sub sid
{
    my ($self) = @_;

    return $self->{sid};
}

sub _decode
{
    my ($self, $blob, $blobOffset) = @_;

    $blobOffset = 0 unless defined $blobOffset;

    my $aceType;
    my $aceFlags;
    my $aceSize;
    my $mask;
    my $sidBlob;

    my $fmt = "\@$blobOffset(C C S L a*)";
    ($aceType, $aceFlags, $aceSize, $mask, $sidBlob) = unpack($fmt, $blob);

    $self->{aceType} = $aceType;
    $self->{aceFlags} = $aceFlags;
    $self->{aceSize} = $aceSize;
    $self->{mask} = $mask;
    $self->{sid} = new EBox::Samba::Security::SID(blob => $sidBlob);

    EBox::debug("AceType:   <$aceType>");
    EBox::debug("AceFlags:  <$aceFlags>");
    EBox::debug("AceSize:   <$aceSize>");
    EBox::debug("Mask:      <$mask>");
    EBox::debug("SID:       <" . $self->sid->asString() . ">");
}

1;
