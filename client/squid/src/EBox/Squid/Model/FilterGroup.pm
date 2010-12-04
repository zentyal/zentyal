# Copyright (C) 2009-2010 eBox Technologies S.L.
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

package EBox::Squid::Model::FilterGroup;
use base 'EBox::Model::DataTable';

use EBox;
use EBox::Global;
use EBox::Exceptions::Internal;
use EBox::Exceptions::External;
use EBox::Gettext;
use EBox::Types::Text;
use EBox::Squid::Types::Policy;
use EBox::Squid::Types::TimePeriod;
use EBox::Types::HasMany;

use constant MAX_DG_GROUP => 99; # max group number allowed by dansguardian
use constant STORE_URL => 'https://store.zentyal.com/other/advanced-security.html?utm_source=zentyal&utm_medium=HTTP_proxy_profile_filter&utm_campaign=advanced_security_updates';

# Group: Public methods

# Constructor: new
#
#       Create the new  model
#
# Overrides:
#
#       <EBox::Model::DataTable::new>
#
# Returns:
#
#       <EBox::Squid::Model::GroupPolicy> - the recently
#       created model
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless $self, $class;
    return $self;
}

# Method: viewCustomizer
#
#      To display a permanent message
#
# Overrides:
#
#      <EBox::Model::DataTable::viewCustomizer>
#
sub viewCustomizer
{
    my ($self) = @_;

    my $customizer = $self->SUPER::viewCustomizer();

    my $securityUpdatesAddOn = 0;
    if ( EBox::Global->modExists('remoteservices') ) {
        my $rs = EBox::Global->modInstance('remoteservices');
        $securityUpdatesAddOn = $rs->securityUpdatesAddOn();
    }

    unless ( $securityUpdatesAddOn ) {
        $customizer->setPermanentMessage($self->_commercialMsg());
    }

    return $customizer;
}

# Method: _table
#
#
sub _table
{
    my ($self) = @_;

    my $dataTable =
    {
        tableName          => name(),
        pageTitle         => __('Filter profiles'),
        printableTableName => __('List of profiles'),
        modelDomain        => 'Squid',
        'defaultController' => '/ebox/Squid/Controller/FilterGroup',
        'defaultActions' => [ 'add', 'del', 'editField', 'changeView' ],
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
                printableName => __('Filter group'),
                editable      => 1,
                ),
            new EBox::Types::HasMany(
                fieldName => 'filterPolicy',
                printableName => __('Configuration'),

                foreignModel => 'squid/FilterGroupSettings',
                foreignModelIsComposite => 1,

                'view' => '/ebox/Squid/Composite/FilterGroupSettings',
                'backView' => '/ebox/Squid/View/FilterGroup',
                ),
            );

    return \@header;
}

my $defaultRow;

sub defaultGroupName
{
    return 'default';
}

sub _initDefaultRow
{
    my ($self) = @_;

    my $dir   = $self->directory();
    $defaultRow = new EBox::Model::Row(
                                       dir => $dir,
                                       gconfmodule => $self->{gconfmodule}
                                      );

    $defaultRow->setModel($self);
    $defaultRow->setId('defaultFilterGroup');

    my $nameElement = new EBox::Types::Text(
                                        fieldName => 'name',
                                        printableName => __('Filter group'),
                                        defaultValue  => $self->defaultGroupName(),
                                        editable      => 0,
                                       );

    my $policyElement = new EBox::Types::HasMany(
                                 fieldName => 'filterPolicy',
                                 printableName => __('Filter group policy'),

                                 foreignModel => 'squid/FilterSettings',
                                 foreignModelIsComposite => 1,

                                 'view' => '/ebox/Squid/Composite/FilterSettings',
                                 'backView' => '/ebox/squid/View/FilterGroup',
                                );

    $defaultRow->addElement($nameElement);
    $defaultRow->addElement($policyElement);
    $defaultRow->setReadOnly(1);
}

sub _ids
{
    my ($self) = @_;

    my $ids = $self->SUPER::_ids();
    unshift (@{$ids}, 'default');
    return $ids;
}

sub row
{
    my ($self, $id) = @_;

    unless ($id eq 'default') {
        return $self->SUPER::row($id);
    }

    defined $defaultRow or
        $self->_initDefaultRow();

    return $defaultRow;
}

