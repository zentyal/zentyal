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

package EBox::Squid::Model::GroupPolicyBase;
use base 'EBox::Model::DataTable';
# Class:
#
#    EBox::Squid::Model::GroupPolicy
#
#
#   It subclasses <EBox::Model::DataTable>
#

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




sub tableHeader
{
    my ($self) = @_;
    


 my @tableHeader =
    (
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
     new EBox::Squid::Types::TimePeriod(
                           fieldName => 'timePeriod',
                           printableName => __('Time period'),
                           help => $self->_timePeriodHelp(),
                           editable => 1,
                          ),
    );

 return \@tableHeader;
}


sub _timePeriodHelp
{
    return 
  __('Time period when the access is allowed. It is ignored with a deny policy');
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

sub syncRows
{
    my ($self, $currentIds) = @_;

    my $userMod = EBox::Global->modInstance('users');

  my $anyChange = undef;
    for my $id (@{$currentIds}) {
        my $userGroup = $self->row($id)->valueByName('group');
        unless(defined($userGroup) and length ($userGroup) > 0) {
            $self->removeRow($id, 1);
            $anyChange = 1;
        }
    }
    return $anyChange;

}






sub existsGroupPolicy
{
    my ($self) = @_;
    my $nPolicies = @{ $self->ids() };
    return ($nPolicies > 0);
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

  } @{ $self->ids()  };

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


sub precondition
{
    my ($self) = @_;
    my $users = EBox::Global->modInstance('users');
    $users->isEnabled() or
        return 0;

    return $users->groups() > 0; 
}

sub preconditionFailMsg
{
    my $users = EBox::Global->modInstance('users');
    my $mode = $users->mode();
    if ($mode eq 'master') {
        return __x(
'There are no user groups in the system. {open}Create{close} at least one group  if you want to set a group policy',
open => q{<a href='/ebox/UsersAndGroups/Groups'>},
close => q{</a>}
        );
    } elsif ($mode eq 'slave') {
        my $master = $users->model('Mode')->remoteValue();
        return __x(
'There are no user groups in the system. {open}Create{close} at least one group  if you want to set a group policy',
open => "<a href='https://$master/ebox/UsersAndGroups/Groups'>",
close => "</a>"
        );
    }
}

1;

