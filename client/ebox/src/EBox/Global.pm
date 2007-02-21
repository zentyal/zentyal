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

package EBox::Global;

use strict;
use warnings;

use base qw(EBox::GConfModule Apache::Singleton::Process);

use EBox;
use EBox::Validate qw( :all );
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::Internal;
use EBox::Exceptions::DataExists;
use Error qw(:try);
use EBox::Config;
use EBox::Gettext;
use Log::Log4perl;
use POSIX qw(setuid setgid setlocale LC_ALL);

use Digest::MD5;

#redefine inherited method to create own constructor
#for Singleton pattern
#sub _new_instance 
#{
	#my $class = shift;
	#my $self  = bless { }, $class;
	#$self->{'global'} = _create EBox::Global;
	#return $self;
#}

sub _new_instance 
{
	my $class = shift;
	my $self = $class->SUPER::_create(name => 'global', @_);
	bless($self, $class);
	$self->{'mod_instances'} = {};
	$self->{'mod_instances_hidden'} = {};
	return $self;
}

sub isReadOnly
{
	my $self = shift;
	return $self->{ro};
}



# Method: modExists 
#
#      Check if a module exists 
#
# Parameters:
#
#       module -  module's name to check
#
# Returns:
#
#   	boolean - True if the module exists, otherwise false
#
sub modExists # (module) 
{
	my ($self, $name) = @_;

	my $class = $self->get_string("modules/$name/class");
	return undef unless(defined($class));

	# Try to dectect if gconf is messing with us,
	# and a removed module is still there
	eval "use $class";
	return undef if ($@);

	return 1;
}

#
# Method: modIsChanged 
#
#      Check if the module config has changed
#
# Parameters:
#
#       module -  module's name to check
#
# Returns:
#
#   	boolean - True if the module config has changed , otherwise false
#

sub modIsChanged # (module) 
{
	my ($self, $name) = @_;
	defined($name) or return undef;
	($name ne 'global') or return undef;
	$self->modExists($name) or return undef;
	return $self->get_bool("modules/$name/changed");
}

#
# Method: modChange 
#
# 	Sets a module as changed
#
# Parameters:
#
#       module -  module's name to set
#
sub modChange # (module) 
{
	my ($self, $name) = @_;
	defined($name) or return;
	($name ne 'global') or return;
	$self->modExists($name) or return;
	$self->set_bool("modules/$name/changed", 1);
}

#
# Method: modRestarted
#
# 	Sets a module as restarted
#
# Parameters:
#
#       module -  module's name to set 
#
sub modRestarted # (module) 
{
	my ($self, $name) = @_;
	defined($name) or return;
	($name ne 'global') or return;
	$self->modExists($name) or return;
	$self->set_bool("modules/$name/changed", undef);
}


#
# Method: modNames
#
# 	Returns anrray containing all module names	
# 
# Returns:
#
#   	array ref - each element contains the module's name
#
sub modNames
{
	my $self = shift;
	my $log = EBox::logger();
	my $global = EBox::Global->instance();
	my @allmods = ();
	foreach (('sysinfo', 'network', 'firewall')) {
		if ($self->modExists($_)) {
			push(@allmods, $_);
		}
	}
	foreach my $mod (@{$self->all_dirs_base("modules")}) {
		next unless ($self->modExists($mod));
		next if (grep(/^$mod$/, @allmods));
		my $class = $global->get_string("modules/$mod/class");
		unless (defined($class) and ($class ne '')) {
			$global->delete_dir("modules/$mod");
			$log->info("Removing module $mod as it seems " .
				   "to be empty");
		} else {
			push(@allmods, $mod);				
		}
	}
	return \@allmods;
}

#
# Method: unsaved 
#
# 	Tells you if there is at least one unssaved module
# 
# Returns:
#
#   	array ref - each element contains the module's name
#
sub unsaved
{
	my $self = shift;
	my @names = @{$self->modNames};
	foreach (@names) {
		$self->modIsChanged($_) or next;
		return 1;
	}
	return undef;
}

#
# Method: revokeAllModules 
#
# 	Revoke the changes made in the configuration for all the  modules	
# 
sub revokeAllModules
{
	my $self = shift;
	my @names = @{$self->modNames};
	my $failed = "";

	foreach my $name (@names) {
		$self->modIsChanged($name) or next;
		my $mod = $self->modInstance($name);
		try {
			$mod->revokeConfig;
		} catch EBox::Exceptions::Internal with {
			$failed .= "$name ";
		};
	}
	if ($failed eq "") {
		return;
	}
	throw EBox::Exceptions::Internal("The following modules failed while ".
		"revoking their changes, their state is unknown: $failed");
}

