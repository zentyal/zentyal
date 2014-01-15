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

# Class: EBox::Users::InetOrgPerson
#
#   Zentyal organizational person, stored in LDAP
#

package EBox::Users::InetOrgPerson;

use base 'EBox::Users::LdapObject';

use EBox::Global;
use EBox::Gettext;
use EBox::Users::Group;

use EBox::Exceptions::LDAP;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::MissingArgument;

use Perl6::Junction qw(any);
use TryCatch::Lite;
use Convert::ASN1;
use Net::LDAP::Entry;
use Net::LDAP::Constant qw(LDAP_LOCAL_ERROR);

sub new
{
    my $class = shift;
    my %opts = @_;
    my $self;

    if (defined $opts{idField} and defined $opts{$opts{idField}}) {
        $self = {};
    } else {
        $self = $class->SUPER::new(@_);
    }
    $self->{coreAttrs} = ['cn', 'givenName', 'initials', 'sn', 'displayName', 'description', 'mail'];

    if (defined $opts{coreAttrs}) {
        push ($self->{coreAttrs}, $opts{coreAttrs});
    }

    bless ($self, $class);
    return $self;
}

sub fullname
{
    my ($self) = @_;
    return $self->get('cn');
}

sub firstname
{
    my ($self) = @_;
    my $firstname =  $self->get('givenName');
    if (not $firstname) {
        return '';
    }
    return $firstname;
}

sub initials
{
    my ($self) = @_;
    return $self->get('initials');
}

sub surname
{
    my ($self) = @_;
    my $sn = $self->get('sn');
    if (not $sn) {
        return '';
    }
    return $sn;
}

sub displayname
{
    my ($self) = @_;
    return $self->get('displayName');
}

sub description
{
    my ($self) = @_;
    return $self->get('description');
}

sub mail
{
    my ($self) = @_;

    return $self->get('mail');
}

# Catch some of the set ops which need special actions
sub set
{
    my ($self, $attr, $value) = @_;

    # remember changes in core attributes (notify LDAP user base modules)
    if ($attr eq any(@{$self->{coreAttrs}})) {
        $self->{core_changed} = 1;
    }

    shift @_;
    $self->SUPER::set(@_);
}

sub save
{
    my ($self) = @_;


    shift @_;
    $self->SUPER::save(@_);

    my $changetype = $self->_entry->changetype();
    if (($changetype ne 'delete') and $self->{core_changed}) {
        delete $self->{core_changed};
    }
}

# Catch some of the delete ops which need special actions
sub delete
{
    my ($self, $attr, $value) = @_;

    # remember changes in core attributes (notify LDAP user base modules)
    if ($attr eq any(@{$self->{coreAttrs}})) {
        $self->{core_changed} = 1;
    }

    shift @_;
    $self->SUPER::delete(@_);
}

# Method: addGroup
#
#   Add this inetOrgPerson to the given group
#
# Parameters:
#
#   group - Group object
#
sub addGroup
{
    my ($self, $group) = @_;

    $group->addMember($self);
}

# Method: removeGroup
#
#   Removes this inetOrgPerson from the given group
#
# Parameters:
#
#   group - Group object
#
sub removeGroup
{
    my ($self, $group) = @_;

    $group->removeMember($self);
}

# Method: groups
#
#   Groups this inetOrgPerson belongs to
#
# Parameters:
#
#   %params - Hash to control which groups to skip or include.
#       - internal
#       - system
#
# Returns:
#
#   Array ref of EBox::Users::Group objects
#
sub groups
{
    my ($self, %params) = @_;

    return $self->_groups(%params);
}

# Method: groupsNotIn
#
#   Groups this inetOrgPerson does not belong to
#
# Parameters:
#
#   %params - Hash to control which groups to skip or include.
#       - internal
#       - system
#
# Returns:
#
#   Array ref of EBox::Users::Group objects
#
sub groupsNotIn
{
    my ($self, %params) = @_;

    $params{invert} = 1;

    return $self->_groups(%params);
}

