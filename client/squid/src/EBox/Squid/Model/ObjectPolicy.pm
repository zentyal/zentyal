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
use EBox::Types::Boolean;
use EBox::Types::Text;
use EBox::Squid::Types::Policy;

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

# Group: Protected methods

# Method: _table
#
#       The table description which consists of three fields:
#
#       name          - <EBox::Types::Text>
#       description   - <EBox::Types::Text>
#       configuration - <EBox::Types::Union>. It could have one of the following:
#                     - model - <EBox::Types::HasMany>
#                     - link  - <EBox::Types::Link>
#                     - none  - <EBox::Types::Union::Text>
#       enabled       - <EBox::Types::Boolean>
#
#       You can only edit enabled and configuration fields. The event
#       name and description are read-only fields.
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
    );

  my $dataTable =
    {
     tableName          => name(),
     printableTableName => __(q{Configure network objects' policies}),
     modelDomain        => 'Squid',
     'defaultController' => '/ebox/Squid/Controller/ObjectPolicy',
     'defaultActions' => [	
			  'add', 'del',
			  'editField',
			  'changeView'
			 ],
     tableDescription   => \@tableHeader,
     class              => 'dataTable',
     order              => 0,
     rowUnique          => 1,
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




sub _objectsByPolicy
{
  my ($self, $policy) = @_;

  EBox::Squid::Types::Policy->checkPolicy($policy);

  my @objects =  map {
    $_->{object}
  }  @{ $self->findAllValue(policy => $policy) };

  return \@objects;
}

sub _objectHasPolicy
{
  my ($self, $object, $policy) = @_;

  EBox::Squid::Types::Policy->checkPolicy($policy);

  my $objectRow = $self->findValue(object => $object);
  if (not defined $objectRow) {
    throw EBox::Exceptions::External('{o} does not exists', o => $object );
  }

  return $object->{policy} eq $policy;
}

#
# Method: filtered
#
#	Returns a list of filtered objects
#
# Parameters:
#
#	array ref - holding the object names
#
sub filtered
{
  my($self) = @_;
  return $self->_objectsByPolicy('filter');

}

# Method: unfiltered
#
#	Returns a list of unfiltered objects
#
# Parameters:
#
#	array ref - holding the object names
#
sub unfiltered
{
  my($self) = @_;
  return $self->_objectsByPolicy('allow');

}


# Method: isUnfiltered
#
#	Checks if a given object is set as unfiltered
#
# Parameters:
#
#	object - object name
#
# Returns:
#
#	boolean - true if it's set as unfiltered, otherwise false
sub isUnfiltered # ($object)
{
  my ($self, $object) = @_;
  $self->_objectHasPolicy($object, 'allow');
}


#
# Method: banned
#
#	Returns the list of banned objects.
#
# Returns:
#
#	array ref - holding the objects
#
sub banned
{
  my($self) = @_;
  return $self->_objectsByPolicy('deny');

}

# Method: isBanned
#
#	Checks if a given object is banned
#
# Parameters:
#
#	object - object name
#
# Returns:
#
#	boolean - true if it's set as banned, otherwise false
sub isBanned # ($object)
{
  my ($self, $object) = @_;
  $self->_objectHasPolicy($object, 'deny');
}

1;

