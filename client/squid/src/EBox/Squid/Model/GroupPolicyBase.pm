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

package EBox::Squid::Model::GroupPolicyBase;
use base 'EBox::Model::DataTable';
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


sub precondition
{
    my ($self) = @_;
    my $users = EBox::Global->modInstance('users');
    return $users->configured();

}

sub preconditionFailMsg
{
    my ($self) = @_;
    return __(
              'User and groups module must have been enabled to configure this section'
             )


}


sub tableHeader
{
 my @tableHeader =
    (
     new EBox::Types::Select(
         fieldName     => 'group',
         printableName => __('Group'),

         populate      => \&populateGroups,
         unique        => 1,
         editable      => 1,
         optional      => 0,

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
     new EBox::Squid::Types::TimePeriod(
                           fieldName => 'timePeriod',
                           printableName => __('Allowed time period'),
                           help          => __('Time period when the access is allowed'),
                           editable => 1,
                          ),
    );

 return \@tableHeader;
}

sub populateGroups
{
    my $userMod = EBox::Global->modInstance('users');
    my @groups = map ( 
                { 
                    value            => $_->{account},
                    printableValue   => $_->{account},
                }, $userMod->groups()
            );
    return \@groups;
}

sub rows
{
    my ($self, $filter, $page) = @_;

    my $userMod = EBox::Global->modInstance('users');

    my $rows = $self->SUPER::rows($filter, $page);
    my $filteredRows = [];
    foreach my $row (@{$rows}) {
        my $userGroup = $row->valueByName('group');
        if (defined($userGroup) and $userMod->groupExists($userGroup)) {
            push (@{$filteredRows}, $row);
        } else {
            $self->removeRow($row->{id}, 1);
        }
    }
    return $filteredRows;
}






sub existsGroupPolicy
{
    my ($self) = @_;
    my $nPolicies = @{ $self->rows() };
    return ($nPolicies > 0);
}


sub groupsPolicies
{
  my ($self) = @_;

  my $userMod = EBox::Global->modInstance('users');  

  my @groupsPol = map {
    my $group =  $_->valueByName('group');
    my $allow = $_->valueByName('policy') eq 'allow';
    my $time = $_->elementByName('timePeriod');
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

  } @{ $self->rows()  };

  return \@groupsPol;
}






1;

