# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
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

package EBox::Objects;

use strict;
use warnings;

use base 'EBox::GConfModule';

use Net::IP;
use EBox::Validate qw( :all );
use EBox::Global;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::DataMissing;
use EBox::Exceptions::DataNotFound;
use EBox::Gettext;
use EBox::LogAdmin qw(:all);

sub _create 
{
	my $class = shift;
	my $self = $class->SUPER::_create(name => 'objects',
					title => __n('Objects'),
					domain => 'ebox-objects',
					@_);

	$self->{'actions'} = {};
	$self->{'actions'}->{'add_object'} = __n('Added object {object}');
	$self->{'actions'}->{'add_to_object'} = 
		__n('Added {nname} ({ip}/{mask} [{mac}]) to object {object}');
	$self->{'actions'}->{'remove_object'} = __n('Removed object {object}');
	$self->{'actions'}->{'remove_object_force'} = 
		__n('Forcefully removed object {object}');
	$self->{'actions'}->{'remove_from_object'} =
		__n('Removed {nname} from object {object}');


	bless($self, $class);
	return $self;
}

## api functions

# Method: ObjectsArray
#
#   	Returns all the created objects
#
# Returns:
#
#   	array ref - each element contains a hash with the object keys 'name' 
#   	(object's name), 'member' (array ref holding members of the object)
sub ObjectsArray
{
	my $self = shift;
	my @array = ();
	my @objs = @{$self->all_dirs_base("")};
	foreach (@objs) {
		my $hash = $self->hash_from_dir($_);
		$hash->{name} = $_;
		$hash->{member} = $self->array_from_dir($_);
		push(@array, $hash);
	}
	return \@array;
}

# Method: ObjectMemberss
#
#   	Returns the members belonging to an object
#
# Returns:
#
#   	array ref - each element contains a hash with the member keys 'nname' 
#   	(member's name), 'ip' (ip's member), 'mask' (network mask's member),
#   	'mac', (mac adress' member)
sub ObjectMembers # (object) 
{
	my ( $self, $object ) = @_;
	return $self->array_from_dir($object);
}

# Method: ObjectDescription
#   
# 	Returns the description of an Object
#
# Parameteres:
#   
# 	object - the name of an Object
#
# Returns:
#
# 	string - description of the Object
#
# Exceptions: 
#
# 	DataNotFound - if the Object does not exist
sub ObjectDescription  # (object) 
{
	my ( $self, $object ) = @_;
	$self->dir_exists($object) or 
		throw EBox::Exceptions::DataNotFound('data' => __('Object'),
						     'value' => $object);
	return $self->get_string("$object/description");
}

# Method: ObjectNames
#   
# 	Returns all the object names
#
# Returns:
#
# 	array ref - holding the object names
#
sub ObjectNames
{
	my $self = shift;
	return $self->all_dirs_base("");
}

# Method: ObjectAddresses
#   
# 	Returns all the object names
#
# Returns:
#
# 	array ref - each element holds a hash containing the keys: 
# 	'ip' and 'mask'
#
sub ObjectAddresses  # (object) 
{
	my ( $self, $object ) = @_;
	my @array = $self->all_dirs("$object");

	my @addresses = ();
	foreach (@array) {
		push(@addresses, $self->get_string("$_/ip") . "/" .
				 $self->get_int("$_/mask"));
	}
	return \@addresses;
}

