#!/usr/bin/perl -w

# Copyright (C) 2012-2013 Zentyal S.L.
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

# Class: EBox::UsersAndGroups::User
#
#   Zentyal user, stored in LDAP
#

package EBox::UsersAndGroups::User::ExternalAD;

use base 'EBox::UsersAndGroups::User';

use EBox::Config;
use EBox::Global;
use EBox::Gettext;
use EBox::UsersAndGroups;
use EBox::UsersAndGroups::Group;

use EBox::Exceptions::External;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::LDAP;

use Perl6::Junction qw(any);
use Error qw(:try);
use Convert::ASN1;
use Net::LDAP::Entry;
use Net::LDAP::Constant qw(LDAP_LOCAL_ERROR);

use constant MAXUSERLENGTH  => 128;
use constant MAXPWDLENGTH   => 512;
use constant SYSMINUID      => 1900;
use constant MINUID         => 2000;
use constant MAXUID         => 2**31;
use constant HOMEPATH       => '/home';
use constant QUOTA_PROGRAM  => EBox::Config::scripts('users') . 'user-quota';
use constant QUOTA_LIMIT    => 2097151;
use constant CORE_ATTRS     => ( 'cn', 'uid', 'sn', 'givenName',
                                 'loginShell', 'uidNumber', 'gidNumber',
                                 'homeDirectory', 'quota', 'userPassword',
                                 'description', 'krb5Key');

sub new
{
    my $class = shift;
    my %opts = @_;
    my $self = {};

    if (defined $opts{uid}) {
        $self->{uid} = $opts{uid};
    } else {
        $self = $class->SUPER::new(@_);
    }

    bless ($self, $class);
    return $self;
}

sub mainObjectClass
{
    return 'user';
}

sub dnComponent
{
    return 'cn=Users';
}

# Method: _entry
#
#   Return Net::LDAP::Entry entry for the user
#
sub _entry
{
    my ($self) = @_;

    unless ($self->{entry}) {
        # XXX cahgne for AD
        if (defined $self->{uid}) {
            my $result = undef;
            my $attrs = {
                base => $self->_ldap->dn(),
                filter => "(uid=$self->{uid})",
                scope => 'sub',
            };
            $result = $self->_ldap->search($attrs);
            if ($result->count() > 1) {
                throw EBox::Exceptions::Internal(
                    __x('Found {count} results for, expected only one.',
                        count => $result->count()));
            }
            $self->{entry} = $result->entry(0);
        } else {
            $self->SUPER::_entry();
        }
    }
    return $self->{entry};
}

# Method: name
#
#   Return user name
#
sub name
{
    my ($self) = @_;
    EBox::debug("NAME called " .  $self->get('samaccountname'));

    return $self->get('samaccountname');
}

sub fullname
{
    my ($self) = @_;
    my $fullname = $self->get('displayName');
    if (not $fullname) {
        $fullname = $self->get('name');
    }
    return $fullname;
}

sub firstname
{
    my ($self) = @_;
    return $self->get('givenName');
}

sub surname
{
    my ($self) = @_;
    # XXX look for equivalent
    return 'surname';
    return $self->get('sn');
}

sub home
{
    my ($self) = @_;
    return $self->get('homeDirectory');
}

sub quota
{
    my ($self) = @_;
    # XXX look for equivalent
    return '';
    return $self->get('quota');
}

sub comment
{
    my ($self) = @_;
    return $self->get('description');
}

# ?>>
sub internal
{
    my ($self) = @_;

    my $title = $self->get('title');
    return (defined ($title) and ($title eq 'internal'));
}

sub _groups
{
    my ($self, $system, $invert) = @_;

}

sub groups
{
    # XXX
    return [];
}

sub groupsNotIn
{
    return [];
}

sub system
{
    my ($self) = @_;

    # XXX look gor more attributes
    return $self->get('isCriticalSystemObject');
}

1;
