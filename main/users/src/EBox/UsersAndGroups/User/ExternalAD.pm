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

# Class: EBox::UsersAndGroups::User::ExternalAD
#
#   User retrieved from external AD
#

package EBox::UsersAndGroups::User::ExternalAD;
use base 'EBox::UsersAndGroups::User';

use EBox::Config;
use EBox::Global;
use EBox::Gettext;
use EBox::UsersAndGroups;

use EBox::Exceptions::External;
use EBox::Exceptions::UnwillingToPerform;

use Perl6::Junction qw(any);
use Error qw(:try);
use Convert::ASN1;
use Net::LDAP::Entry;
use Net::LDAP::Constant qw(LDAP_LOCAL_ERROR);

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

# Method: mainObjectClass
#
#  Overrides:
#    EBox::UsersAndGroups::User::mainObjectClass
sub mainObjectClass
{
    return 'user';
}

# Method: dnComponent
#
#  Overrides:
#    EBox::UsersAndGroups::User::dnComponent
sub dnComponent
{
    return 'cn=Users';
}

# Method: groupClass
#
#  Overrides:
#    EBox::UsersAndGroups::User::groupClass
sub groupClass
{
    return 'EBox::UsersAndGroups::Group::ExternalAD';
}

# Method: dnLeftmostAttribute
#
#  Overrides:
#    EBox::UsersAndGroups::User::dnLeftmostattribute
sub dnLeftmostAttribute
{
    return 'cn';
}

# Method: name
#
#   This uses the sAMAccountName attribute as user name
#
#  Overrides:
#   EBox::UsersAndGroups::User::name
sub name
{
    my ($self) = @_;
    return $self->get('samaccountname');
}

# Method: fullname
#
#   This uses the displayName attribute as user full name. If not available it
#   fall backs to the name attribute
#
#  Overrides:
#   EBox::UsersAndGroups::User::fullname
sub fullname
{
    my ($self) = @_;
    my $fullname = $self->get('displayName');
    if (not $fullname) {
        $fullname = $self->get('name');
    }
    return $fullname;
}

# Method: quota
#
#   No quota suport for external AD users, so we return empty string
#
#  Overrides:
#   EBox::UsersAndGroups::User::quota
sub quota
{
    my ($self) = @_;
    return '';
}

sub system
{
    my ($self) = @_;

    # XXX look for more attributes ?
    return $self->get('isCriticalSystemObject');
}

sub set
{
    throw EBox::Exceptions::UnwillingToPerform(reason => 'External AD users cannot be modified');
}

sub delete
{
    throw EBox::Exceptions::UnwillingToPerform(reason => 'External AD users cannot be modified');
}

sub save
{
    throw EBox::Exceptions::UnwillingToPerform(reason => 'External AD users cannot be modified');
}

sub changePassword
{
    throw EBox::Exceptions::UnwillingToPerform(reason => 'Cannot change the password of external AD users');
}

sub setPasswordFromHashes
{
    throw EBox::Exceptions::UnwillingToPerform( reason =>'Cannot change the password of external AD users');
}

sub deleteObject
{
    throw EBox::Exceptions::UnwillingToPerform(reason => 'External AD users cannot be modified');
}

sub quotaAvailable
{
    return 0;
}

1;
