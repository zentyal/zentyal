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

sub mainObjectClass
{
    return 'user';
}

sub dnComponent
{
    return 'cn=Users';
}

sub groupClass
{
    return 'EBox::UsersAndGroups::Group::ExternalAD';
}

# Method: name
#
#   Return user name
#
sub name
{
    my ($self) = @_;
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


sub system
{
    my ($self) = @_;

    # XXX look gor more attributes
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