#
# Method: saveAllModules
#
#      Save changes in all modules 		
#
sub saveAllModules
{
	my $self = shift;
	my @names = @{$self->modNames};
	my @mods = ();
	my $log = EBox::logger();
	my $msg = "Saving config and restarting services: ";
	my $failed = "";
	
	if ($self->modExists('firewall')) {
		push(@mods, 'firewall');
	}
	foreach my $modname (@names) {
		$self->modIsChanged($modname) or next;

		unless (grep(/^$modname$/, @mods)) {
			push(@mods, $modname);
			$msg .= "$modname ";
		}
		
		my @deps = @{$self->modRevDepends($modname)};
		foreach my $aux (@deps) {
			unless (grep(/^$aux$/, @mods)) {
				push(@mods, $aux);
				$msg .= "$aux ";
			}
		}
	}
	$log->info($msg);

	my $apache = 0;
	foreach my $name (@mods) {
		if ($name eq 'apache') {
			$apache = 1;
			next;
		}
		my $mod = $self->modInstance($name);
		try {
			$mod->save();
		} catch EBox::Exceptions::Internal with {
			$failed .= "$name ";
		};
	}

	# FIXME - tell the CGI to inform the user that apache is restarting
	if ($apache) {
		my $mod = $self->modInstance('apache');
		try {
			$mod->save();
		} catch EBox::Exceptions::Internal with {
			$failed .= "apache";
		};

	}
	
	if ($failed eq "") {
		return;
	}
	throw EBox::Exceptions::Internal("The following modules failed while ".
		"saving their changes, their state is unknown: $failed");
}

#
# Method: restartAllMdoules 
#
# 	Force a restart for all the modules	
#
sub restartAllModules
{
	my $self = shift;
	my @names = @{$self->modNames};
	my $log = EBox::logger();
	my $failed = "";
	$log->info("Restarting all modules");

	unless ($self->isReadOnly) {
		$self->{ro} = 1;
		$self->{'mod_instances'} = {};
	}

	foreach my $name (@names) {
		my $mod = $self->modInstance($name);
		try {
			$mod->restartService();
		} catch EBox::Exceptions::Internal with {
			$failed .= "$name ";
		};

	}
	if ($failed eq "") {
		return;
	}
	throw EBox::Exceptions::Internal("The following modules failed while ".
		"being restarted, their state is unknown: $failed");
}

#
# Method: stopAllModules 
#
# 	Stops all the modules
#
sub stopAllModules
{
	my $self = shift;
	my @names = @{$self->modNames};
	my $log = EBox::logger();
	my $failed = "";
	$log->info("Stopping all modules");

	unless ($self->isReadOnly) {
		$self->{ro} = 1;
		$self->{'mod_instances'} = {};
	}

	foreach my $name (@names) {
		my $mod = $self->modInstance($name);
		try {
			$mod->stopService();
		} catch EBox::Exceptions::Internal with {
			$failed .= "$name ";
		};

	}
	
	if ($failed eq "") {
		return;
	}
	throw EBox::Exceptions::Internal("The following modules failed while ".
		"stopping, their state is unknown: $failed");
}

#
# Method: getInstance
#
# 	Returns an instance of global class
#
# Parameters:
#
#   	readonly - If this value is passed, it will return a readonly instance
#
# Returns:
#   
#   	EBox::Global instance - It will be read-only if it's required
#
sub getInstance # (read_only?) 
{
	my $tmp = shift;
	if (!$tmp or ($tmp ne 'EBox::Global')) {
		throw EBox::Exceptions::Internal("Incorrect call to ".
		"EBox::Global->getInstance(), maybe it was called as an static".
		" function instead of a class method?");
	}
	my $ro = shift;
	my $global = EBox::Global->instance();
	if ($global->isReadOnly xor $ro) {
		$global->{ro} = $ro;
		# swap instance groups
		my $bak = $global->{mod_instances};
		$global->{mod_instances} = $global->{mod_instances_hidden};
		$global->{mod_instances_hidden} = $bak;
	}
	return $global;
}

# 
# Method: modInstances 
#
#	Returns an array ref with an instance of every module
#
# Returns:
#   
#   	array ref - the elments contains the instance of modules
#
sub modInstances
{
	my $self = EBox::Global->instance();
	my @names = @{$self->modNames};
	my @array = ();

	foreach my $name (@names) {
		my $mod = $self->modInstance($name);
		push(@array, $mod);
	}
	return \@array;
}

