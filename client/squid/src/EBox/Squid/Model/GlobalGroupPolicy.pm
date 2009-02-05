# Copyright (C) 2008 Warp Networks S.L.
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

package EBox::Squid::Model::GlobalGroupPolicy;
use base 'EBox::Squid::Model::GroupPolicyBase';
# Class:
#
#    EBox::Squid::Model::GroupPolicy
#
#
#   It subclasses <EBox::Model::DataTable>
#

# eBox uses
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
      pageTitle          => __(q{Configure user's groups global policies}),
      printableTableName => __('List of groups'),
      modelDomain        => 'Squid',
      'defaultController' => '/ebox/Squid/Controller/GlobalGroupPolicy',
      'defaultActions' => [     
          'add', 'del',
      'editField',
      'changeView',
      'move',
          ],
      tableDescription   => $self->tableHeader(),
      class              => 'dataTable',
      order              => 1,
      rowUnique          => 1,
      automaticRemove    => 1,
      printableRowName   => __("group's policy"),
      help               => __("Here you can globaly block or allow access per user group. Filter options will be per global policy or per object policy"),
      messages           => {
          add => __(q{Added group's policy}),
          del =>  __(q{Removed group's policy}),
          update => __(q{Updated group's policy}),
      },
  };

}


sub tableHeader
{
    my ($self) = @_;

    my $header = $self->SUPER::tableHeader() ;

    my @policyElements = (
                          new EBox::Types::Select(
                              fieldName => 'filterGroup',
                              printableName => __('Filter profile'),
                      
                              foreignModel  => \&filterGroupModel,
                              foreignField  => 'name',
                              
                               defaultValue  => 'default',
                               editable      => 1,
                                                 ),

                         );

    push @{ $header }, @policyElements;
       
    return $header;
}

sub name
{
    return 'GlobalGroupPolicy';
}


sub filterGroupModel
{
    my ($self) = @_;
    my $sq = EBox::Global->modInstance('squid');
    return $sq->model('FilterGroup');
}

sub validateTypedRow
{
  my ($self, $action, $params_r, $actual_r) = @_;
  $self->_checkTransProxy($params_r, $actual_r);
  $self->_checkGlobalPolicy();
}


sub _checkTransProxy
{
  my ($self, $params_r, $actual_r) = @_;

  my $squid = EBox::Global->modInstance('squid');
  if (not $squid->transproxy()) {
    return;
  }

  if ($self->existsGroupPolicy()) {
    throw EBox::Exceptions::External(
       __('User group policies are not compatible with transparent proxy mode')
                                    );
  }
}


sub _checkGlobalPolicy
{
    my ($self) = @_;

    my $squid = EBox::Global->modInstance('squid');
    if (not $squid->globalPolicyUsesAuth()) {
    throw EBox::Exceptions::External(
       __('Global group policy need a global policy with authentication')
                                    );        
    }
}


sub usersByFilterGroup
{
    my ($self) = @_;

    my %usersSeen;
    my %usersByFilterGroup;

    my $usersMod = EBox::Global->modInstance('users');
    my $filterGroupsModel = EBox::Global->modInstance('squid')->model('FilterGroup');

    foreach my $row (@{ $self->rows() }) {
        my $userGroup   = $row->elementByName('group')->printableValue();
#         my $filterGroupRowId = $row->valueByName('filterGroup');
#         my $filterGroup  = $filterGroupsModel->row($filterGroupRowId)->valueByName('name');
#         EBox::debug("userGroup $userGroup");
#         EBox::debug("filterGroup $filterGroup");
        my $filterGroup = $row->valueByName('filterGroup');

        my @users;
        foreach my $user ( @{ $usersMod->usersInGroup($userGroup) } ) {
            if (exists $usersSeen{$user}) {
                next;
            }

            $usersSeen{$user} = 1;
            push @users, $user;
        }


        if ($filterGroup eq 'default') {
            next;
        }
        

        if (not exists $usersByFilterGroup{$filterGroup}) {
            $usersByFilterGroup{$filterGroup} = \@users;
        }
        else {
            push @{ $usersByFilterGroup{$filterGroup} }, @users;
        }
    }

    return \%usersByFilterGroup;
}

1;

