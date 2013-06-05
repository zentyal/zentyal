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

# Class: EBox::Samba::User
#
#   Samba user, stored in samba LDAP
#
package EBox::Samba::GPO;

use base 'EBox::Samba::LdbObject';

use EBox::Gettext;
use EBox::Exceptions::Internal;
use Perl6::Junction qw(any);

# Method: _entry
#
#   Return Net::LDAP::Entry entry for the GPO
#
sub _entry
{
    my ($self) = @_;

    unless ($self->{entry}) {
        my $entry = $self->SUPER::_entry();
        my @objectClasses = $entry->get('objectClass');
        unless (grep (/GroupPolicyContainer/i, @objectClasses)) {
            my $dn = $entry->dn();
            throw EBox::Exceptions::Internal("Object '$dn' is not a Group Policy Container");
        }
    }

    return $self->{entry};
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

    my $flags = $self->get('status');
    return ($flags & 0x11);
}

# Method: statusString
#
#   Returns the GPO status string representation
#
sub statusString
{
    my ($self) = @_;

    my $status = $self->status();
    if ($status == 0) {
        return __('Enabled');
    }
    if ($status == 1) {
        return __('User configuration disabled');
    }
    if ($status == 2) {
        return __('Computer configuration disabled');
    }
    if ($status == 3) {
        return __('All settings disabled');
    }

    throw EBox::Exceptions::Internal('Unknown GPO status');
}

1;
