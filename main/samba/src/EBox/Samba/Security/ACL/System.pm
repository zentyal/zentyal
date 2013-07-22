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

# Class: EBox::Samba::Security::ACL::System
#
#   See EBox::Samba::Security::ACL for description
#
# Documentation:
#
#   [MS-DTYP] — v20130118
#       Windows Data Types
#       Copyright © 2013 Microsoft Corporation.
#
package EBox::Samba::Security::ACL::System;

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
    unless ($type == EBox::Samba::Security::ACE::ACE_TYPE_SYSTEM_AUDIT or
            $type == EBox::Samba::Security::ACE::ACE_TYPE_SYSTEM_AUDIT_OBJECT or
            $type == EBox::Samba::Security::ACE::ACE_TYPE_SYSTEM_AUDIT_CALLBACK or
            $type == EBox::Samba::Security::ACE::ACE_TYPE_SYSTEM_AUDIT_CALLBACK_OBJECT or
            $type == EBox::Samba::Security::ACE::ACE_TYPE_SYSTEM_ALARM or
            $type == EBox::Samba::Security::ACE::ACE_TYPE_SYSTEM_ALARM_OBJECT or
            $type == EBox::Samba::Security::ACE::ACE_TYPE_SYSTEM_ALARM_CALLBACK or
            $type == EBox::Samba::Security::ACE::ACE_TYPE_SYSTEM_ALARM_CALLBACK_OBJECT or
            $type == EBox::Samba::Security::ACE::ACE_TYPE_SYSTEM_MANDATORY_LABEL or
            $type == EBox::Samba::Security::ACE::ACE_TYPE_SYSTEM_RESOURCE_ATTRIBUTE or
            $type == EBox::Samba::Security::ACE::ACE_TYPE_SYSTEM_SCOPED_POLICY_ID) {
        throw EBox::Exceptions::InvalidArgument("Invalid ACE type for a system ACL");
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

    if ($aceType == EBox::Samba::Security::ACE::ACE_TYPE_SYSTEM_AUDIT) {
        throw EBox::Exceptions::NotImplemented(
            'EBox::Samba::Security::ACE::SystemAudit');
    }
    if ($aceType == EBox::Samba::Security::ACE::ACE_TYPE_SYSTEM_AUDIT_OBJECT) {
        return new EBox::Samba::Security::ACE::SystemAuditObject(
            blob => $blob, blobOffset => $blobOffset);
    }
    if ($aceType == EBox::Samba::Security::ACE::ACE_TYPE_SYSTEM_AUDIT_CALLBACK) {
        throw EBox::Exceptions::NotImplemented(
            'EBox::Samba::Security::ACE::SystemAuditCallback');
    }
    if ($aceType == EBox::Samba::Security::ACE::ACE_TYPE_SYSTEM_AUDIT_CALLBACK_OBJECT) {
        throw EBox::Exceptions::NotImplemented(
            'EBox::Samba::Security::ACE::SystemAuditCallbackObject');
    }
    if ($aceType == EBox::Samba::Security::ACE::ACE_TYPE_SYSTEM_ALARM) {
        throw EBox::Exceptions::NotImplemented(
            'EBox::Samba::Security::ACE::SystemAlarm');
    }
    if ($aceType == EBox::Samba::Security::ACE::ACE_TYPE_SYSTEM_ALARM_OBJECT) {
        throw EBox::Exceptions::NotImplemented(
            'EBox::Samba::Security::ACE::SystemAlarmObject');
    }
    if ($aceType == EBox::Samba::Security::ACE::ACE_TYPE_SYSTEM_ALARM_CALLBACK) {
        throw EBox::Exceptions::NotImplemented(
            'EBox::Samba::Security::ACE::SystemAlarmCallback');
    }
    if ($aceType == EBox::Samba::Security::ACE::ACE_TYPE_SYSTEM_ALARM_CALLBACK_OBJECT) {
        throw EBox::Exceptions::NotImplemented(
            'EBox::Samba::Security::ACE::SystemAlarmCallbackObject');
    }
    if ($aceType == EBox::Samba::Security::ACE::ACE_TYPE_SYSTEM_MANDATORY_LABEL) {
        throw EBox::Exceptions::NotImplemented(
            'EBox::Samba::Security::ACE::SystemMandatoryLabel');
    }
    if ($aceType == EBox::Samba::Security::ACE::ACE_TYPE_SYSTEM_RESOURCE_ATTRIBUTE) {
        throw EBox::Exceptions::NotImplemented(
            'EBox::Samba::Security::ACE::SystemResourceAttribute');
    }
    if ($aceType == EBox::Samba::Security::ACE::ACE_TYPE_SYSTEM_SCOPED_POLICY_ID) {
        throw EBox::Exceptions::NotImplemented(
            'EBox::Samba::Security::ACE::SystemScopedPolicyId');
    }

    throw EBox::Exceptions::Internal("Unknown ACE type or invalid value for
        a system ACL (ACE type was $aceType).");
}

1;
