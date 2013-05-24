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

# Class: EBox::UsersAndGroups::InetOrgPerson
#
#   Zentyal organizational person, stored in LDAP
#

package EBox::UsersAndGroups::InetOrgPerson;

use base 'EBox::UsersAndGroups::LdapObject';

use EBox::Global;
use EBox::Gettext;
use EBox::UsersAndGroups::Group;

use EBox::Exceptions::LDAP;
use EBox::Exceptions::DataExists;

use Perl6::Junction qw(any);
use Error qw(:try);
use Convert::ASN1;
use Net::LDAP::Entry;
use Net::LDAP::Constant qw(LDAP_LOCAL_ERROR);

sub new
{
    my $class = shift;
    my %opts = @_;
    my $self;

    $self = $class->SUPER::new(@_);
    $self->{coreAttrs} = ['cn', 'givenName', 'initials', 'sn', 'displayName', 'description'];

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
    return $self->get('givenName');
}

sub initials
{
    my ($self) = @_;
    return $self->get('initials');
}

sub surname
{
    my ($self) = @_;
    return $self->get('sn');
}

sub displayname
{
    my ($self) = @_;
    return $self->get('displayName');
}

sub comment
{
    my ($self) = @_;
    return $self->get('description');
}

# Catch some of the set ops which need special actions
sub set
{
    my ($self, $attr, $value) = @_;

    # remember changes in core attributes (notify LDAP user base modules)
    if ($attr eq any $self->{coreAttrs}) {
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
    if ($attr eq any $self->{coreAttrs}) {
        $self->{core_changed} = 1;
    }

    shift @_;
    $self->SUPER::delete(@_);
}

# Method: setIgnoredModules
#
#   Set the modules that should not be notified of the changes
#   made to this object
#
# Parameters:
#
#   mods - Array reference cotaining module names
#
sub setIgnoredModules
{
    my ($self, $mods) = @_;
    $self->{ignoreMods} = $mods;
}

# Method: setIgnoredSlaves
#
#   Set the slaves that should not be notified of the changes
#   made to this object
#
# Parameters:
#
#   mods - Array reference cotaining slave names
#
sub setIgnoredSlaves
{
    my ($self, $slaves) = @_;
    $self->{ignoreSlaves} = $slaves;
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
#   Returns:
#
#       array ref of EBox::UsersAndGroups::Group objects
#
sub groups
{
    my ($self) = @_;

    return $self->_groups();
}

# Method: groupsNotIn
#
#   Groups this inetOrgPerson does not belong to
#
#   Returns:
#
#       array ref of EBox::UsersAndGroups::Group objects
#
sub groupsNotIn
{
    my ($self) = @_;

    return $self->_groups(1);
}

sub _groups
{
    my ($self, $invert) = @_;

    my $filter;
    my $dn = $self->dn();
    if ($invert) {
        $filter = "(&(objectclass=zentyalGroup)(!(member=$dn)))";
    } else {
        $filter = "(&(objectclass=zentyalGroup)(member=$dn))";
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
            push (@groups, new EBox::UsersAndGroups::Group(entry => $entry));
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
    my ($self, $person) = @_;
    my $fullname = '';

    if ($person->{givenname}) {
        $fullname = $person->{givenname} . ' ';
    }
    if ($person->{initials}) {
        $fullname .= $person->{initials} . '. ';
    }
    if ($person->{surname}) {
        $fullname .= $person->{surname};
    }
    return $fullname
}

# Method: create
#
#       Adds a new inetOrgPerson
#
# Parameters:
#
#   person - hash ref containing:
#       dn  - The DN path where this person should be stored.
#       fullname
#       givenname
#       initials
#       surname
#       displayname
#       comment
#       ou (multiple_ous enabled only)
#   params hash (all optional):
#      ignoreMods - modules that should not be notified about the person creation
#      ignoreSlaves - slaves that should not be notified about the person creation
#   extraAttributes
#
# Returns:
#
#   Returns the new create person object
#
sub create
{
    my ($self, $person, %params) = @_;

    unless (defined $person->{dn}) {
        throw EBox::Exceptions::MissingArgument("person->{dn}");
    }

    my $users = EBox::Global->modInstance('users');

    # Verify person exists
    if (new EBox::UsersAndGroups::InetOrgPerson(dn => $person->{dn})->exists()) {
        throw EBox::Exceptions::DataExists('data' => __('person'),
                                           'value' => $person->{dn});
    }

    $person->{fullname} = self->generatedFullName($person) unless (defined $person->{fullname});

    my @attr = ();
    push (@attr, objectClass => 'inetOrgPerson');
    push (@attr, cn          => $person->{fullname}) if defined $person->{fullname};
    push (@attr, givenName   => $person->{givenname}) if defined $person->{givenname};
    push (@attr, initials    => $person->{initials}) if defined $person->{initials};
    push (@attr, sn          => $person->{surname}) if defined $person->{surname};
    push (@attr, displayName => $person->{displayname}) if defined $person->{displayname};
    push (@attr, description => $person->{comment}) if defined $person->{comment};

    my $res = undef;
    my $entry = undef;
    try {
        # Call modules initialization. The notified modules can modify the entry,
        # add or delete attributes.
        $entry = new Net::LDAP::Entry($person->{dn}, @attr);

        my $result = $entry->update($self->_ldap->{ldap});
        if ($result->is_error()) {
            unless ($result->code == LDAP_LOCAL_ERROR and $result->error eq 'No attributes to update') {
                throw EBox::Exceptions::LDAP(
                    message => __('Error on person LDAP entry creation:'),
                    result => $result,
                    opArgs => $self->entryOpChangesInUpdate($entry),
                   );
            };
        }

        $res = new EBox::UsersAndGroups::InetOrgPerson(dn => $person->{dn});

    } otherwise {
        my ($error) = @_;

        EBox::error($error);

        if (defined $res and $res->exists()) {
            $res->SUPER::deleteObject(@_);
        }
        $res = undef;
        $entry = undef;
        throw $error;
    };

    if ($res->{core_changed}) {
        $res->save();
    }

    # Return the new created person
    return $res;
}

1;