sub _groups
{
    my ($self, %params) = @_;

    my $filter;
    my $dn = $self->dn();

    my $usersMod = $self->_usersMod();
    my $groupClass = $usersMod->groupClass();
    my $groupObjectClass = $groupClass->mainObjectClass();
    if ($params{invert}) {
        $filter = "(&(objectclass=$groupObjectClass)(!(member=$dn)))";
    } else {
        $filter = "(&(objectclass=$groupObjectClass)(member=$dn))";
    }

    my %attrs = (
        base => $self->_ldap->dn(),
        filter => $filter,
        scope => 'sub',
    );

    my $result = $self->_ldap->search(\%attrs);

    my @groups;
    if ($result->count > 0) {
        foreach my $entry ($result->entries()) {
            my $groupObject = $groupClass->new(entry => $entry);
            push (@groups, $groupObject);
        }
        # sort grups by name
        @groups = sort {
            my $aValue = $a->name();
            my $bValue = $b->name();
            (lc $aValue cmp lc $bValue) or
                ($aValue cmp $bValue)
        } @groups;
    }
    return \@groups;
}

# Method: deleteObject
#
#   Delete the inetOrgPerson
#
sub deleteObject
{
    my ($self) = @_;

    # remove this inetOrgPerson from all its grups
    foreach my $group (@{$self->groups()}) {
        $self->removeGroup($group);
    }

    # Mark as changed to process save
    $self->{core_changed} = 1;

    # Call super implementation
    shift @_;
    $self->SUPER::deleteObject(@_);
}

sub generatedFullName
{
    my ($self, %args) = @_;
    my $fullname = '';

    if ($args{givenname}) {
        $fullname = $args{givenname} . ' ';
    }
    if ($args{initials}) {
        $fullname .= $args{initials} . '. ';
    }
    if ($args{surname}) {
        $fullname .= $args{surname};
    }
    return $fullname
}

# Method: create
#
#       Adds a new inetOrgPerson
#
# Parameters:
#
#   args - Named parameters:
#       fullname - Full name.
#       dn       - The DN string to identify this person.
#       givenname
#       initials
#       surname
#       displayname
#       description
#       mail
#       ignoreMods   - modules that should not be notified about the person creation
#       ignoreSlaves - slaves that should not be notified about the person creation
#
# Returns:
#
#   Returns the new create person object
#
sub create
{
    my ($class, %args) = @_;

    throw EBox::Exceptions::MissingArgument('dn') unless ($args{dn});

    # Verify person exists
    if (new EBox::Users::InetOrgPerson(dn => $args{dn})->exists()) {
        throw EBox::Exceptions::DataExists('data' => __('person'),
                                           'value' => $args{dn});
    }

    my $fullname = $args{fullname};
    $fullname = $class->generatedFullName(%args) unless ($fullname);

    my @attr = ();
    push (@attr, objectClass => 'inetOrgPerson');
    push (@attr, cn          => $fullname);
    push (@attr, givenName   => $args{givenname}) if ($args{givenname});
    push (@attr, initials    => $args{initials}) if ($args{initials});
    push (@attr, sn          => $args{surname}) if ($args{surname});
    push (@attr, displayName => $args{displayname}) if ($args{displayname});
    push (@attr, description => $args{description}) if ($args{description});
    push (@attr, mail        => $args{mail}) if ($args{mail});

    my $res = undef;
    my $entry = undef;
    try {
        # Call modules initialization. The notified modules can modify the entry,
        # add or delete attributes.
        $entry = new Net::LDAP::Entry($args{dn}, @attr);

        my $result = $entry->update($class->_ldap->{ldap});
        if ($result->is_error()) {
            unless ($result->code == LDAP_LOCAL_ERROR and $result->error eq 'No attributes to update') {
                throw EBox::Exceptions::LDAP(
                    message => __('Error on person LDAP entry creation:'),
                    result => $result,
                    opArgs => $class->entryOpChangesInUpdate($entry),
                   );
            };
        }

        $res = new EBox::Users::InetOrgPerson(dn => $args{dn});

    } catch ($error) {
        EBox::error($error);

        if (defined $res and $res->exists()) {
            $res->SUPER::deleteObject(@_);
        }
        $res = undef;
        $entry = undef;
        throw $error;
    }

    if ($res->{core_changed}) {
        $res->save();
    }

    # Return the new created person
    return $res;
}

1;
