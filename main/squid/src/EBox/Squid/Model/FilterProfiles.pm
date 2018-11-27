# Copyright (C) 2009-2014 Zentyal S.L.
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

package EBox::Squid::Model::FilterProfiles;

use base 'EBox::Model::DataTable';

use EBox;
use EBox::Global;
use EBox::Exceptions::Internal;
use EBox::Exceptions::External;
use EBox::Gettext;
use EBox::Types::Text;
use EBox::Squid::Types::TimePeriod;
use EBox::Types::HasMany;

use constant MAX_DG_GROUP => 99; # max group number allowed by dansguardian

# Group: Public methods

# Method: _table
#
#
sub _table
{
    my ($self) = @_;

    my $dataTable =
    {
        tableName          => 'FilterProfiles',
        pageTitle          => __('HTTP Proxy'),
        printableTableName => __('Filter Profiles'),
        modelDomain        => 'Squid',
        defaultActions => [ 'add', 'del', 'editField', 'changeView', 'clone' ],
        tableDescription   => $self->tableHeader(),
        class              => 'dataTable',
        rowUnique          => 1,
        automaticRemove    => 1,
        printableRowName   => __("filter profile"),
        messages           => {
            add => __(q{Added filter profile}),
            del =>  __(q{Removed filter profile}),
            update => __(q{Updated filter profile}),
        },
    };
}

sub tableHeader
{
    my ($self) = @_;

    my @header = (
            new EBox::Types::Text(
                fieldName => 'name',
                printableName => __('Name'),
                editable      => 1,
            ),
            new EBox::Types::HasMany(
                fieldName => 'filterPolicy',
                printableName => __('Configuration'),

                foreignModel => 'squid/ProfileConfiguration',
                foreignModelIsComposite => 1,

                view => '/Squid/Composite/ProfileConfiguration',
                backView => '/Squid/View/FilterProfiles',
            ),
    );

    return \@header;
}

sub validateTypedRow
{
    my ($self, $action, $params_r, $actual_r) = @_;

    if (($self->size() + 1)  == MAX_DG_GROUP) {
        throw EBox::Exceptions::External(
                __('Maximum number of filter groups reached')
                );
    }

    my $name = exists $params_r->{name} ?
                      $params_r->{name}->value() :
                      $actual_r->{name}->value();

    # no whitespaces allowed in profile name
    if ($name =~ m/\s/) {
        throw EBox::Exceptions::External(__('No spaces are allowed in profile names'));
    }
    # reserved character for acl names
    if ($name =~ m/~/) {
        throw EBox::Exceptions::External(__(q|The '~' character is reserved and cannot be used in profile names|));
    }
}

sub _authOnly
{
    my ($self) = @_;

    return $self->parentModule()->model('AccessRules')->existsPoliciesForGroupOnly();
}

# Method: idByRowId
#
#  Returns:
#  hash with row IDs as key and the filter group id number as value
sub idByRowId
{
    my ($self) = @_;

    my %idByRowId;
    my $id = $self->_authOnly() ? 1 : 3;
    foreach my $rowId (@{ $self->ids() }) {
        $idByRowId{$rowId} = $id++;
    }

    return \%idByRowId;
}

sub dgProfiles
{
    my ($self) = @_;
    my @profiles = ();

    my $id = 1;
    unless ($self->_authOnly()) {
        push (@profiles, { number => 1, policy => 'deny', groupName => 'defaultDeny' });
        push (@profiles, { number => 2, policy => 'allow', groupName => 'defaultAllow' });
        $id = 3;
    }

    foreach my $rowId ( @{ $self->ids() } ) {
        my $row = $self->row($rowId);
        my $name  = $row->valueByName('name');

        if ($id > MAX_DG_GROUP) {
            EBox::info("Filter group $name and following groups will use default content filter policy because the maximum number of Dansguardian groups is reached");
            last;
        }

        my $group = {
            number => $id++,
            groupName => $name,
            policy => 'filter'
        };

        my $policy = $row->elementByName('filterPolicy')->foreignModelInstance();

        $group->{antivirus} = $policy->componentByName('AntiVirus', 1)->active(),

        $group->{threshold} = $policy->componentByName('ContentFilterThreshold', 1)->threshold();

        $group->{bannedExtensions} = $policy->componentByName('Extensions', 1)->banned();

        $group->{bannedMIMETypes} = $policy->componentByName('MIME', 1)->banned();

        $self->_setProfileDomainsPolicy($group, $policy);

        push (@profiles, $group);
    }

    return \@profiles;
}