#
# Method: objectInUse
#
#   	Asks all installed modules if they are currently using an Object.
#
# Parameters:
#
# 	object - the name of an Object
#
# Returns:
#   
# 	boolean - true if there is a module which uses the Object, otherwise 
# 	false
sub objectInUse # (object) 
{
	my ($self, $object ) = @_;
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
#   	Checks if a given object exists
#   	
# Parameters:
#   
# 	name - the name of an Object
#
# Returns:
#
# 	boolean - true if the Object exists, otherwise false
sub objectExists # (name) 
{
	my ($self, $object ) = @_;
	return $self->dir_exists($object);
}

# Method: addObject
#
#   	Adds a new object
#   	
# Parameters:
#   
# 	object - object description
#
sub addObject # (description) 
{
	#action: add_object

	my ($self, $desc ) = @_;
	
	unless (defined($desc) && $desc ne "") {
		throw EBox::Exceptions::DataMissing
			('data' => __('Object name'));
	}

	# normalize description
	$desc =~ s/^\s+//;
	$desc =~ s/\s+$//;
	$desc =~ s/\s+/ /g;

	foreach my $object (@{ $self->ObjectNames() }) {
	    my $otherDesc = $self->ObjectDescription($object);
	    if ($desc eq $otherDesc) {
		throw EBox::Exceptions::External __x("The name '{name}' is already used to identify another object. Please choose another name" ,name => $desc);
	    }
	}


	my $id = $self->get_unique_id("x");

	$self->set_string("$id/description", $desc);
	logAdminDeferred('objects',"add_object","object=$desc");
	return $id;
}

#deletes the Object passed as parameter
sub _removeObject  # (object) 
{
	my ($self, $object)  = @_;
	unless (defined($object) && $object ne "") {
		return;
	}
	if ($self->dir_exists($object)){
		$self->delete_dir($object);
		return 1;
	} else {
		return undef;
	}
}

# Method: removeObjectForce 
#
#   	Forces an object to be deleted
#   	
# Parameters:
#   
# 	object - object description
#
sub removeObjectForce # (object) 
{
	#action: remove_object_force
	
	my ($self, $object)  = @_;
	my $global = EBox::Global->getInstance();
	my @mods = @{$global->modInstancesOfType('EBox::ObjectsObserver')};
	foreach my $mod (@mods) {
		$mod->freeObject($object);
	}
	my $oname = $self->get_string("$object/description");
	logAdminDeferred('objects',"remove_object_force","object=$oname");
	return $self->_removeObject($object);
}

# Method: removeObject
#
#   	Tries to delete an object if it's not used. It raises an excepion
#   	if the object is used.
#   	
# Parameters:
#   
# 	object - object description
#
# Exceptions:
#
#   	DataInUse - If the object to be deleted is used
#
sub removeObject # (object) 
{
	#action: remove_object
	
	my ($self, $object)  = @_;
	if ($self->objectInUse($object)) {
		throw EBox::Exceptions::DataInUse();
	} else {
		my $oname = $self->get_string("$object/description");
		logAdminDeferred('objects',"remove_object","object=$oname");
		return $self->_removeObject($object);
	}
}

# Method: addToObject
#
#   	Add a member to a given object
#
# Parameters:
#
#   	object - object name
#   	ip - memeber's IPv4 address
#	mac - member's mac *optional*
#	description - description *optional*
sub addToObject  # (object, ip, mask, mac?, description?) 
{
	#action: add_to_object

	my ( $self, $object, $ip, $mask, $mac, $nname ) = @_;

	$self->dir_exists($object) or 
		throw EBox::Exceptions::DataNotFound('data' => __('Object'),
						     'value' => $object);

	checkIP($ip, "IP address");
	checkCIDR("$ip/$mask", "Network address");
	if ($mac){
		checkMAC($mac, "Hardware address");
	} else {
		$mac = "";
	}
	
	if ($self->alreadyInObject($ip, $mask)) {
		throw EBox::Exceptions::DataExists(
						'data' => __('network address'),
						'value' => "$ip/$mask");
	}

	my $id = $self->get_unique_id("m", $object);

	$self->set_string("$object/$id/nname", $nname);
	$self->set_string("$object/$id/ip", $ip);
	$self->set_string("$object/$id/mac", $mac);
	$self->set_int("$object/$id/mask", $mask);

	my $oname = $self->get_string("$object/description");
	logAdminDeferred('objects',"add_to_object","nname=$nname,ip=$ip,mask=$mask,mac=$mac,object=$oname");
	
	return 0;
}

# Method: removeFromObject 
#
#   	Removes a member from a given object
#
# Parameters:
#
#   	object - object name
#   	id - memeber's identifier
sub removeFromObject  # (object, id)
{
	#action: remove_from_object

	my ( $self, $object, $id )  = @_;

	$self->dir_exists($object) or 
		throw EBox::Exceptions::DataNotFound('data' => __('Object'),
						     'value' => $object);

	if($self->dir_exists("$object/$id")) {
		my $nname = $self->get_string("$object/$id/nname");
		my $oname = $self->get_string("$object/description");
		$self->delete_dir("$object/$id");
		logAdminDeferred('objects',"remove_from_object","nname=$nname,object=$oname");
		return 1;
	} else {
		return undef;
	}
}

# Method: alreadyInObject
#
#   	Checks if a member (i.e: its ip and mask) are already in some object	
#
# Parameters:
#
#   	ip - IPv4 address
#   	mask - network masl
#
# Returns:
#   
#   	booelan - true if it's already in other object, otherwise false
sub alreadyInObject # (ip, mask) 
{
	my ( $self, $iparg, $maskarg ) = @_;
	my $network = "$iparg/$maskarg";
	my @objs = $self->all_dirs("");

	foreach (@objs) {
		my @members = $self->all_dirs($_);
		foreach(@members) {
			my $member = $self->get_string("$_/ip") . "/" .
				     $self->get_int("$_/mask");
			my $m_ip = new Net::IP($member);
			my $n_ip = new Net::IP($network);
			if($m_ip->overlaps($n_ip)!=$IP_NO_OVERLAP){
				return 1;
			}
		}
	}
	return undef;
}

# Method: menu 
#
#       Overrides EBox::Module method.
#   
#
sub menu
{
	my ($self, $root) = @_;
	my $item = new EBox::Menu::Item('url' => 'Objects/Index',
					'text' => $self->title,
					'order' => 3);
	$root->add($item);
}

1;
