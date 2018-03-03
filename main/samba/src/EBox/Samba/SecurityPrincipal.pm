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

# Class: EBox::Samba::SecurityPrincipal
#
#   This class is an abstraction for LDAP objects implementing the
#   SecurityPrincipal auxiliary class
#
package EBox::Samba::SecurityPrincipal;
use base 'EBox::Samba::OrganizationalPerson';

use EBox::Gettext;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::Internal;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::MissingArgument;

use TryCatch;
use Net::LDAP::Util qw(escape_filter_value);

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
#      samAccountName
#  or
#      sid
#
sub new
{
    my ($class, %params) = @_;

    my $self = {};
    bless ($self, $class);

    if ($params{samAccountName}) {
        $self->{samAccountName} = $params{samAccountName};
    } elsif ($params{sid}) {
        $self->{sid} = $params{sid};
    } else {
        try {
            $self = $class->SUPER::new(%params);
        } catch (EBox::Exceptions::MissingArgument $e) {
            throw EBox::Exceptions::MissingArgument("$e|samAccountName|sid");
        }
    }
    return $self;
}

# Method: _entry
#
#   Return Net::LDAP::Entry entry for the object
#
sub _entry
{
    my ($self) = @_;

    unless ($self->{entry}) {
        my $result = undef;
        if (defined $self->{samAccountName}) {
            my $value = escape_filter_value($self->{samAccountName});
            my $attrs = {
                base => $self->_ldap->dn(),
                filter => "(samAccountName=$value)",
                scope => 'sub',
                attrs => ['*', 'unicodePwd', 'supplementalCredentials'],
            };
            $result = $self->_ldap->search($attrs);
        } elsif (defined $self->{sid}) {
            my $attrs = {
                base => $self->_ldap->dn(),
                filter => "(objectSid=$self->{sid})",
                scope => 'sub',
                attrs => ['*', 'unicodePwd', 'supplementalCredentials'],
            };
            $result = $self->_ldap->search($attrs);
        } else {
            return $self->SUPER::_entry();
        }
        return undef unless defined $result;

        if ($result->count() > 1) {
            throw EBox::Exceptions::Internal(
                __x('Found {count} results for, expected only one.',
                    count => $result->count()));
        }

        $self->{entry} = $result->entry(0);
    }

    return $self->{entry};
}

# Method: sid
#
#    Get the objectSID in string representation
#
# Returns:
#
#    String - the object SID
#
sub sid
{
    my ($self) = @_;

    my $sid = $self->get('objectSid');
    my $sidString = $self->_sidToString($sid);
    return $sidString;
}

sub _sidToString
{
    my ($self, $sid) = @_;

    return undef
        unless unpack("C", substr($sid, 0, 1)) == 1;

    return undef
        unless length($sid) == 8 + 4 * unpack("C", substr($sid, 1, 1));

    my $sid_str = "S-1-";

    $sid_str .= (unpack("C", substr($sid, 7, 1)) +
                (unpack("C", substr($sid, 6, 1)) << 8) +
                (unpack("C", substr($sid, 5, 1)) << 16) +
                (unpack("C", substr($sid, 4, 1)) << 24));

    for my $loop (0 .. unpack("C", substr($sid, 1, 1)) - 1) {
        $sid_str .= "-" . unpack("I", substr($sid, 4 * $loop + 8, 4));
    }

    return $sid_str;
}

sub _stringToSid
{
    my ($self, $sidString) = @_;

    return undef
        unless uc(substr($sidString, 0, 4)) eq "S-1-";

    my ($auth_id, @sub_auth_id) = split(/-/, substr($sidString, 4));

    my $sid = pack("C4", 1, $#sub_auth_id + 1, 0, 0);

    $sid .= pack("C4", ($auth_id & 0xff000000) >> 24, ($auth_id &0x00ff0000) >> 16,
            ($auth_id & 0x0000ff00) >> 8, $auth_id &0x000000ff);

    for my $loop (0 .. $#sub_auth_id) {
        $sid .= pack("I", $sub_auth_id[$loop]);
    }

    return $sid;
}

sub _checkAccountName
{
    my ($self, $name, $maxLength) = @_;

    my $advice = undef;

    if ($name =~ m/\.$/) {
        $advice = __('Windows account names cannot end with a dot');
    } elsif ($name =~ m/^-/) {
        $advice = __('Windows account names cannot start with a dash');
    } elsif (not $name =~ /^[a-zA-Z\d\s_\-\.]+$/) {
        $advice = __('To avoid problems, the account name should ' .
                     'consist only of letters, digits, underscores, ' .
                      'spaces, periods, and dashes'
               );
    } elsif (length ($name) > $maxLength) {
        $advice = __x("Account name must not be longer than {maxLength} characters",
                       maxLength => $maxLength);
    }

    if ($advice) {
        throw EBox::Exceptions::InvalidData(
                'data' => __('account name'),
                'value' => $name,
                'advice' => $advice);
    }
}

sub _checkAccountNotExists
{
    my ($self, $samAccountName) = @_;

    my $obj = new EBox::Samba::SecurityPrincipal(samAccountName => $samAccountName);
    if ($obj->exists()) {
        my $dn = $obj->dn();
        throw EBox::Exceptions::DataExists(
            'data' => __('Account name'),
            'value' => "$samAccountName ($dn)");
    }
}

sub xidNumber
{
    my ($self) = @_;

    my $usersMod = EBox::Global->modInstance('samba');
    my $ldap = $usersMod->ldap();
    my $idmap = $ldap->idmap();

    my $xidNumber = $idmap->getXidNumberBySID($self->sid());

    unless (defined $xidNumber) {
        # This object lacks an XidNumber, we generate one.
        $xidNumber = $idmap->consumeNextXidNumber();
        my $object = $usersMod->entryModeledObject($self->_entry);
        if ($object->isa('EBox::Samba::User')) {
            $object->setupUidMapping($xidNumber);
        } elsif ($object->isa('EBox::Samba::Group')) {
            $object->setupGidMapping($xidNumber);
        } else {
            EBox::debug("Unknown object!");
        }
    }

    return $xidNumber;
}

# Method: unixId
#
#    Return a valid unix identifier (uidNumber or gidNumber) based on
#    the RID
#
# Parameters:
#
#    rid - String the relative identifier
#
# Returns:
#
#    Int - the unix valid identifier
#
sub unixId
{
    my ($self, $rid) = @_;

    # map Guest to nobody
    if ($rid == 501) {
        return 65534;
    }

    # Let 1000 users for UNIX
    return 2000 + $rid;
}

1;
