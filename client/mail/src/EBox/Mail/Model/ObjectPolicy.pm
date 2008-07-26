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

package EBox::Mail::Model::ObjectPolicy;
use base 'EBox::Model::DataTable';
# Class:
#
#    EBox::Mail::Model::ObjectPolicy
#
#
#   It subclasses <EBox::Model::DataTable>
#

# eBox uses
use EBox;

use EBox::Exceptions::Internal;
use EBox::Gettext;
use EBox::Types::Boolean;
use EBox::Types::Select;


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
#       <EBox::Mail::Model::ObjectPolicy> - the recently
#       created model
#
sub new
  {

      my $class = shift;

      my $self = $class->SUPER::new(@_);

      bless $self, $class;
      return $self;

  }

# Method: headTitle
#
# Overrides:
#   
#   <EBox::Model::Component::headTitle>
#
sub headTitle
{
    return undef; 
}

# Group: Protected methods

# Method: _table
#
#       The table description 
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
                            ),
     new EBox::Types::Boolean(
                                    fieldName     => 'allow',
                                    printableName => __('Allow relay'),
                                    editable      => 1,
                                   ),
    );

  my $dataTable =
    {
     tableName          => __PACKAGE__->nameFromClass,
     printableTableName => __(q{Relay policy for network objects'}),
     modelDomain        => 'Mail',
     'defaultController' => '/ebox/Mail/Controller/ObjectPolicy',
     'defaultActions' => [      
                          'add', 'del',
                          'editField',
                          'changeView'
                         ],
     tableDescription   => \@tableHeader,
     class              => 'dataTable',
     order              => 0,
     rowUnique          => 1,
     printableRowName   => __("object's relay policy"),
     help               => __("Here you can allow mail relay per network object"),
    };

}

sub objectModel
{
    my $objects = EBox::Global->getInstance()->modInstance('objects');
    return $objects->{'objectModel'};
}



# Method: allowedAddresses
#
# Returns:
#   - reference to a list of addresses for which relay is allowed
# 
sub allowedAddresses
{
    my ($self) = @_;
    
    my $objects = EBox::Global->modInstance('objects');
    my @addr = map {
        @{ $objects->objectAddresses($_)  }
    } @{ $self->_objectsByAllowPolicy(1)  };

    return \@addr;

}



sub _objectsByAllowPolicy
{
  my ($self, $allowPolicy) = @_;

  my $rows_r  =  $self->findAll(allow => $allowPolicy);

  my $objectsModel = $self->objectModel();
  my @objects = map {
      my $id  = $_->elementByName('object')->value();
      $id
  }  @{ $rows_r };


  return \@objects;
}

# Method: isAllowed
#
# returns wether a given object is allowed to relay mail. Objects no present in
# this table will have relay denied by default
sub isAllowed
{
  my ($self, $object) = @_;


  my $objectRow = $self->_findRowByObjectName($object);
  if (not defined $objectRow) {
    # not policy , default is to deny
      return undef;
  }

  return $objectRow->elementByName('allow')->value() ? 1 : undef;
}


sub freeObject
{
    my ($self, $object) = @_;
    
    my $row = $self->_findRowByObjectName($object);
    my $id = $row->id();
    $self->removeRow($id, 1);
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

