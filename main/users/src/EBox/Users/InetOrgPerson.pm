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
use Error qw(:try);
use Convert::ASN1;
use Net::LDAP::Entry;
use Net::LDAP::Constant qw(LDAP_LOCAL_ERROR);

use constant MAXFIRSTNAMELENGTH   =>   64;
use constant MAXINITIALSLENGTH    =>    6;
use constant MAXSURNAMELENGTH     =>   64;
use constant MAXFULLNAMELENGTH    =>   64;
use constant MAXDISPLAYNAMELENGTH =>  256;
use constant MAXDESCRIPTIONLENGTH => 1024;
use constant MAXMAILLENGTH        =>  256;

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

# Method: checkFirstnameFormat
#
#   Checks whether the given argument matches the restrictions to be used as a firstname field. Right now it just
#   checks the string lenght restriction.
#
# Parameters:
#
#   firstname - String
#
# Throws <EBox::Exceptions::InvalidArgument> if there is anything wrong with the format to be used as firstname.
#
sub checkFirstnameFormat
{
    my ($class, $firstname) = @_;

    unless (defined $firstname) {
        throw EBox::Exceptions::InvalidArgument("firstname");
    }

    if (length ($firstname) > MAXFIRSTNAMELENGTH) {
        throw EBox::Exceptions::InvalidData(
            'data' => __('first name'),
            'value' => $firstname,
            'advice' => __x('cannot be longer than {limit} characters', limit => MAXFIRSTNAMELENGTH)
           );
    }

}

# Method: checkInitialsFormat
#
#   Checks whether the given argument matches the restrictions to be used as a initials field. Right now it just
#   checks the string lenght restriction.
#
# Parameters:
#
#   initials - String
#
# Throws <EBox::Exceptions::InvalidArgument> if there is anything wrong with the format to be used as initials.
#
sub checkInitialsFormat
{
    my ($class, $initials) = @_;

    unless (defined $initials) {
        throw EBox::Exceptions::InvalidArgument("initials");
    }

    if (length ($initials) > MAXINITIALSLENGTH) {
        throw EBox::Exceptions::InvalidData(
            'data' => __('initials'),
            'value' => $initials,
            'advice' => __x('cannot be longer than {limit} characters', limit => MAXINITIALSLENGTH)
           );
    }

}

# Method: checkSurnameFormat
#
#   Checks whether the given argument matches the restrictions to be used as a surname field. Right now it just
#   checks the string lenght restriction.
#
# Parameters:
#
#   surname - String
#
# Throws <EBox::Exceptions::InvalidArgument> if there is anything wrong with the format to be used as surname.
#
sub checkSurnameFormat
{
    my ($class, $surname) = @_;

    unless (defined $surname) {
        throw EBox::Exceptions::InvalidArgument("surname");
    }

    if (length ($surname) > MAXSURNAMELENGTH) {
        throw EBox::Exceptions::InvalidData(
            'data' => __('surname'),
            'value' => $surname,
            'advice' => __x('cannot be longer than {limit} characters', limit => MAXSURNAMELENGTH)
           );
    }

}

# Method: checkFullnameFormat
#
#   Checks whether the given argument matches the restrictions to be used as a fullname field. Right now it just
#   checks the string lenght restriction.
#
# Parameters:
#
#   fullname - String
#
# Throws <EBox::Exceptions::InvalidArgument> if there is anything wrong with the format to be used as fullname.
#
sub checkFullnameFormat
{
    my ($class, $fullname) = @_;

    unless (defined $fullname) {
        throw EBox::Exceptions::InvalidArgument("fullname");
    }

    if (length ($fullname) > MAXFULLNAMELENGTH) {
        throw EBox::Exceptions::InvalidData(
            'data' => __('fullname'),
            'value' => $fullname,
            'advice' => __x('cannot be longer than {limit} characters', limit => MAXFULLNAMELENGTH)
           );
    }

}

# Method: checkDisplaynameFormat
#
#   Checks whether the given argument matches the restrictions to be used as a displayname field. Right now it just
#   checks the string lenght restriction.
#
# Parameters:
#
#   displayname - String
#
# Throws <EBox::Exceptions::InvalidArgument> if there is anything wrong with the format to be used as displayname.
#
sub checkDisplaynameFormat
{
    my ($class, $displayname) = @_;

    unless (defined $displayname) {
        throw EBox::Exceptions::InvalidArgument("displayname");
    }

    if (length ($displayname) > MAXDISPLAYNAMELENGTH) {
        throw EBox::Exceptions::InvalidData(
            'data' => __('displayname'),
            'value' => $displayname,
            'advice' => __x('cannot be longer than {limit} characters', limit => MAXDISPLAYNAMELENGTH)
           );
    }

}

# Method: checkDescriptionFormat
#
#   Checks whether the given argument matches the restrictions to be used as a description field. Right now it just
#   checks the string lenght restriction.
#
# Parameters:
#
#   description - String
#
# Throws <EBox::Exceptions::InvalidArgument> if there is anything wrong with the format to be used as description.
#
sub checkDescriptionFormat
{
    my ($class, $description) = @_;

    unless (defined $description) {
        throw EBox::Exceptions::InvalidArgument("description");
    }

    if (length ($description) > MAXDESCRIPTIONLENGTH) {
        throw EBox::Exceptions::InvalidData(
            'data' => __('description'),
            'value' => $description,
            'advice' => __x('cannot be longer than {limit} characters', limit => MAXDESCRIPTIONLENGTH)
           );
    }

}

# Method: checkMailFormat
#
#   Checks whether the given argument matches the restrictions to be used as a mail field. Right now it just
#   checks the string lenght restriction.
#
# Parameters:
#
#   mail - String
#
# Throws <EBox::Exceptions::InvalidArgument> if there is anything wrong with the format to be used as mail.
#
sub checkMailFormat
{
    my ($class, $mail) = @_;

    unless (defined $mail) {
        throw EBox::Exceptions::InvalidArgument("mail");
    }

    if (length ($mail) > MAXMAILLENGTH) {
        throw EBox::Exceptions::InvalidData(
            'data' => __('mail'),
            'value' => $mail,
            'advice' => __x('cannot be longer than {limit} characters', limit => MAXMAILLENGTH)
           );
    }

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
    $class->checkFullnameFormat($fullname);

    my @attr = ();
    push (@attr, objectClass => 'inetOrgPerson');
    push (@attr, cn          => $fullname);
    if ($args{givenname}) {
        $class->checkFirstnameFormat($args{givenname});
        push (@attr, givenName   => $args{givenname});
    }
    if ($args{initials}) {
        $class->checkInitialsFormat($args{initials});
        push (@attr, initials    => $args{initials});
    }
    if ($args{surname}) {
        $class->checkSurnameFormat($args{surname});
        push (@attr, sn          => $args{surname});
    }
    if ($args{displayname}) {
        $class->checkDisplaynameFormat($args{displayname});
        push (@attr, displayName => $args{displayname});
    }
    if ($args{description}) {
        $class->checkDisplaynameFormat($args{description});
        push (@attr, description => $args{description});
    }
    if ($args{mail}) {
        $class->checkDisplaynameFormat($args{mail});
        push (@attr, mail        => $args{mail});
    }

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
