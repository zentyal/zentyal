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

# Class: EBox::Samba::Security::ACE
#
#   An access control entry (ACE) is used to encode the user rights afforded
#   to a principal, either a user or group. This is generally done by
#   combining an ACCESS_MASK and the SID of the principal.
#
# Documentation:
#
#   [MS-DTYP] — v20130118
#       Windows Data Types
#       Copyright © 2013 Microsoft Corporation.
#
package EBox::Samba::Security::ACE;

use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::InvalidArgument;
use EBox::Exceptions::NotImplemented;

use Error qw(:try);

use constant ACE_TYPE_ACCESS_ALLOWED                    => 0x00;
use constant ACE_TYPE_ACCESS_DENIED                     => 0x01;
use constant ACE_TYPE_SYSTEM_AUDIT                      => 0x02;
use constant ACE_TYPE_SYSTEM_ALARM                      => 0x03;
use constant ACE_TYPE_ACCESS_ALLOWED_COMPOUND           => 0x04;
use constant ACE_TYPE_ACCESS_ALLOWED_OBJECT             => 0x05;
use constant ACE_TYPE_ACCESS_DENIED_OBJECT              => 0x06;
use constant ACE_TYPE_SYSTEM_AUDIT_OBJECT               => 0x07;
use constant ACE_TYPE_SYSTEM_ALARM_OBJECT               => 0x08;
use constant ACE_TYPE_ACCESS_ALLOWED_CALLBACK           => 0x09;
use constant ACE_TYPE_ACCESS_DENIED_CALLBACK            => 0x0A;
use constant ACE_TYPE_ACCESS_ALLOWED_CALLBACK_OBJECT    => 0x0B;
use constant ACE_TYPE_ACCESS_DENIED_CALLBACK_OBJECT     => 0x0C;
use constant ACE_TYPE_SYSTEM_AUDIT_CALLBACK             => 0x0D;
use constant ACE_TYPE_SYSTEM_ALARM_CALLBACK             => 0x0E;
use constant ACE_TYPE_SYSTEM_AUDIT_CALLBACK_OBJECT      => 0x0F;
use constant ACE_TYPE_SYSTEM_ALARM_CALLBACK_OBJECT      => 0x10;
use constant ACE_TYPE_SYSTEM_MANDATORY_LABEL            => 0x11;
use constant ACE_TYPE_SYSTEM_RESOURCE_ATTRIBUTE         => 0x12;
use constant ACE_TYPE_SYSTEM_SCOPED_POLICY_ID           => 0x13;

use constant ACE_FLAG_CONTAINER_INHERIT     => 0x02;
use constant ACE_FLAG_FAILED_ACCESS         => 0x80;
use constant ACE_FLAG_INHERIT_ONLY          => 0x08;
use constant ACE_FLAG_INHERITED             => 0x10;
use constant ACE_FLAG_NO_PROPAGATE_INHERIT  => 0x04;
use constant ACE_FLAG_OBJECT_INHERIT        => 0x01;
use constant ACE_FLAG_SUCCESSFUL_ACCESS     => 0x40;

sub new
{
    my ($class, %params) = @_;

    my $self = {};
    bless ($self, $class);

    unless (defined $params{blob}) {
        throw EBox::Exceptions::MissingArgument('blob');
    }

    if (defined $params{blob}) {
        $self->_decode($params{blob}, $params{blobOffset});
    }

    return $self;
}

sub size
{
    my ($self) = @_;

    return $self->{aceSize};
}


sub flags
{
    my ($self) = @_;

    return $self->{aceFlags};
}

sub type
{
    my ($self) = @_;

    return $self->{aceType};
}

1;
