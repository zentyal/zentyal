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
use EBox::Types::Select;
use EBox::Types::Union;
use EBox::Types::Union::Text;
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
        new EBox::Types::Union(
            fieldName     => 'source',
            printableName => __('Source'),
            subtypes => [
                new EBox::Types::Select(
                    fieldName     => 'object',
                    foreignModel  => $self->modelGetter('objects', 'ObjectTable'),
                    foreignField  => 'name',
                    foreignNextPageField => 'members',
                    printableName => __('Network Object'),
                    unique        => 1,
                    editable      => 1,
                    optional      => 0,
                ),
                new EBox::Types::Select(
                    fieldName     => 'group',
                    printableName => __('Users Group'),

                    populate      => \&populateGroups,
                    unique        => 1,
                    editable      => 1,
                    optional      => 0,
                    disableCache  => 1,
                ),
                new EBox::Types::Union::Text(
                    fieldName => 'any',
                    printableName => __('Any'),
                )
            ]
        ),
        new EBox::Types::Union(
            fieldName     => 'policy',
            printableName => __('Decision'),
            filter        => \&_filterProfilePrintableValue,
            subtypes => [
                new EBox::Types::Union::Text(
                    fieldName => 'allow',
                    printableName => __('Allow All'),
                ),
                new EBox::Types::Union::Text(
                    fieldName => 'deny',
                    printableName => __('Deny All'),
                ),
                new EBox::Types::Select(
                    fieldName => 'profile',
                    printableName => __('Apply Filter Profile'),
                    foreignModel  => $self->modelGetter('squid', 'FilterProfiles'),
                    foreignField  => 'name',
                    editable      => 1,
                )
            ]
        ),
    );

    my $dataTable =
    {
        tableName          => 'AccessRules',
        pageTitle          => __('HTTP Proxy'),
        printableTableName => __('Access Rules'),
        modelDomain        => 'Squid',
        defaultActions     => [ 'add', 'del', 'editField', 'changeView', 'clone', 'move' ],
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
    return [] unless ($userMod->isEnabled());

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

    if ($squid->transproxy() and $squid->authNeeded()) {
        throw EBox::Exceptions::External(__('Source matching by user group is not compatible with transparent proxy mode'));
    }
}

sub groupsPolicies
{
    my ($self) = @_;

    my $userMod = EBox::Global->modInstance('users');
    return [] unless ($userMod->isEnabled());

    my @groupsPol = map {
        my $row = $self->row($_);
        my $source = $row->elementByName('source');
        my $group = $source->selectedType() eq 'group' ? $source->value() : undef;
        my $policy = $row->elementByName('policy');
        my $allow = $policy->value() eq 'allow';
        my $time = $row->elementByName('timePeriod');
        my $users = $group ? $userMod->group($group)->users() : [];

        if (@{$users}) {
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
        my $source = $row->elementByName('source');
        next unless $source->selectedType() eq 'group';
        my $userGroup = $source->printableValue();
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
        my $source = $row->elementByName('source');
        next unless $source->selectedType() eq 'group';
        my $userGroup = $source->printableValue();
        if ($group eq $userGroup) {
            $self->removeRow($id);
        }
    }
}

sub objectsPolicies
{
    my ($self) = @_;

    my $objectMod = $self->global()->modInstance('objects');

    my @obsPol = map {
        my $row = $self->row($_);

        my $source = $row->elementByName('source');
        my $members = [];
        my $obj;
        my $any = 0;
        if ($source->selectedType() eq 'object') {
            $obj = $source->value();
            $members = $objectMod->objectMembers($obj);
        } elsif ($source->selectedType() eq 'any') {
            $any = 1;
        }

        if ($any or @{$members}) {
            my $policy        = $row->elementByName('policy');
            my $allow         = $policy->value() eq 'allow';
            my $filter        = $policy->selectedType() eq 'filter';
            my $timePeriod    = $row->elementByName('timePeriod');
            my $addresses     = $any ? [] : $objectMod->objectAddresses($obj);

            my $obPol = {
                object    => $obj,
                members   => $members,
                addresses => $addresses,
                allowAll  => $allow,
                filter    => $filter,
                any       => $any,
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

            $obPol;
        }
        else {
            ()
        }

    } @{ $self->ids() };

    return \@obsPol;
}

sub objectsProfiles
{
    my ($self) = @_;

    my %profileIdByRowId = %{ $self->parentModule()->model('FilterProfiles')->idByRowId() };

    my $objectMod = $self->global()->modInstance('objects');

    my @profiles;
    foreach my $id (@{$self->ids()}) {
        my $row = $self->row($id);
        my $policy = $row->elementByName('policy');
        next unless ($policy->selectedType() eq 'profile');
        my $profile = $policy->value();

        my $source = $row->elementByName('source');
        next unless ($source->selectedType() eq 'object');
        my $obj       = $source->value();
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

sub rulesUseAuth
{
    my ($self) = @_;

    foreach my $id (@{$self->ids()}) {
        my $row = $self->row($id);
        my $source = $row->elementByName('source');
        if ($source->selectedType() eq 'group') {
            return 1;
        }
    }

    return 0;
}

sub rulesUseFilter
{
    my ($self) = @_;

    foreach my $id (@{$self->ids()}) {
        my $row = $self->row($id);
        my $policy = $row->elementByName('policy');
        if ($policy->selectedType() eq 'profile') {
            return 1;
        }
    }

    return 0;
}

sub _filterProfilePrintableValue
{
    my ($type) = @_;

    if ($type->selectedType() eq 'profile') {
        return __x("Apply '{p}' profile", p => $type->value());
    } else {
        return $type->printableValue();
    }
}

1;