sub name
{
    return 'FilterGroup';
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
}

# Method: idByRowId
#
#  Returns:
#  hash with row IDs as key and the filter group id number as value
sub idByRowId
{
    my ($self) = @_;
    my %idByRowId;
    my $id = 0;
    foreach my $rowId (@{ $self->ids()  }) {
        $id += 1;
        $idByRowId{$rowId} = $id;
    }

    return \%idByRowId;
}

sub filterGroups
{
    my ($self) = @_;
    my @filterGroups = ();

    my $squid = EBox::Global->modInstance('squid');
    my $usergroupPolicies = $squid->model('GlobalGroupPolicy');
    my %usersByFilterGroupId = %{ $usergroupPolicies->usersByFilterGroup()  };

    # groups will have ids greater that this number
    my $id = 0;

    # remember id 1 is reserved for gd's default group so it must be
    # the first to be getted
    foreach my $rowId ( @{ $self->ids() } ) {
        my $row = $self->row($rowId);
        my $name  = $row->valueByName('name');

        $id += 1;
        if ($id > MAX_DG_GROUP) {
            EBox::info("Filter group $name and following groups will use default content filter policy because the maximum number of Dansguardian groups is reached");
            last;
        }

        if ($id == 1) {
            # default filter group needs special tratment
            push @filterGroups, $self->_defaultFilterGroup($row);
            next;
        }

        my $users;
        if (exists $usersByFilterGroupId{$rowId}) {
            $users = $usersByFilterGroupId{$rowId};
        } else {
            $users = [];
        }

        my %group = (
                number => $id,
                groupName => $name,
                users  => $users,
                defaults => {},
                );

        my $policy = $row->elementByName('filterPolicy')->foreignModelInstance();

        $group{antivirus} =
            $policy->componentByName('FilterGroupAntiVirus', 1)->active(),

            $group{threshold} =
                $policy->componentByName('FilterGroupContentFilterThreshold', 1)->threshold();

        my $useDefault;

        $useDefault = $policy->componentByName('UseDefaultExtensionFilter', 1);
        if ($useDefault->useDefaultValue()) {
            $group{defaults}->{bannedextensionlist} = 1;
        }
        else {
            $group{bannedExtensions} =
                $policy->componentByName('FilterGroupExtensionFilter', 1)->banned();
        }

        $useDefault = $policy->componentByName('UseDefaultMIMEFilter', 1);
        if ($useDefault->useDefaultValue()) {

            $group{defaults}->{bannedmimetypelist} = 1;
        }
        else {
            $group{bannedMIMETypes} =
                $policy->componentByName('FilterGroupMIMEFilter', 1)->banned();
        }

        $self->_setFilterGroupDomainsPolicy(\%group, $policy);

        push @filterGroups, \%group;
    }

    return \@filterGroups;
}


sub _setFilterGroupDomainsPolicy
{
    my ($self, $group, $policy) = @_;

    my $useDefault = $policy->componentByName('UseDefaultDomainFilter', 1);
    if ($useDefault->useDefaultValue()) {
        $group->{defaults}->{exceptionsitelist} = 1;
        $group->{defaults}->{exceptionurllist}  = 1;
        $group->{defaults}->{greysitelist}      = 1;
        $group->{defaults}->{greyurllist }      = 1;
        $group->{defaults}->{bannedsitelist}    = 1;
        $group->{defaults}->{bannedurllist}     = 1;

        return;
    }

    my $domainFilter      = $policy->componentByName('FilterGroupDomainFilter', 1);
    my $domainFilterFiles = $policy->componentByName('FilterGroupDomainFilterFiles', 1);

    $group->{exceptionsitelist} = [
                                   domains => $domainFilter->allowed(),
                                   includes => $domainFilterFiles->allowed(),
                                  ];

    $group->{exceptionurllist} = [
                                  urls =>  $domainFilter->allowedUrls(),
                                  includes => $domainFilterFiles->allowedUrls(),
                                 ];

    $group->{greysitelist} = [
                              domains => $domainFilter->filtered(),
                              includes => $domainFilterFiles->filtered(),
                             ];

    $group->{greyurllist} = [
                             urls => $domainFilter->filteredUrls(),
                             includes => $domainFilterFiles->filteredUrls(),
                            ];

    $group->{bannedurllist} = [
                               urls =>  => $domainFilter->bannedUrls(),
                               includes => $domainFilterFiles->bannedUrls(),
                              ];

    my $domainFilterSettings = $policy->componentByName('FilterGroupDomainFilterSettings', 1);

    $group->{bannedsitelist} = [
                                blockIp       => $domainFilterSettings->blockIpValue,
                                blanketBlock  => $domainFilterSettings->blanketBlockValue,
                                domains       => $domainFilter->banned(),
                                includes      => $domainFilterFiles->banned(),
                               ];
}

