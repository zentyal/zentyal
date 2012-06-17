# Copyright (C) 2008-2012 eBox Technologies S.L.
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

package EBox::Squid::Model::AccessRules;

use base 'EBox::Model::DataTable';

# Class:
#
#    EBox::Squid::Model::AccessRules
#
#
#   It subclasses <EBox::Model::DataTable>
#

use EBox;
use EBox::Global;
use EBox::Exceptions::Internal;
use EBox::Gettext;
use EBox::Types::Text;
use EBox::Squid::Types::TimePeriod;

use constant MAX_DG_GROUP => 99; # max group number allowed by dansguardian

# Method: _table
#
#
sub _table
{
    my ($self) = @_;

    my @tableHeader = (
        new EBox::Squid::Types::TimePeriod(
                fieldName => 'timePeriod',
                printableName => __('Time period'),
                help => __('Time period when the this rule is applied'),
                editable => 1,
        ),
        new EBox::Types::Select(
            fieldName     => 'object',
            foreignModel  => $self->modelGetter('objects', 'ObjectTable'),
            foreignField  => 'name',
            foreignNextPageField => 'members',
            printableName => __('Object'),
            unique        => 1,
            editable      => 1,
            optional      => 0,
        ),
        new EBox::Types::Select(
            fieldName     => 'group',
            printableName => __('Group'),

            populate      => \&populateGroups,
            unique        => 1,
            editable      => 1,
            optional      => 0,
            disableCache  => 1,

        ),
        new EBox::Types::Select(
            fieldName     => 'policy',
            printableName => __('Policy'),
            populate => sub {
               return [
                        {
                          value => 'allow',
                          printableValue => __('Allow')
                        },
                        {
                          value => 'deny',
                          printableValue => __('Deny')
                        },
                      ]
            },
            defaultValue => 'allow',
            editable => 1,
        ),
        new EBox::Types::Select(
            fieldName => 'profile',
            printableName => __('Filter profile'),

            foreignModel  => $self->modelGetter('squid', 'FilterProfiles'),
            foreignField  => 'name',

            editable      => 1,
        ),
    );

    my $dataTable =
    {
        tableName          => 'AccessRules',
        pageTitle          => __('HTTP Proxy'),
        printableTableName => __('Access Rules'),
        modelDomain        => 'Squid',
        defaultActions     => [ 'add', 'del', 'editField', 'changeView', 'move' ],
        tableDescription   => \@tableHeader,
        class              => 'dataTable',
        order              => 1,
        rowUnique          => 1,
        automaticRemove    => 1,
        printableRowName   => __('rule'),
        help               => __('Here you can filter, block or allow access by user group or network object. Rules are only applied during the selected time period.'),
    };
}

sub populateGroups
{
    my $userMod = EBox::Global->modInstance('users');
    my @groups;
    foreach my $group (@{$userMod->groups()}) {
        my $name = $group->name();
        push (@groups, { value => $name, printableValue => $name });
    }
    return \@groups;
}

sub validateTypedRow
{
    my ($self, $action, $params_r, $actual_r) = @_;

    my $squid = $self->parentModule();
    if ($squid->transproxy()) {
        #FIXME: do not allow auth by group in transparent proxy
        #throw EBox::Exceptions::External(__('Authorization policy is not compatible with transparent proxy mode'));
    }
}

sub existsGroupPolicy
{
    my ($self) = @_;
    my $nPolicies = @{ $self->ids() };
    return ($nPolicies > 0);
}

sub _checkTransProxy
{
    my ($self, $params_r, $actual_r) = @_;

    my $squid = EBox::Global->modInstance('squid');
    if (not $squid->transproxy()) {
        return;
    }

    if ($self->existsGroupPolicy()) {
        throw EBox::Exceptions::External(__('Source matching by user group is not compatible with transparent proxy mode'));
    }
}

sub usersByProfile
{
    my ($self) = @_;

    my %usersSeen;
    my %usersByProfile;

    my $usersMod = EBox::Global->modInstance('users');
    my $profilesModel = EBox::Global->modInstance('squid')->model('FilterProfiles');

    foreach my $id (@{ $self->ids() }) {
        my $row = $self->row($id);
        my $userGroup   = $row->elementByName('group')->printableValue();
        my $profile = $row->valueByName('profile');

        my @users;
        foreach my $user ( @{ $usersMod->usersInGroup($userGroup) } ) {
            if (exists $usersSeen{$user}) {
                next;
            }

            $usersSeen{$user} = 1;
            push @users, $user;
        }

        if (not exists $usersByProfile{$profile}) {
            $usersByProfile{$profile} = \@users;
        }
        else {
            push @{ $usersByProfile{$profile} }, @users;
        }
    }

    return \%usersByProfile;
}

sub groupsPolicies
{
    my ($self) = @_;

    my $userMod = EBox::Global->modInstance('users');

    my @groupsPol = map {
        my $row = $self->row($_);
        my $group =  $row->valueByName('group');
        my $allow = $row->valueByName('policy') eq 'allow';
        my $time = $row->elementByName('timePeriod');
        my $users =  $userMod->usersInGroup($group);

        if (@{ $users }) {
            my $grPol = { group => $group, users => $users, allow => $allow };
            if (not $time->isAllTime) {
                if (not $time->isAllWeek()) {
                    $grPol->{timeDays} = $time->weekDays();
                }

                my $hours = $time->hourlyPeriod();
                if ($hours) {
                    $grPol->{timeHours} = $hours;
                }
            }

            $grPol;
        }
        else {
            ()
        }

    } @{ $self->ids() };

    return \@groupsPol;
}

