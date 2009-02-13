# Copyright (C) 2009 Warp Networks S.L.
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
use EBox::Gettext;
use EBox::Types::Text;
use EBox::Squid::Types::Policy;
use EBox::Squid::Types::TimePeriod;
use EBox::Types::HasMany;

use constant MAX_DG_GROUP => 99; # max group number allowed by dansguardian

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



# Method: _table
#
#
sub _table
{
    my ($self) = @_;

  my $dataTable =
  {
      tableName          => name(),
      pageTitle          => __(q{Filter profiles}),
#      printableTableName => __('List of groups'),
      modelDomain        => 'Squid',
      'defaultController' => '/ebox/Squid/Controller/FilterGroup',
      'defaultActions' => [     
          'add', 'del',
      'editField',
      'changeView',
          ],
      tableDescription   => $self->tableHeader(),
      class              => 'dataTable',
      rowUnique          => 1,
      automaticRemove    => 1,
      printableRowName   => __("filter profile"),
#      help               => __(""),
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
                                 'backView' => '/ebox/squid/View/FilterGroup',
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

sub rows
{
    my ($self, @params) = @_;

    defined $defaultRow or
        $self->_initDefaultRow();

    my $rows = $self->SUPER::rows(@params);
    unshift @{ $rows }, $defaultRow;

    return $rows;
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
}






sub filterGroups
{
  my ($self) = @_;
  my @filterGroups = (  );

  my $squid   = EBox::Global->modInstance('squid');  
  my $usergroupPolicies =  $squid->model('GlobalGroupPolicy');
  my %usersByFilterGroupId = %{ $usergroupPolicies->usersByFilterGroup()  };


  my $id = 0; # groups will have ids greater that this number
              # remember id 1 is reserved for gd's default group so it must be
              # the first to be getted


  foreach my $row ( @{ $self->rows() } ) {
      my $name  = $row->valueByName('name');
      my $rowId = $row->id();
      
      $id += 1 ; 
      if ($id > MAX_DG_GROUP) {
          EBox::info("Filter group $name and following groups will use default content filter policy because the maximum number of Dansguardian groups is reached");
          last;
      }

      if ($id == 1) {
          # defautl filter group needs special tratment
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
                                  domains => [],
                                  includes => $domainFilterFiles->allowedUrls(),
                                 ];

    $group->{greysitelist} = [ 
                              domains => $domainFilter->filtered(),
                              includes => $domainFilterFiles->filtered(),
                             ];
  
    $group->{greyurllist} = [ 
                             domains => [],
                             includes => $domainFilterFiles->filteredUrls(),
                            ];


    $group->{bannedurllist} = [ 
                               domains => [],
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
                                    domains => [],
                                    includes => $domainFilterFiles->allowedUrls(),
                                   ];

    $default->{greysitelist} = [ 
                        domains => $domainFilter->filtered(),
                        includes => $domainFilterFiles->filtered(),
                       ];
  
    $default->{greyurllist} = [ 
                        domains => [],
                        includes => $domainFilterFiles->filteredUrls(),
                       ];



    $default->{bannedurllist} = [ 
                        domains => [],
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

1;