sub _defaultFilterGroup
{
    my ($self, $row) = @_;

    my $policy = $row->elementByName('filterPolicy')->foreignModelInstance();

    my $default = {
        number => 1,
        groupName => 'default',
        antivirus =>
            $policy->componentByName('DefaultAntiVirus', 1)->active(),
        threshold =>
            $policy->componentByName('ContentFilterThreshold', 1)->contentFilterThresholdValue(),
        bannedExtensions =>
            $policy->componentByName('ExtensionFilter', 1)->banned(),
        bannedMIMETypes =>
            $policy->componentByName('MIMEFilter', 1)->banned(),
        defaults => {},
    };

    my $domainFilter      = $policy->componentByName('DomainFilter', 1);
    my $domainFilterFiles = $policy->componentByName('DomainFilterFiles', 1);

    $default->{exceptionsitelist} = [
        domains => $domainFilter->allowed(),
        includes => $domainFilterFiles->allowed(),
    ];

    $default->{exceptionurllist} = [
        urls => $domainFilter->allowedUrls(),
        includes => $domainFilterFiles->allowedUrls(),
    ];

    $default->{greysitelist} = [
        domains => $domainFilter->filtered(),
        includes => $domainFilterFiles->filtered(),
    ];

    $default->{greyurllist} = [
        urls => $domainFilter->filteredUrls(),
        includes => $domainFilterFiles->filteredUrls(),
    ];

    $default->{bannedurllist} = [
        urls => $domainFilter->bannedUrls(),
        includes => $domainFilterFiles->bannedUrls(),
    ];

    my $domainFilterSettings = $policy->componentByName('DomainFilterSettings', 1);

    $default->{bannedsitelist} = [
        blockIp       => $domainFilterSettings->blockIpValue,
        blanketBlock  => $domainFilterSettings->blanketBlockValue,
        domains       => $domainFilter->banned(),
        includes      => $domainFilterFiles->banned(),
    ];

    return $default;
}


sub antivirusNeeded
{
    my ($self) = @_;

    my $id = 0;
    foreach my $rowId ( @{ $self->ids() } ) {
        my $antivirusModel;
        my $row = $self->row($rowId);
        my $policy =
            $row->elementByName('filterPolicy')->foreignModelInstance();

        if ($id == 0) {
            # default group is always the first
            $antivirusModel =
                $policy->componentByName('DefaultAntiVirus', 1);
        } elsif ($id > MAX_DG_GROUP) {
            my $name  = $row->valueByName('name');
            EBox::info(
                    "Maximum nuber of dansguardian groups reached, group $name and  following groups antivirus configuration is not used"
                    );
            last;
        } else {
            $antivirusModel =
                $policy->componentByName('FilterGroupAntiVirus', 1);
        }

        if ($antivirusModel->active()) {
            return 1;
        }

        $id += 1 ;
    }

    # no profile with antivirus enabled found...
    return 0;
}

# this must be only called one time
sub restoreConfig
{
    my ($class, $dir)  = @_;
    EBox::Squid::Model::DomainFilterFilesBase->restoreConfig($dir);
}

# Security Updates Add-On message
sub _commercialMsg
{
    return __sx(
        'Get Content Filtering updates to keep your HTTP proxy aware of '
        . 'the latest threats such as malware, phishing and bots! The Content '
        . 'Filtering updates are integrated in the {openhref}Advanced Security '
        . 'Updates{closehref} subscription that guarantees that the Antispam, '
        . 'Intrusion Detection System, Content filtering system and Antivirus '
        . 'installed on your Zentyal server are updated on daily basis based '
        . 'on the information provided by the most trusted IT experts.',
        openhref  => '<a href="' . STORE_URL . '" target="_blank">',
        closehref => '</a>');

}

1;
