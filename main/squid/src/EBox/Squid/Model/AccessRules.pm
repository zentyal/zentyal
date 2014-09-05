# Copyright (C) 2008-2014 Zentyal S.L.
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

use EBox;
use EBox::Exceptions::Internal;
use EBox::Exceptions::External;
use EBox::Gettext;
use EBox::Types::Text;
use EBox::Types::Select;
use EBox::Types::Union;
use EBox::Types::Union::Text;
use EBox::Squid::Types::TimePeriod;

use TryCatch::Lite;
use Net::LDAP;
use Net::LDAP::Control::Sort;
use Net::LDAP::Control::Paged;
use Net::LDAP::Constant qw(LDAP_LOCAL_ERROR LDAP_CONTROL_PAGED LDAP_SUCCESS);
use Net::LDAP::Util qw(escape_filter_value canonical_dn);
use Authen::SASL qw(Perl);

use constant MAX_DG_GROUP => 99; # max group number allowed by dansguardian
use constant AUTH_AD_SKIP_SYSTEM_GROUPS_KEY => 'auth_ad_skip_system_groups';

sub _table
{
    my ($self) = @_;

    my @tableHeader = (
        new EBox::Squid::Types::TimePeriod(
                fieldName => 'timePeriod',
                printableName => __('Time period'),
                help => __('Time period when the rule is applied'),
                editable => 1,
        ),
        new EBox::Types::Union(
            fieldName     => 'source',
            printableName => __('Source'),
            filter        => \&_filterSourcePrintableValue,
            subtypes => [
                new EBox::Types::Select(
                    fieldName     => 'object',
                    foreignModel  => $self->modelGetter('objects', 'ObjectTable'),
                    foreignField  => 'name',
                    foreignNextPageField => 'members',
                    printableName => __('Network Object'),
                    editable      => 1,
                    optional      => 0,
                ),
                new EBox::Types::Select(
                    fieldName        => 'group',
                    printableName    => __('Users Group'),
                    populate         => \&_populateGroups,
                    editable         => 1,
                    optional         => 0,
                    disableCache     => 1,
                    allowUnsafeChars => 1,
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

sub viewCustomizer
{
    my ($self) = @_;

    my $squid = $self->parentModule();
    if (($squid->authenticationMode() eq $squid->AUTH_MODE_EXTERNAL_AD) and not $squid->configured()) {
        my $customizer = new EBox::View::Customizer();
        $customizer->setModel($self);
        $customizer->setPermanentMessage(__('Group selection will not be available until you enable the HTTP proxy module'), 'note');
        return $customizer;
    }

    return $self->SUPER::viewCustomizer();
}

sub _populateGroups
{
    my ($self) = @_;

    my $squid = $self->parentModule();
    my $mode = $squid->authenticationMode();
    if ($mode eq $squid->AUTH_MODE_EXTERNAL_AD()) {
        if (not $squid->configured) {
            return [];
        }
        return $self->_populateGroupsFromExternalAD();
    } else {
        my $sambaMod = $self->global()->modInstance('samba');
        return [] unless ($sambaMod->isEnabled() and $sambaMod->isProvisioned());

        my @groups;
        foreach my $group (@{$sambaMod->securityGroups()}) {
            push (@groups, { value => $group->dn(), printableValue => $group->get('samAccountName') });
        }
        return \@groups;
    }
    return [];
}

sub _adLdap
{
    my ($self) = @_;

    unless (defined $self->{adLdap}) {
        my $squid = $self->parentModule();
        my $keytab = $squid->KEYTAB_FILE();
        $self->{adLdap} = $self->global()->modInstance('samba')->ldap()->connectWithKerberos($keytab);
    }

    return $self->{adLdap};
}

# Method: _sidToString
#
#   This method translate binary SIDs retrieved from AD LDAP to its string
#   representation.
#
#   FIXME This method is duplicated from samba module, file LdbObject.pm,
#         should be in a utility class at common or core
#
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

sub _populateGroupsFromExternalAD
{
    my ($self) = @_;

    my $squid = $self->parentModule();

    my $skip = EBox::Config::boolean(AUTH_AD_SKIP_SYSTEM_GROUPS_KEY);

    my $groups = [];
    my $ad = $self->_adLdap();
    my $defaultNC = $self->defaultNC($ad);

    if (not $self->{sortControl}) {
        $self->{sortControl} =  new Net::LDAP::Control::Sort(order => 'samAccountName');
    }
    my $sort = $self->{sortControl};

    my $filter = $skip ?
        '(&(objectClass=group)(!(isCriticalSystemObject=*)))':
        '(objectClass=group)';
    my $res = $self->_pagedSearch($ad,
                                  { base   => $defaultNC,
                                    scope  => 'sub',
                                    filter => $filter,
                                    attrs  => ['samAccountName', 'objectSid'],
                                    control => [$sort] });
    foreach my $entry (@{$res}) {
        my $printableValue;
        my $samAccountName = $entry->get_value('samAccountName');
        my $sid = $self->_sidToString($entry->get_value('objectSid'));
        my $parentRelative = $entry->dn();
        $parentRelative =~ s/$defaultNC$//;
        $parentRelative =~ s/^.*?,//;
        $parentRelative =~ s/,$//;
        if (($parentRelative eq 'CN=Users') or ($parentRelative eq 'CN=Builtin')) {
            $printableValue = $samAccountName;
        } else {
            $parentRelative =~ s/^.*?=//;
            $parentRelative =~ s{,.*?=}{/}g;
            $printableValue = "$parentRelative/$samAccountName";
        }

        utf8::decode($printableValue);
        push (@{$groups}, { value => $sid, printableValue => $printableValue });
    }

    return $groups;
}

sub _adGroupMembers
{
    my ($self, $group) = @_;

    my $members = [];
    my $ldap = $self->_adLdap();
    my $defaultNC = $self->defaultNC($ldap);
    $group = escape_filter_value($group);
    my $filter = "(&(objectClass=group)(objectSid=$group))";
    my $result = $self->_pagedSearch($ldap,
                                     { base  => $defaultNC,
                                       scope  => 'sub',
                                       filter => $filter,
                                       attrs  => ['member'] });
    foreach my $groupEntry (@{$result}) {
        my @members = $groupEntry->get_value('member');
        next unless @members;
        foreach my $memberDN (@members) {
            # NOTE MS LDAP does not collapse multiple consecutive white spaces
            #      as openLDAP does. The canonical_dn function collapse them
            #      and make ldap search fail with LDAP_NO_SUCH_OBJECT
            #$memberDN = canonical_dn($memberDN);

            # Get nested groups
            my $result2 = $ldap->search(base => $memberDN,
                                        scope => 'base',
                                        filter => '(objectClass=group)',
                                        attrs => ['objectSid']);
            unless ($result2->code() eq LDAP_SUCCESS) {
                $self->_ADException($result2);
            }
            foreach my $nestedGroupEntry ($result2->entries()) {
                my $nestedGroupSid = $nestedGroupEntry->get_value('objectSid');
                next unless defined $nestedGroupSid;
                my $nestedMembers = $self->_adGroupMembers($nestedGroupSid);
                push (@{$members}, @{$nestedMembers});
            }

            # Get users
            my $result3 = $ldap->search(base => $memberDN,
                                        scope => 'base',
                                        filter => "(objectClass=user)",
                                        attrs => ['samAccountName']);
            unless ($result3->code() eq LDAP_SUCCESS) {
                $self->_ADException($result3);
            }
            foreach my $userEntry ($result3->entries()) {
                my $samAccountName = $userEntry->get_value('samAccountName');
                next unless defined $samAccountName;
                push (@{$members}, $samAccountName);
            }
        }
    }

    return $members;
}

# Page search
# Parameters:
#    ldap - <Net::LDAP> connection
#    searchParams - Hash ref with the following keys:
#         base - String the base
#         scope - String the scope  ('sub' or 'base')
#         filter - String the filter
#         attrs - Array ref with the attrs to retrieve
#         control - Array ref with the controls
#                   paged one will be added by _pagedSearch
#    pageSize - Int the size *(Optional)* Default: 500
#
# Returns: Array ref of <Net::LDAP::Entry>
sub _pagedSearch
{
    my ($self, $ldap, $searchParams, $pageSize) = @_;

    $pageSize = 500 unless ($pageSize);
    my $page = new Net::LDAP::Control::Paged(size => $pageSize);
    my @controls = ( $page );
    push(@controls, @{$searchParams->{control}}) if (ref($searchParams->{control}) eq 'ARRAY');
    my %search = (
        base    => $searchParams->{base},
        filter  => $searchParams->{filter},
        scope   => $searchParams->{scope},
        attrs   => $searchParams->{attrs},
        control => \@controls,
    );

    my @entries = ();
    my $cookie;
    while (1) {
        # Perform the search
        my $msg = $ldap->search(%search);
        unless ($msg->code() eq LDAP_SUCCESS) {
            $self->_ADException($msg);
        }

        foreach my $entry ($msg->entries()) {
            $entry = $self->_rangeAttrSearch($ldap, $searchParams, $entry);
            push(@entries, $entry);
        }

        my ($resp) = $msg->control(LDAP_CONTROL_PAGED);
        last unless ($resp);

        $cookie = $resp->cookie();
        last unless ($cookie);

        $page->cookie($cookie);
    }

    if ($cookie) {
        # We had an abnormal exit, so let the server know we do not want any more
        $page->cookie($cookie);
        $page->size(0);
        $ldap->search(%search);
    }
    return \@entries;
}

# Get the attributes which must have a range
# Returns the entry modified
sub _rangeAttrSearch
{
    my ($self, $ldap, $searchParams, $entry) = @_;

    foreach my $attr ($entry->attributes()) {
        if ($attr =~ /;range=/) {
            my ($pureAttr, $range) = split(/;/, $attr, 2);
            my ($last) = $range =~ m/range=\d+-(.*)$/;
            my @attrValues = $entry->get_value($pureAttr);
            push(@attrValues, $entry->get_value($attr));
            while( $last ne '*' ) {
                my $rangeAttr = "$pureAttr;range=" . ($last + 1) . '-*';
                # Simple query
                my $msg = $ldap->search(base   => $searchParams->{base},
                                        scope  => $searchParams->{scope},
                                        filter => $searchParams->{filter},
                                        attrs  => [$rangeAttr]);
                unless ($msg->code() eq LDAP_SUCCESS) {
                    $self->_ADException($msg);
                }
                foreach my $rangeEntry ($msg->entries()) {
                    ($rangeAttr) = grep { $_ =~ m/;range/ } $rangeEntry->attributes();
                    push(@attrValues, $rangeEntry->get_value($rangeAttr));
                }
                ($last) = $rangeAttr =~ m/range=\d+-(.*)$/;  # To calculate new range
            }
            $entry->replace($pureAttr, \@attrValues);
        }
    }
    return $entry;
}

# Launch an external exception if the AD cannot fulfil our request
sub _ADException
{
    my ($self, $msg) = @_;

    # try to disconnect to force reconnection in next request
    if ($self->{adLdap}) {
        try {
            $self->{adLdap}->disconnect();
        } catch {
        }
    }
    delete $self->{adLdap};
    delete $self->{defaultNC};

    throw EBox::Exceptions::External(
        __x('AD Error {error_name}: {error_desc}. If you think this error is temporary, please try again later',
            error_name => $msg->error_name(),
            error_desc => $msg->error_desc()))
}

sub validateTypedRow
{
    my ($self, $action, $params_r, $actual_r) = @_;

    my $squid = $self->parentModule();

    my $source = exists $params_r->{source} ?
                      $params_r->{source}:  $actual_r->{source};
    my $sourceType  = $source->selectedType();
    my $sourceValue = $source->value();

    if ($squid->transproxy() and ($sourceType eq 'group')) {
        throw EBox::Exceptions::External(__('Source matching by user group is not compatible with transparent proxy mode'));
    }

    # check if it is a incompatible rule
     my $groupRules;
     my $objectProfile;
     if ($sourceType eq 'group') {
         $groupRules = 1;
     } else {
        my $policy = exists $params_r->{policy} ?  $params_r->{policy}->selectedType
                                                 :  $actual_r->{policy}->selectedType();
         if (($policy eq 'allow') or ($policy eq 'profile') ) {
             $objectProfile = 1;
         }
     }

    if ((not $groupRules) and (not $objectProfile)) {
        return;
    }

    my $ownId = $params_r->{id};
    my $ownTimePeriod = exists $params_r->{timePeriod} ?
                                     $params_r->{timePeriod} :  $actual_r->{timePeriod};
    foreach my $id (@{ $self->ids() }) {
        next if (defined($ownId) and ($id eq $ownId));

        my $row = $self->row($id);
        my $rowSource = $row->elementByName('source');
        my $rowSourceType = $rowSource->selectedType();
        if ($objectProfile and ($rowSourceType eq 'group')) {
            throw EBox::Exceptions::External(
              __("You cannot add a 'Allow' or 'Profile' rule for an object or any address if you have group rules")
             );
        } elsif ($groupRules and ($rowSourceType ne 'group')) {
            if ($row->elementByName('policy')->selectedType() ne 'deny') {
                throw EBox::Exceptions::External(
                 __("You cannot add a group-based rule if you have an 'Allow' or 'Profile' rule for objects or any address")
               );
            }
        }

        if ($sourceValue eq $rowSource->value()) {
            # same object/group, check time overlaps
            my $rowTimePeriod = $row->elementByName('timePeriod');
            if ($ownTimePeriod->overlaps($rowTimePeriod)) {
                throw EBox::Exceptions::External(
                    __x('The time period of the rule ({t1}) overlaps with the time period of ({t2}) other rule for the same {sourceType}',
                        t1 => $ownTimePeriod->printableValue(),
                        t2 => $rowTimePeriod->printableValue(),
                        # XXX due to the bad case of subtype's printable names
                        # we need to do lcfirst of all words instead of doing so
                        # only in the first one
                        sourceType => join (' ', map { lcfirst $_ } split '\s+',  $source->subtype()->printableName()),
                       )
                   );
            }
        }

    }
}

sub addedRowNotify
{
    my ($self) = @_;
    $self->_changeInAccessRules();
}

sub updatedRowNotify
{
    my ($self) = @_;
    $self->_changeInAccessRules();
}

sub deletedRowNotify
{
    my ($self, $row, $force) = @_;
    $self->_changeInAccessRules();
}

sub _changeInAccessRules
{
    my ($self) = @_;

    # TODO: Check if there is a change in the use of filtering
    $self->global()->modChange('logs');
}

# TODO: Add doc as used by list-proxy-rules job
sub rules
{
    my ($self) = @_;

    my $objectMod = $self->global()->modInstance('objects');
    my $userMod = $self->global()->modInstance('samba');
    my $usersEnabled = $userMod->isEnabled();

    # we dont use row ids to make rule id shorter bz squid limitations with id length
    my $number = 0;
    my @rules;
    foreach my $id (@{$self->ids()}) {
        my $row = $self->row($id);
        my $source = $row->elementByName('source');

        my $rule = { number => $number};
        if ($source->selectedType() eq 'object') {
            my $object = $source->value();
            $rule->{object} = $object;
            $rule->{members} = $objectMod->objectMembers($object);
            my $addresses = $objectMod->objectAddresses($object);
            # ignore empty objects
            next unless @{$addresses};
            $rule->{addresses} = $addresses;
        } elsif ($source->selectedType() eq 'group') {
            my $mode = $self->parentModule->authenticationMode();
            if ($mode eq $self->parentModule->AUTH_MODE_INTERNAL()) {
                next unless ($usersEnabled);
                my $group = $source->value();
                $rule->{group} = $group;
            } elsif ($mode eq $self->parentModule->AUTH_MODE_EXTERNAL_AD()) {
                $rule->{adDN} = $source->value();
            }
        } elsif ($source->selectedType() eq 'any') {
            $rule->{any} = 1;
        }

        my $policyElement = $row->elementByName('policy');
        my $policyType =  $policyElement->selectedType();
        $rule->{policy} = $policyType;
        if ($policyType eq 'profile') {
            $rule->{profile} = $policyElement->value();
        }

        my $timePeriod = $row->elementByName('timePeriod');
        if (not $timePeriod->isAllTime) {
            if (not $timePeriod->isAllWeek()) {
                $rule->{timeDays} = $timePeriod->weekDays();
            }

            my $hours = $timePeriod->hourlyPeriod();
            if ($hours) {
                $rule->{timeHours} = $hours;
            }
        }

        push (@rules, $rule);
        $number += 1;
    }

    return \@rules;
}

sub squidFilterProfiles
{
    my ($self) = @_;

    my $enabledProfiles = $self->_enabledProfiles();
    my $filterProfiles = $self->parentModule()->model('FilterProfiles');
    my $acls = $filterProfiles->squidAcls($enabledProfiles);
    my $rulesStubs = $filterProfiles->squidRulesStubs($enabledProfiles, sharedAcls => $acls->{shared});
    return {
              acls => $acls->{all},
              rulesStubs => $rulesStubs,
           };
}

sub existsPoliciesForGroup
{
    my ($self, $group) = @_;
    foreach my $id (@{ $self->ids() }) {
        my $row = $self->row($id);
        my $source = $row->elementByName('source');
        next unless $source->selectedType() eq 'group';
        my $userGroup = $source->value();
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

sub filterProfiles
{
    my ($self) = @_;

    my $filterProfilesModel = $self->parentModule()->model('FilterProfiles');
    my %profileIdByRowId = %{ $filterProfilesModel->idByRowId() };

    my $objectMod = $self->global()->modInstance('objects');
    my $userMod = $self->global()->modInstance('samba');
    my $domainUsers = $userMod->ldap->domainUsersGroup->get('samAccountName');

    my @profiles;
    foreach my $id (@{$self->ids()}) {
        my $row = $self->row($id);

        my $profile = {};

        my $policy     = $row->elementByName('policy');
        my $policyType = $policy->selectedType();
        if ($policyType eq 'allow') {
            $profile->{number} = 2;
        } elsif ($policyType eq 'deny') {
            $profile->{number} = 1;
        } elsif ($policyType eq 'profile') {
            my $rowId = $policy->value();
            $profile->{number} = $profileIdByRowId{$rowId};
            $profile->{usesFilter} = $filterProfilesModel->usesFilterById($rowId);
        } else {
            throw EBox::Exceptions::Internal("Unknown policy type: $policyType");
        }
        $profile->{policy} = $policyType;
        my $timePeriod = $row->elementByName('timePeriod');
        unless ($timePeriod->isAllTime()) {
            $profile->{timePeriod} = 1;
            $profile->{begin} = $timePeriod->from();
            $profile->{end} = $timePeriod->to();
            $profile->{days} = $timePeriod->dayNumbers();
        }

        my $source = $row->elementByName('source');
        my $sourceType = $source->selectedType();
        $profile->{source} = $sourceType;
        if ($sourceType eq 'any') {
            $profile->{anyAddress} = 1;
            $profile->{address} = '0.0.0.0/0.0.0.0';
            push @profiles, $profile;
        } elsif ($sourceType eq 'object') {
            my $obj       = $source->value();
            my @addresses = @{ $objectMod->objectAddresses($obj, mask => 1) };
            foreach my $cidrAddress (@addresses) {
                # put a pseudo-profile for each address in the object
                my ($addr, $netmask) = ($cidrAddress->[0], EBox::NetWrappers::mask_from_bits($cidrAddress->[1]));
                my %profileCopy = %{$profile};
                $profileCopy{address} = "$addr/$netmask";
                push @profiles, \%profileCopy;
            }
        } elsif ($sourceType eq 'group') {
            my $group = $source->value();
            $profile->{group} = $group;
            my @users;
            if ($self->parentModule->authenticationMode() eq
                $self->parentModule->AUTH_MODE_EXTERNAL_AD()) {
                @users = @{$self->_adGroupMembers($group)};
            } else {
                my $members;
                if ($group eq $domainUsers) {
                    $members = $userMod->users();
                } else {
                    $members = $userMod->objectFromDN($group)->users();
                }
                @users = map { $_->name() } @{$members};
            }
            @users or next;
            $profile->{users} = \@users;
            push @profiles, $profile;
        } else {
            throw EBox::Exceptions::Internal("Unknow source type: $sourceType");
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
    my $profiles = $self->_enabledProfiles();
    my $filterProfiles = $self->parentModule()->model('FilterProfiles');
    return $filterProfiles->usesFilter($profiles);
}

sub _enabledProfiles
{
    my ($self) = @_;
    my %profiles;
    foreach my $id (@{ $self->ids()  }) {
        my $row = $self->row($id);
        my $policy = $row->elementByName('policy');
        if ($policy->selectedType eq 'profile') {
            $profiles{$policy->value()} = 1;
        }
    }
    return [keys %profiles];
}

sub _filterSourcePrintableValue
{
    my ($type) = @_;

    my $selected = $type->selectedType();
    my $value = $type->printableValue();

    if ($selected eq 'object') {
        return __x('Object: {o}', o => $value);
    } elsif ($selected eq 'group') {
        return __x('Group: {g}', g => $value);
    } else {
        return $value;
    }
}

sub _filterProfilePrintableValue
{
    my ($type) = @_;

    if ($type->selectedType() eq 'profile') {
        return __x("Apply '{p}' profile", p => $type->printableValue());
    } else {
        return $type->printableValue();
    }
}

sub defaultNC
{
    my ($self, $ldap) = @_;
    if ($self->{defaultNC}) {
        return $self->{defaultNC};
    }

    my $dse = $ldap->root_dse(attrs => ['defaultNamingContext', '*']);
    if (not $dse) {
        throw EBox::Exceptions::Internal('Cannot get root dse');
    }

    my $defaultNC = $dse->get_value('defaultNamingContext');
    $defaultNC = canonical_dn($defaultNC);
    $self->{defaultNC} = $defaultNC;
    return $self->{defaultNC};
}

1;