# 
# Method: modInstancesOfType 
#
#	Returns an array ref with an instance of every module that extends
#	a given classname
#
#   Paramters: 
#
#   	classname - the class base you are interested in 
#
# Returns:
#   
#   	array ref - the elments contains the instance of the modules
#   		    extending the classname
#
sub modInstancesOfType # (classname)
{
	shift;
	my $classname = shift;
	my $self = EBox::Global->instance();
	my @names = @{$self->modNames};
	my @array = ();

	foreach my $name (@names) {
		my $mod = $self->modInstance($name);
		if ($mod->isa($classname)) {
			push(@array, $mod);
		}
	}
	return \@array;
}


# 
# Method: modInstance 
#
# 	Builds and instance of a module. Can be called as a class method or as an
# 	object method.
#
#   Paramters: 
#
#   	modulename - module name
#
# Returns:
#   
#   	If everything goes ok:
#
#   	EBox::Module - A instance of the requested module
#
#   	Otherwise
#
#   	undef
sub modInstance # (module) 
{
	my $self = shift;
	my $name = shift;
	if (!$self) {
		throw EBox::Exceptions::Internal("Incorrect call to ".
		"EBox::Global modInstance(), maybe it was called as an static".
		" function instead of an instance method?");
	}
	my $global = undef;
	if ($self eq "EBox::Global") {
		$global = EBox::Global->getInstance();
	} elsif ($self->isa("EBox::Global")) {
		$global = $self;
	} else {
		throw EBox::Exceptions::Internal("Incorrect call to ".
		"EBox::Global modInstance(), the first parameter is not a class".
		" nor an instance.");
	}

	if ($name eq 'global') {
		return $global;
	}
	my $modInstance  = $global->{'mod_instances'}->{$name};
	if (defined($modInstance)) {
		if (not ($global->isReadOnly() xor $modInstance->{'ro'})) {
			return $modInstance;
		}
	}
	
	$global->modExists($name) or return undef;
	my $classname = $global->get_string("modules/$name/class");
	unless ($classname) {
		throw EBox::Exceptions::Internal("Module '$name' ".
				"declared, but it has no classname.");
	}
	eval "use $classname";
	if ($@) {
		throw EBox::Exceptions::Internal("Error loading ".
						 "class: $classname");
	}
	if ($global->isReadOnly()) {
		$global->{'mod_instances'}->{$name} =
					$classname->_create(ro => 1);
	} else {
		$global->{'mod_instances'}->{$name} =
						$classname->_create;
	}
	return $global->{'mod_instances'}->{$name};

}


# 
# Method: logger 
#
# 	Initialises Log4perl if necessary, returns the logger for the i
# 	caller package
#
#   Paramters: 
#
#   	caller - 
#
# Returns:
#   
#   	If everything goes ok:
#
#   	EBox::Module - A instance of the requested module
#
#   	Otherwise
#
#   	undef
sub logger # (caller?) 
{
	shift;
	EBox::deprecated();
	return EBox::logger(shift);
}

# 
# Method: modDepends 
#
#	Returns an array with the names of the modules that the requested
#	module deed on
#
#   Paramters: 
#
#   	module - requested module
#
# Returns:
#   
#	undef -  if the module does not exist
#	array ref - holding the names of the modules that the requested module
sub modDepends # (module) 
{
	my ($self, $name) = @_;
	$self->modExists($name) or return undef;
	my $list = $self->get_list("modules/$name/depends");
	if ($list) {
		return $list;
	} else {
		return [];
	}
}

# 
# Method: modRevDepends 
#
#	Returns an array with the names of the modules which depend on a given
#	module
#
#   Paramters: 
#
#   	module - requested module
#
# Returns:
#   
# 	undef -  if the module does not exist
#	array ref - holding the names of the modules which depend on the 
#	requested module
#
sub modRevDepends # (module) 
{
	my ($self, $name) = @_;
	$self->modExists($name) or return undef;
	my @revdeps = ();
	my @mods = @{$self->modNames};
	foreach my $mod (@mods) {
		my @deps = @{$self->modDepends($mod)};
		foreach my $dep (@deps) {
			defined($dep) or next;
			if ($name eq $dep) {
				push(@revdeps, $mod);
				last;
			}
		}
	}
	return \@revdeps;
}

# 
# Method: setLocale 
#
#	*deprecated*
#
sub setLocale # (locale) 
{
	shift;
	EBox::deprecated();
	EBox::setLocale(shift);
}

# 
# Method: setLocale 
#
#	*deprecated*
#
sub locale 
{
	EBox::deprecated();
	return EBox::locale();
}

# 
# Method: setLocale 
#
#	*deprecated*
#
sub init
{
	EBox::deprecated();
	EBox::init();
}


1;
