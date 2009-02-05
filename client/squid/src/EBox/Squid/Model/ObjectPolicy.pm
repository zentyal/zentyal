# Copyright (C) 2007 Warp Networks S.L.
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

package EBox::Squid::Model::ObjectPolicy;
use base 'EBox::Model::DataTable';
# Class:
#
#    EBox::Squid::Model::ObjectPolicy
#
#
#   It subclasses <EBox::Model::DataTable>
#

# eBox uses
use EBox;

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
#       <EBox::Squid::Model::ObjectPolicy> - the recently
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
  my @tableHeader =
    (
     new EBox::Types::Select(
         fieldName     => 'object',
         foreignModel  => \&objectModel,
         foreignField  => 'name',

         printableName => __('Object'),
         unique        => 1,
         editable      => 1,
         optional      => 0,
         ),
     new EBox::Squid::Types::Policy(
         fieldName     => 'policy',
         printableName => __('Policy'),
         ),
     new EBox::Squid::Types::TimePeriod(
                           fieldName => 'timePeriod',
                           printableName => __('Time period'),
                           editable => 1,
                          ),

     new EBox::Types::HasMany
     (
      'fieldName' => 'groupPolicy',
      'printableName' => __('Group policy'),
      'foreignModel' => 'ObjectGroupPolicy',
      'view' => '/ebox/Squid/View/ObjectGroupPolicy',
      'backView' => '/ebox/Squid/View/ObjectGroupPolicy',
      'size' => '1',
     ),
     
    );

  my $dataTable =
  {
      tableName          => name(),
      pageTitle          => __(q{Configure network objects' policies}),
      printableTableName => __('List of objects'),
      modelDomain        => 'Squid',
      'defaultController' => '/ebox/Squid/Controller/ObjectPolicy',
      'defaultActions' => [     
          'add', 'del',
      'editField',
      'changeView',
      'move',
          ],
      tableDescription   => \@tableHeader,
      class              => 'dataTable',
      order              => 1,
      rowUnique          => 1,
      automaticRemove    => 1,
      printableRowName   => __("object's policy"),
      help               => __("Here you can establish a custom policy per network object"),
      messages           => {
          add => __(q{Added object's policy}),
          del =>  __(q{Removed object's policy}),
          update => __(q{Updated object's policy}),
      },
  };

}

sub objectModel
{
    my $objects = EBox::Global->getInstance()->modInstance('objects');
    return $objects->{'objectModel'};
}


sub name
{
    return 'ObjectPolicy';
}

sub validateTypedRow
{
  my ($self, $action, $params_r, $actual_r) = @_;
  $self->_checkPolicyWithTransProxy($params_r, $actual_r);
  $self->_checkPolicyWithTimePeriod($params_r, $actual_r);
  $self->_checkPolicyWithGroupsPolicy($params_r, $actual_r);
}


sub _checkPolicyWithTransProxy
{
  my ($self, $params_r, $actual_r) = @_;

  my $squid = EBox::Global->modInstance('squid');
  if (not $squid->transproxy()) {
    return;
  }


  my $pol = exists $params_r->{policy} ?
                     $params_r->{policy}:
                     $actual_r->{policy} ;

  if ($pol->usesAuth()) {
    throw EBox::Exceptions::External(
       __('Authorization policy is not compatible with transparent proxy mode')
                                    );
  }
}

sub _checkPolicyWithTimePeriod
{
  my ($self, $params_r, $actual_r) = @_;

  my $policy = exists $params_r->{policy} ?
                     $params_r->{policy} :
                     $actual_r->{policy} ;

  my $time = exists $params_r->{timePeriod} ?
                     $params_r->{timePeriod} :
                     $actual_r->{timePeriod} ;

  if ($time->isAllTime()) {
      return;
  }

  if ($policy->usesFilter()) {
      throw EBox::Exceptions::External(
         __('Filter policies are incompatible with restricted time periods')
                                      );
  }

}



sub _checkPolicyWithGroupsPolicy
{
  my ($self, $params_r, $actual_r) = @_;


  my $policy = exists $params_r->{policy} ?
                     $params_r->{policy} :
                     $actual_r->{policy} ;

  my $usesAuth = $policy->usesAuth();
  if ($usesAuth) {
      return;
  }

  my $groupPolicyElement = $actual_r->{groupPolicy};
  my $groupPolicy        = $groupPolicyElement->foreignModelInstance();
  if ($groupPolicy->size() > 0) {
      throw EBox::Exceptions::External(
   __('You cannot choose a policy without authorization if you have any group policy')
                                      );
  }

}

sub objectsPolicies
{
  my ($self) = @_;

  my $objectMod = EBox::Global->modInstance('objects');
  
  my @obsPol = map {
      my $row = $_;

      my $obj           = $row->valueByName('object');
      my $addresses     = $objectMod->objectAddresses($obj);

      my $policy        = $row->elementByName('policy');
      my $auth          = $policy->usesAuth();
      my $allowAll      = $policy->usesAllowAll();
      my $filter        = $policy->usesFilter();

      my $timePeriod    = $row->elementByName('timePeriod');
      my $groupPolicy   = $row->subModel('groupPolicy');

    if (@{ $addresses }) {
      my $obPol = { 
                   object    => $obj, 
                   addresses => $addresses, 
                   auth      => $auth,
                   allowAll  => $allowAll,
                   filter    => $filter,
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

  } @{ $self->rows()  };

  return \@obsPol;
}

sub existsAuthObjects
{
  my ($self) = @_;

  foreach  ( @{ $self->rows() } )  {
    my $obPolicy = $_->valueByName('policy');
    my $groupPolicy = $_->subModel('groupPolicy');

    return 1 if $obPolicy eq 'auth';
    return 1 if $obPolicy eq 'authAndFilter';

    return 1 if @{ $groupPolicy->groupsPolicies() } > 0;
  }

  return undef;
}





sub existsFilteredObjects
{
  my ($self) = @_;

  foreach  ( @{ $self->rows() } )  {
    my $obPolicy = $_->valueByName('policy');
    return 1 if $obPolicy eq 'filter';
    return 1 if $obPolicy eq 'authAndFilter';
  }

  return undef;
}

sub _objectsByPolicy
{
    my ($self, $policy) = @_;
    
    EBox::Squid::Types::Policy->checkPolicy($policy);
    

    my @objects = map {
        my $obPolicy = $_->valueByName('policy');
        ($obPolicy eq $policy) ? $_->valueByName('object') : ()
        
    } @{ $self->rows()  };


    
    return \@objects;
}

sub _objectHasPolicy
{
    my ($self, $object, $policy) = @_;
    
    EBox::Squid::Types::Policy->checkPolicy($policy);
    

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
sub isUnfiltered # ($object)
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
sub isBanned # ($object)
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

