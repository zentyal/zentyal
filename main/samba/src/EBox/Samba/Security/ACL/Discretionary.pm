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

# Class: EBox::Samba::Security::ACL::Discretionary
#
#   See EBox::Samba::Security::ACL for description
#
# Documentation:
#
#   [MS-DTYP] — v20130118
#       Windows Data Types
#       Copyright © 2013 Microsoft Corporation.
#
package EBox::Samba::Security::ACL::Discretionary;

use base 'EBox::Samba::Security::ACL';

sub addACE
{
    my ($self, $ace) = @_;

    unless (defined $ace) {
        throw EBox::Exceptions::MissingArgument('ace');
    }

    unless ($ace->isa('EBox::Samba::Security::ACE')) {
        throw EBox::Exceptions::InvalidArgument(
            'ace. Expected EBox::Samba::Security::ACE instance');
    }

    my $type = $ace->type();
    unless ($type == EBox::Samba::Security::ACE::ACE_TYPE_ACCESS_ALLOWED or
            $type == EBox::Samba::Security::ACE::ACE_TYPE_ACCESS_DENIED or
            $type == EBox::Samba::Security::ACE::ACE_TYPE_ACCESS_ALLOWED_COMPOUND or
            $type == EBox::Samba::Security::ACE::ACE_TYPE_ACCESS_ALLOWED_OBJECT or
            $type == EBox::Samba::Security::ACE::ACE_TYPE_ACCESS_DENIED_OBJECT or
            $type == EBox::Samba::Security::ACE::ACE_TYPE_ACCESS_ALLOWED_CALLBACK or
            $type == EBox::Samba::Security::ACE::ACE_TYPE_ACCESS_DENIED_CALLBACK or
            $type == EBox::Samba::Security::ACE::ACE_TYPE_ACCESS_ALLOWED_CALLBACK_OBJECT or
            $type == EBox::Samba::Security::ACE::ACE_TYPE_ACCESS_DENIED_CALLBACK_OBJECT) {
        throw EBox::Exceptions::InvalidArgument("Invalid ACE type for a discretionary ACL");
    }

    push (@{$self->{aceList}}, $ace);
}

sub _decodeACE
{
    my ($self, $blob, $blobOffset) = @_;

    $blobOffset = 0 unless defined $blobOffset;

    # Decode ACE header to instantiate the proper ACE class
    my $fmt = "\@$blobOffset(C C S)";
    my ($aceType, undef, undef) = unpack($fmt, $blob);

    if ($aceType == EBox::Samba::Security::ACE::ACE_TYPE_ACCESS_ALLOWED) {
        return new EBox::Samba::Security::ACE::AccessAllowed(
            blob => $blob, blobOffset => $blobOffset);
    }
    if ($aceType == EBox::Samba::Security::ACE::ACE_TYPE_ACCESS_DENIED) {
        throw EBox::Exceptions::NotImplemented(
            'EBox::Samba::Security::ACE::AccessDenied');
    }
    if ($aceType == EBox::Samba::Security::ACE::ACE_TYPE_ACCESS_ALLOWED_COMPOUND) {
        throw EBox::Exceptions::NotImplemented(
            'EBox::Samba::Security::ACE::AccessAllowedCompound');
    }
    if ($aceType == EBox::Samba::Security::ACE::ACE_TYPE_ACCESS_ALLOWED_OBJECT) {
        return new EBox::Samba::Security::ACE::AccessAllowedObject(
            blob => $blob, blobOffset => $blobOffset);
    }
    if ($aceType == EBox::Samba::Security::ACE::ACE_TYPE_ACCESS_DENIED_OBJECT) {
        throw EBox::Exceptions::NotImplemented(
            'EBox::Samba::Security::ACE::AccessDeniedObject');
    }
    if ($aceType == EBox::Samba::Security::ACE::ACE_TYPE_ACCESS_ALLOWED_CALLBACK) {
        throw EBox::Exceptions::NotImplemented(
            'EBox::Samba::Security::ACE::AccessAllowedCallback');
    }
    if ($aceType == EBox::Samba::Security::ACE::ACE_TYPE_ACCESS_DENIED_CALLBACK) {
        throw EBox::Exceptions::NotImplemented(
            'EBox::Samba::Security::ACE::AccessDeniedCallback');
    }
    if ($aceType == EBox::Samba::Security::ACE::ACE_TYPE_ACCESS_ALLOWED_CALLBACK_OBJECT) {
        throw EBox::Exceptions::NotImplemented(
            'EBox::Samba::Security::ACE::AccessAllowedCallbackObject');
    }
    if ($aceType == EBox::Samba::Security::ACE::ACE_TYPE_ACCESS_DENIED_CALLBACK_OBJECT) {
        throw EBox::Exceptions::NotImplemented(
            'EBox::Samba::Security::ACE::AccessDeniedCallbackObject');
    }

    throw EBox::Exceptions::Internal("Unknown ACE type or invalid value for
        a discretionary ACL (ACE type was $aceType).");
}

1;
