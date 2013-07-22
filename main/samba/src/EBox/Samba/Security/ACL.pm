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

# Class: EBox::Samba::Security::ACL
#
#   The access control list (ACL) class is used to specify a list of
#   individual access control entries (ACEs).
#
#   The individual ACEs in an ACL are numbered from 0 to n, where n+1 is the
#   number of ACEs in the ACL. When editing an ACL, an application refers to
#   an ACE within the ACL by the ACE index.
#
#   An ACL is said to be in canonical form if:
#   *All explicit ACEs are placed before inherited ACEs
#   * Within the explicit ACEs, deny ACEs come before grant ACEs
#   *Deny ACEs on the object come before deny ACEs on a child or property
#   * Grant ACEs on the object come before grant ACEs on a child or property
#   * Inherited ACEs are placed in the order in which they were inherited
#
#   There are two types of ACL:
#   * A discretionary access control list (DACL) is controlled by the owner
#     of an object or anyone granted WRITE_DAC access to the object. It
#     specifies the access particular users and groups can have to an object.
#     For example, the owner of a file can use a DACL to control which users
#     and groups can and cannot have access to the file
#   *A system access control list (SACL) is similar to the DACL, except that
#     the SACL is used to audit rather than control access to an object. When
#     an audited action occurs, the operating system records the event in the
#     security log. Each ACE in a SACL has a header that indicates whether
#     auditing is triggered by success, failure, or both; a SID that specifies
#     a particular user or security group to monitor; and an access mask that
#     lists the operations to audit
#
# Documentation:
#
#   [MS-DTYP] — v20130118
#       Windows Data Types
#       Copyright © 2013 Microsoft Corporation.
#
package EBox::Samba::Security::ACL;

use EBox::Samba::Security::ACE::AccessAllowed;
use EBox::Samba::Security::ACE::AccessAllowedObject;
use EBox::Samba::Security::ACE::SystemAuditObject;

use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::NotImplemented;
use Error qw(:try);

sub new
{
    my ($class, %params) = @_;

    my $self = {};
    bless ($self, $class);

    unless (defined $params{blob}) {
        throw EBox::Exceptions::MissingArgument('blob');
    }

    $self->{aceList} = [];
    if (defined $params{blob}) {
        $self->_decode($params{blob}, $params{blobOffset});
    }

    return $self;
}

# Method: addACE
#
#   Adds an ACE to the ACL. Implemented on child classes because the ACE types
#   an ACL can contain depends on the ACL type (discretionary or system)
#
sub addACE
{
    my ($self, $ace) = @_;

    throw EBox::Exceptions::NotImplemented("addACE");
}

# Method: _decodeACE
#
#   Decodes an ACE inside the ACL blob. Implemented on child classes because
#   the ACE types an ACL can contain depends on the ACL type (discretionary
#   or system)
#
sub _decodeACE
{
    my ($self, $blob, $blobOffset) = @_;

    throw EBox::Exceptions::NotImplemented("_decodeACE");
}

sub _decode
{
    my ($self, $blob, $blobOffset) = @_;

    # AclRevision (1 byte):
    # An unsigned 8-bit value that specifies the revision of the ACL
    my $revision;

    # Sbz1 (1 byte):
    # An unsigned 8-bit value. This field is reserved and MUST be set to zero
    my $sbz1;

    # AclSize (2 bytes):
    # An unsigned 16-bit integer that specifies the size, in bytes, of the
    # complete ACL, including all ACEs.
    my $aclSize;

    # AceCount (2 bytes):
    # An unsigned 16-bit integer that specifies the count of the number of ACE
    # records in the ACL.
    my $aceCount;

    # Sbz2 (2 bytes):
    # An unsigned 16-bit integer. This field is reserved and MUST be set to
    # zero.
    my $sbz2;

    my $fmt = "\@$blobOffset(C C S S S)";
    ($revision, $sbz1, $aclSize, $aceCount, $sbz2) = unpack($fmt, $blob);

    EBox::debug("Revision:  <$revision>");
    EBox::debug("Sbz1:      <$sbz1>");
    EBox::debug("AclSize:   <$aclSize>");
    EBox::debug("AceCount:  <$aceCount>");
    EBox::debug("Sbz2:      <$sbz2>");

    unless ($sbz1 == 0) {
        throw EBox::Exceptions::Internal(
            "Invalid sbz1 value. Was $sbz1, expected 0");
    }
    unless ($sbz2 == 0) {
        throw EBox::Exceptions::Internal(
            "Invalid sbz2 value. Was $sbz2, expected 0");
    }

    # Decode ACE entries. Skip the 8 bytes ACL header.
    my $aceOffset = 0;
    my $aclBlob = substr($blob, $blobOffset + 8, $blobOffset + $aclSize + 8);
    for (my $i = 0; $i < $aceCount; $i++) {
        EBox::debug("Decoding ACE");
        my $ace = $self->_decodeACE($aclBlob, $aceOffset);
        $self->addACE($ace);
        $aceOffset += $ace->size();
    }
}

1;