sub _setProfileDomainsPolicy
{
    my ($self, $group, $policy) = @_;

    my $domainFilter      = $policy->componentByName('Domains', 1)->componentByName('DomainFilter', 1);
    my $domainFilterFiles = $policy->componentByName('DomainFilterCategories', 1);

    $group->{exceptionsitelist} = [
                                   domains => $domainFilter->allowed(),
                                   includes => $domainFilterFiles->dgAllowed(),
                                  ];

    $group->{exceptionurllist} = [
                                  urls =>  $domainFilter->allowedUrls(),
                                  includes => $domainFilterFiles->dgAllowedUrls(),
                                 ];

    my $domainFilterSettings = $policy->componentByName('DomainFilterSettings', 1);
    $group->{bannedsitelist} = [
                                blockIp       => $domainFilterSettings->blockIpValue,
                                blanketBlock  => $domainFilterSettings->blanketBlockValue,
                                domains       => [],
                                includes      => [],
                               ];
}

sub antivirusNeeded
{
    my ($self) = @_;

    my $id = 0;
    foreach my $rowId ( @{ $self->ids() } ) {
        my $antivirusModel;
        my $row = $self->row($rowId);
        next unless defined ($row);
        my $policy =
            $row->elementByName('filterPolicy')->foreignModelInstance();

        if ($id > MAX_DG_GROUP) {
            my $name  = $row->valueByName('name');
            EBox::info(
                    "Maximum nuber of dansguardian groups reached, group $name and  following groups antivirus configuration is not used"
                    );
            last;
        } else {
            $antivirusModel =
                $policy->componentByName('AntiVirus', 1);
        }

        if ($antivirusModel->active()) {
            return 1;
        }

        $id += 1 ;
    }

    # no profile with antivirus enabled found...
    return 0;
}

sub markCategoriesAsNoPresent
{
    my ($self, $list) = @_;
    foreach my $id (@{ $self->ids() }) {
        my $filterPolicy = $self->row($id)->subModel('filterPolicy');
        my $domainFilterCategories = $filterPolicy->componentByName('DomainFilterCategories', 1);
        $domainFilterCategories->markCategoriesAsNoPresent($list);
    }
}

sub removeNoPresentCategories
{
    my ($self) = @_;
    foreach my $id (@{ $self->ids() }) {
        my $filterPolicy = $self->row($id)->subModel('filterPolicy');
        my $domainFilterCategories = $filterPolicy->componentByName('DomainFilterCategories', 1);
        $domainFilterCategories->removeNoPresentCategories();
    }
}

sub squidAcls
{
    my ($self, $enabledProfiles) = @_;
    my @acls;
    my %sharedAcls;
    foreach my $id (@{ $enabledProfiles }) {
        my $row = $self->row($id);
        my $profileConf = $row->subModel('filterPolicy');
        push @acls, @{ $profileConf->squidAcls() };
        foreach my $shared (@{ $profileConf->squidSharedAcls }) {
            $sharedAcls{$shared->[0]} = $shared->[1];
        }
    }
    push @acls, values %sharedAcls;

    return {all => \@acls, shared => \%sharedAcls};
}

sub squidRulesStubs
{
    my ($self, $enabledProfiles, @params) = @_;
    my %stubs;
    foreach my $id (@{ $enabledProfiles }) {
        my $row = $self->row($id);
        my $profileConf = $row->subModel('filterPolicy');
        $stubs{$id} = $profileConf->squidRulesStubs(@params);
    }
    return \%stubs;
}

sub usesFilterById
{
    my ($self, $rowId) = @_;
    my $row = $self->row($rowId);
    my $profileConf = $row->subModel('filterPolicy');
    return $profileConf->usesFilter();
}

sub usesFilter
{
    my ($self, $enabledProfiles) = @_;
    foreach my $id (@{ $enabledProfiles }) {
        if ($self->usesFilterById($id)) {
            return 1;
        }
    }
    return 0;
}

sub usesHTTPSById
{
    my ($self, $rowId) = @_;
    my $row = $self->row($rowId);
    return $row->subModel('filterPolicy')->componentByName('DomainFilterSettings', 1)->value('httpsBlock');
}

sub usesHTTPS
{
    my ($self, $enabledProfiles) = @_;
    foreach my $id (@{ $enabledProfiles }) {
        if ($self->usesHTTPSById($id)) {
            return 1;
        }
    }
    return 0;
}

1;
