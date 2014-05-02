# Copyright (C) 2004-2007 Warp Networks S.L.
# Copyright (C) 2008-2014 Zentyal S.L.
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

use base qw( EBox::Module::Service );

use Net::IP;
use Net::Netmask;
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

use constant P0F_CONFIG_FILE  => '/etc/p0f/p0f.fp';
use constant P0F_SOCKET       => '/var/run/p0f/p0f.sock';
use constant P0F_DEFAULT_FILE => '/etc/default/p0f';

sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'objects',
                                      printableName => __('Objects'),
                                      @_);
    bless($self, $class);

    return $self;
}

sub _registerDynamicObjects
{
    my ($self) = @_;

    $self->dynamicObjectRegister(
        {
            name            => 'os_linux',
            printableName   => 'Linux devices',
        }
    ) unless $self->dynamicObjectIsRegistered('os_linux');
    $self->dynamicObjectRegister(
        {
            name            => 'os_windows',
            printableName   => 'Microsoft Windows devices',
        }
    ) unless $self->dynamicObjectIsRegistered('os_windows');
    $self->dynamicObjectRegister(
        {
            name            => 'os_mac',
            printableName   => 'Apple Mac OS devices',
        }
    ) unless $self->dynamicObjectIsRegistered('os_mac');
    $self->dynamicObjectRegister(
        {
            name            => 'os_android',
            printableName   => 'Android devices',
        }
    ) unless $self->dynamicObjectIsRegistered('os_android');
    $self->dynamicObjectRegister(
        {
            name            => 'os_ios',
            printableName   => 'Apple iOS (iPhone and iPad)',
        }
    ) unless $self->dynamicObjectIsRegistered('os_ios');
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

# Method: usedFiles
#
# Overrides:
#
#  <EBox::Module::Service::usedFiles>
#
sub usedFiles
{
    return [
        {
            'file'   => P0F_DEFAULT_FILE,
            'reason' => __('To set up the configuration settings for p0f daemon'),
            'module' => 'objects',
        },
        {
            'file'   => P0F_CONFIG_FILE,
            'reason' => __('To set up the fingerprint database for p0f daemon'),
            'module' => 'objects',
        },
    ];
}

sub _snifferCond
{
    my ($self) = @_;

    my $model = $self->model('ObjectTable');
    foreach my $id (@{$model->ids()}) {
        my $row = $model->row($id);
        my $type = $row->elementByName('type');
        next unless defined $type->set();

        return 1 if $self->dynamicObjectIsRegistered($type->set());
    }

    return 0;
}

sub _daemons
{
    my ($self) = @_;

    my $daemons = [
        {
            name => 'p0f',
            precondition => \&_snifferCond,
        },
    ];

    return $daemons;
}

sub _setConf
{
    my ($self) = @_;

    $self->_registerDynamicObjects();

    my $network = $self->global->modInstance('network');
    my @captureFilter;
    my $ifaces = $network->ifaces();
    foreach my $iface (@{$ifaces}) {
        next unless ($network->ifaceOnConfig($iface));
        next if ($network->ifaceIsExternal($iface));

        my $ifaceData = $network->ifaceAddresses($iface);
        foreach my $addr (@{$ifaceData}) {
            my $ip = $addr->{address};
            my $mask = $addr->{netmask};
            next unless (length $ip and length $mask);

            my $m = new Net::Netmask($ip, $mask);
            my $netcidr = $m->base() . '/' . $m->bits();
            push (@captureFilter, "((src net $netcidr) and (not src $ip))");
        }
    }
    my $captureFilter = join (' or ', @captureFilter);

    my $data = [];
    push (@{$data}, interface => 'any');
    push (@{$data}, conffile  => P0F_CONFIG_FILE);
    push (@{$data}, socket    => P0F_SOCKET);
    push (@{$data}, connAge   => 30);
    push (@{$data}, hostAge   => 120);
    push (@{$data}, filter    => $captureFilter);
    $self->writeConfFile(P0F_DEFAULT_FILE, '/objects/p0f.default.mas', $data,
        { uid => 0, gid => 0, mode => '0640' });

    $data = [];
    push (@{$data}, os_linux => 1);
    push (@{$data}, os_win => 1);
    push (@{$data}, os_mac => 1);
    push (@{$data}, os_ios => 1);
    push (@{$data}, os_android => 1);
    push (@{$data}, ipset_os_linux => 'os_linux');
    push (@{$data}, ipset_os_win => 'os_windows');
    push (@{$data}, ipset_os_mac => 'os_mac');
    push (@{$data}, ipset_os_ios => 'os_ios');
    push (@{$data}, ipset_os_android => 'os_android');
    $self->writeConfFile(P0F_CONFIG_FILE, '/objects/p0f.fp.mas', $data,
        { uid => 0, gid => 0, mode => '0640' });
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
    if (not $object) {
        throw EBox::Exceptions::DataNotFound(
                        data   => __('network object'),
                        value  => $id
           );
    }

    return $object->subModel('members')->members();
}

# Method: objectIsDynamic
#
#   TODO
#
# Parameters:
#
#
# Returns:
#
#
sub objectIsDynamic
{
    my ($self, $id, @params) = @_;

    unless (defined($id)) {
        throw EBox::Exceptions::MissingArgument("id");
    }

    my $model = $self->model('ObjectTable');
    my $row = $model->row($id);
    my $type = $row->elementByName('type');

    return (defined $type->set());
}

# Method: objectAddresses
#
#       Return the network addresses of an object
#
# Parameters:
#
#       id - object's id
#       mask - return addresses' mask as well (named optional, default false)
#
# Returns:
#
#       array ref - containing an IP Address, empty array if there are no addresses in the object
#       In case mask is wanted the elements of the array would be  [ip, mask]
#
sub objectAddresses
{
    my ($self, $id, @params) = @_;

    unless (defined($id)) {
        throw EBox::Exceptions::MissingArgument("id");
    }

    my $members = $self->objectMembers($id);
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

# Method: dynamicObjectRegister
#
#   Stores the object metadata in the module state. This information will be
#   used to populate the dynamic object types selector in the ObjectTable
#   model
#
# Arguments:
#
#   params - Hash ref - Dynamic object metadata, containing the following keys
#       name            - The ipset the host will be added by p0f daemon
#       printableName   - The name to show in the web interface
#
sub dynamicObjectRegister
{
    my ($self, $params) = @_;

    unless (defined $params) {
        throw EBox::Exceptions::MissingArgument('params');
    }
    unless (defined $params->{name}) {
        throw EBox::Exceptions::MissingArgument('name');
    }
    unless (defined $params->{printableName}) {
        throw EBox::Exceptions::MissingArgument('printableName');
    }

    my $name = $params->{name};
    if ($self->dynamicObjectIsRegistered($name)) {
        throw EBox::Exceptions::DataExists();
    }

    my $state = $self->get_state();
    my $registeredDynamicObjects = $state->{dynamicObjects};
    $registeredDynamicObjects->{$name} = $params;
    $state->{dynamicObjects} = $registeredDynamicObjects;
    $self->set_state($state);
}

# Method: dynamicObjectIsRegistered
#
#   Checks if a dynamic object metadata is registered.
#
# Returns:
#
#   boolean - True if object is registered, false otherwise.
#
sub dynamicObjectIsRegistered
{
    my ($self, $name) = @_;

    my $state = $self->get_state();
    my $registeredDynamicObjects = $state->{dynamicObjects};
    return exists $registeredDynamicObjects->{$name};
}


1;
