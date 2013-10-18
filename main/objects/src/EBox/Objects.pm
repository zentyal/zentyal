# Copyright (C) 2008-2013 Zentyal S.L.
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

package EBox::Objects;

use base qw(EBox::Module::Config);

use Net::IP;
use EBox::Validate qw( :all );
use EBox::Global;
use EBox::Objects::Model::ObjectTable;
use EBox::Objects::Model::MemberTable;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::DataMissing;
use EBox::Exceptions::DataNotFound;
use EBox::Gettext;

sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'objects',
                                      printableName => __('Objects'),
                                      @_);
    bless($self, $class);

    return $self;
}

## api functions

# Method: objects
#
#       Return all object names
#
# Returns:
#
#       Array ref. Each element is a hash ref containing:
#
#       id - object's id
#       name - object's name
sub objects
{
    my ($self) = @_;

    my @objects;
    my $model = $self->model('ObjectTable');
    for my $id (@{$model->ids()}) {
    my $object = $model->row($id);
        push (@objects, {
                            id => $id,
                            name => $object->valueByName('name')
                         });
    }

    return \@objects;
}

# Method: objectIds
#
#       Return all object ids
#
# Returns:
#
#       Array ref - containing ids
sub objectIds # (object)
{
    my ($self) = @_;

    my @ids = map { $_->{'id'} }  @{$self->objects()};
    return  \@ids;
}

# objectMembers
#
#       Return the members belonging to an object
#
# Parameters:
#
#       (POSITIONAL)
#
#       id - object's id
#
# Returns:
#
#       <EBox::Objects::Members>
#
# Exceptions:
#
#       <EBox::Exceptions::MissingArgument>
sub objectMembers # (object)
{
    my ($self, $id) = @_;

    unless (defined($id)) {
        throw EBox::Exceptions::MissingArgument("id");
    }

    my $object = $self->model('ObjectTable')->row($id);
    return undef unless defined($object);

    return $object->subModel('members')->members();
}

# objectAddresses
#
#       Return the network addresses of a object
#
# Parameters:
#
#       id - object's id
#       mask - return alse addresses' mask (named optional, default false)
#
# Returns:
#
#       array ref - containing an ip, empty array if
#       there are no addresses in the object
#       In case mask is wanted the elements of the array would be  [ip, mask]
#
sub objectAddresses
{
    my ($self, $id, @params) = @_;

    unless (defined($id)) {
        throw EBox::Exceptions::MissingArgument("id");
    }

    my $members = $self->objectMembers($id);
    if (not $members) {
        return undef;
    }

    return $members->addresses(@params);
}

# Method: objectDescription
#
#       Return the description of an Object
#
# Parameters:
#
#       id - object's id
#
# Returns:
#
#       string - description of the Object
#
# Exceptions:
#
#       DataNotFound - if the Object does not exist
sub objectDescription  # (object)
{
    my ( $self, $id ) = @_;

    unless (defined($id)) {
        throw EBox::Exceptions::MissingArgument("id");
    }

    my $object = $self->model('ObjectTable')->row($id);
    unless (defined($object)) {
        throw EBox::Exceptions::DataNotFound('data' => __('Object'),
                'value' => $object);
    }

    return $object->valueByName('name');
}

# get ( $id, ['name'])

# Method: objectInUse
#
#       Asks all installed modules if they are currently using an Object.
#
# Parameters:
#
#       object - the name of an Object
#
# Returns:
#
#       boolean - true if there is a module which uses the Object, otherwise
#       false
sub objectInUse # (object)
{
    my ($self, $object ) = @_;

    unless (defined($object)) {
        throw EBox::Exceptions::MissingArgument("id");
    }

    my $global = EBox::Global->getInstance();
    my @mods = @{$global->modInstancesOfType('EBox::ObjectsObserver')};
    foreach my $mod (@mods) {
        if ($mod->usesObject($object)) {
            return 1;
        }
    }

    return undef;
}

# Method: objectExists
#
#       Checks if a given object exists
#
# Parameters:
#
#       id - object's id
#
# Returns:
#
#       boolean - true if the Object exists, otherwise false
sub objectExists
{
    my ($self, $id) = @_;

    unless (defined($id)) {
        throw EBox::Exceptions::MissingArgument("id");
    }

    return defined($self->model('ObjectTable')->row($id));
}

# Method: removeObjectForce
#
#       Forces an object to be deleted
#
# Parameters:
#
#       object - object description
#
sub removeObjectForce # (object)
{
    #action: removeObjectForce

    my ($self, $object)  = @_;
    my $global = EBox::Global->getInstance();
    my @mods = @{$global->modInstancesOfType('EBox::ObjectsObserver')};
    foreach my $mod (@mods) {
        $mod->freeObject($object);
    }
}

# Method: addObject
#
#   Add object to the objects table.
#
# Parameters:
#
#   (NAMED)
#   id         - object's id *(optional*). It will be generated automatically
#                if none is passed
#   name       - object's name
#   members    - array ref containing the following hash ref in each value:
#
#                name        - member's name
#                address_selected - type of address, can be:
#                                'ipaddr', 'iprange' (default: ipdaddr)
#
#                ipaddr  parameters:
#                   ipaddr_ip   - member's ipaddr
#                   ipaddr_mask - member's mask
#                   macaddr     - member's mac address *(optional)*
#
#               iprange parameters:
#                   iprange_begin - begin of the range
#                   iprange_end   - end of range
#
#   readOnly   - the service can't be deleted or modified *(optional)*
#
#   Example:
#
#       name => 'administration',
#       members => [
#                   { 'name'         => 'accounting',
#                     'address_selected' => 'ipaddr',
#                     'ipaddr_ip'    => '192.168.1.3',
#                     'ipaddr_mask'  => '32',
#                     'macaddr'      => '00:00:00:FA:BA:DA'
#                   }
#                  ]

sub addObject
{
    my ($self, %params) = @_;

    return $self->model('ObjectTable')->addObject(%params);
}

# Method: menu
#
#       Overrides EBox::Module method.
#
#
sub menu
{
    my ($self, $root) = @_;

    my $folder = new EBox::Menu::Folder('name' => 'Network',
                                        'icon' => 'network',
                                        'text' => __('Network'),
                                        'separator' => 'Core',
                                        'order' => 40);

    my $item = new EBox::Menu::Item('url' => 'Network/Objects',
                                    'text' => __($self->title),
                                    'order' => 40);
    $folder->add($item);
    $root->add($folder);
}

1;