sub existsPoliciesForGroup
{
    my ($self, $group) = @_;
    foreach my $id (@{ $self->ids() }) {
        my $row = $self->row($id);
        my $userGroup   = $row->elementByName('group')->printableValue();
        if ($group eq $userGroup) {
            return 1;
        }
    }

    return 0;
}

sub delPoliciesForGroup
{
    my ($self, $group) = @_;
    my @ids = @{ $self->ids() };
    foreach my $id (@ids) {
        my $row = $self->row($id);
        my $userGroup   = $row->elementByName('group')->printableValue();
        if ($group eq $userGroup) {
            $self->removeRow($id);
        }
    }
}

sub objectsPolicies
{
    my ($self) = @_;

    my $objectMod = EBox::Global->modInstance('objects');

    my @obsPol = map {
        my $row = $self->row($_);

        my $obj           = $row->valueByName('object');
        my $addresses     = $objectMod->objectAddresses($obj);

        my $policy        = $row->elementByName('policy');

        my $timePeriod    = $row->elementByName('timePeriod');
        my $groupPolicy   = $row->subModel('groupPolicy');

        if (@{ $addresses }) {
            my $obPol = {
                object    => $obj,
                addresses => $addresses,
                auth      => 0, #FIXME
                allowAll  => 0, #FIXME
                filter    => 0, #FIXME
            };

            if (not $timePeriod->isAllTime) {
                if (not $timePeriod->isAllWeek()) {
                    $obPol->{timeDays} = $timePeriod->weekDays();
                }

                my $hours = $timePeriod->hourlyPeriod();
                if ($hours) {
                    $obPol->{timeHours} = $hours;
                }
            }

            $obPol->{groupsPolicies} = $groupPolicy->groupsPolicies();

            $obPol;
        }
        else {
            ()
        }

    } @{ $self->ids()  };

    return \@obsPol;
}

sub objectsProfiles
{
    my ($self) = @_;

    my %profileIdByRowId = %{ $self->profileModel->idByRowId() };

    my $objectMod = EBox::Global->modInstance('objects');

    my @profiles;
    # object policies have priority by position in table
    foreach my $id (@{ $self->ids()  }) {
        my $row = $self->row($id);
        my $profile = $row->valueByName('profile');
        if ($row->valueByName('policy') ne 'filter') {
            EBox::debug("Object row with id $id has a custom filter group and a policy that is not 'filter'");
            next;
        }

        my $obj       = $row->valueByName('object');
        my @addresses = @{ $objectMod->objectAddresses($obj, mask => 1) };
        foreach my $cidrAddress (@addresses) {
            my ($addr, $netmask) = ($cidrAddress->[0],
                                    EBox::NetWrappers::mask_from_bits($cidrAddress->[1]));
            my $address = "$addr/$netmask";
            push @profiles, {
                                 address => $address,
                                 group   => $profileIdByRowId{$profile}
                                };
        }
    }

    return \@profiles;
}

sub existsAuthObjects
{
    my ($self) = @_;

    foreach my $id ( @{ $self->ids() } )  {
        my $row = $self->row($id);
        my $obPolicy = $row->valueByName('policy');
        my $groupPolicy = $row->subModel('groupPolicy');

        return 1 if $obPolicy eq 'auth';
        return 1 if $obPolicy eq 'authAndFilter';

        return 1 if @{ $groupPolicy->groupsPolicies() } > 0;
    }

    return undef;
}

sub existsFilteredObjects
{
    my ($self) = @_;

    foreach my $id ( @{ $self->ids() } )  {
        my $obPolicy = $self->row($id)->valueByName('policy');
        return 1 if $obPolicy eq 'filter';
        return 1 if $obPolicy eq 'authAndFilter';
    }

    return undef;
}

sub _objectsByPolicy
{
    my ($self, $policy) = @_;

    my @objects = map {
        my $row = $self->row($_);
        my $obPolicy = $row->valueByName('policy');
        ($obPolicy eq $policy) ? $row->valueByName('object') : ()

    } @{ $self->ids()  };

    return \@objects;
}

sub _objectHasPolicy
{
    my ($self, $object, $policy) = @_;

    my $objectRow = $self->_findRowByObjectName($object);
    if (not defined $objectRow) {
        throw EBox::Exceptions::External('{o} does not exists', o => $object );
    }

    return $objectRow->valueByName('policy') eq $policy;
}

# Method: isUnfiltered
#
#       Checks if a given object is set as unfiltered
#
# Parameters:
#
#       object - object name
#
# Returns:
#
#       boolean - true if it's set as unfiltered, otherwise false
#
sub isUnfiltered
{
    my ($self, $object) = @_;
    return $self->_objectHasPolicy($object, 'allow') or
           $self->_objectHasPolicy($object, 'auth');
}

# Method: isBanned
#
#       Checks if a given object is banned
#
# Parameters:
#
#       object - object name
#
# Returns:
#
#       boolean - true if it's set as banned, otherwise false
#
sub isBanned
{
    my ($self, $object) = @_;
    $self->_objectHasPolicy($object, 'deny');
}

sub _findRowByObjectName
{
    my ($self, $objectName) = @_;

    my $objectModel = $self->objectModel();
    my $objectRowId = $objectModel->findId(name => $objectName);

    my $row = $self->findRow(object => $objectRowId);

    return $row;
}

1;
