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

package EBox::Module;

use strict;
use warnings;

use File::Copy;
use Proc::ProcessTable;
use EBox;
use EBox::Config;
use EBox::Global;
use EBox::Sudo qw( :all );
use EBox::Exceptions::Internal;
use EBox::Exceptions::Lock;
use EBox::Gettext;
use HTML::Mason;
use File::Temp qw(tempfile);
use Fcntl qw(:flock);
use Error qw(:try);


# Method: _create 
#
#   	Base constructor for a module
#
# Parameters:
#
#       name - module's name
#	domain - locale domain
#
# Returns:
#
#       EBox::Module instance
#
# Exceptions:
#
#      	Internal - If no name is provided
sub _create # (name, domain?)
{
	my $class = shift;
	my %opts = @_;
	my $self = {};
	$self->{name} = delete $opts{name};
	$self->{domain} = delete $opts{domain};
	unless (defined($self->{name})) {
		use Devel::StackTrace;
		my $trace = Devel::StackTrace->new;
		print STDERR $trace->as_string;
		throw EBox::Exceptions::Internal(
			"No name provided on Module creation");
	}
	bless($self, $class);
	return $self;
}

# Method: revokeConfig 
#
#   	Base method to revoke config. It should be overriden by subclasses 
#   	as needed
#
sub revokeConfig
{
	# default empty implementation. It should be overriden by subclasses as
	# needed
}

# Method: _saveConfig 
#
#   	Base method to save configuration. It should be overriden 
#	by subclasses as needed
#
sub _saveConfig
{
	# default empty implementation. It should be overriden by subclasses as
	# needed
}

# Method: _regenConfig
#
#   	Base method to regenertate  configuration. It should be overriden 
#	by subclasses as needed
#
sub _regenConfig 
{
	# default empty implementation. It should be overriden by subclasses as
	# needed
}

# Method: _restartService
#
#	This method will try to restart the module's service by means of calling
#	_regenConfig
#
sub restartService
{
	my $self = shift;

	$self->_lock();
	my $global = EBox::Global->getInstance();
	my $log = EBox::logger;
	$log->info("Restarting service for module: " . $self->name);
	try {
		$self->_regenConfig('restart' => 1);
	} finally {
		$self->_unlock();
	};
}

# Method: save
#
#	Sets a module as saved. This implies a call to _regenConfig and set 
#	the module as saved and unlock it.
#
sub save
{
	my $self = shift;

	$self->_lock();
	my $global = EBox::Global->getInstance();
	my $log = EBox::logger;
	$log->info("Restarting service for module: " . $self->name);
	$self->_saveConfig();
	try {
		$self->_regenConfig('save' => '1');
	} finally {
		$global->modRestarted($self->name);
		$self->_unlock();
	};
}

sub _unlock
{
	my $self = shift;
	flock(LOCKFILE, LOCK_UN);
	close(LOCKFILE);
}

sub _lock
{
	my $self = shift;
	my $file = EBox::Config::tmp . "/" . $self->name . ".lock";
	open(LOCKFILE, ">$file") or
		throw EBox::Exceptions::Internal("Cannot open lockfile: $file");
	flock(LOCKFILE, LOCK_EX | LOCK_NB) or
		throw EBox::Exceptions::Lock($self);
}

# Method: _stopService
#
#	This method will try to stop the module's service. It should be 
#	overriden by subclasses as needed
#
sub _stopService
{
	# default empty implementation. It should be overriden by subclasses as
	# needed
}

# Method: stopService
#
#	This is the external interface to call the implementation which lies in
#	_stopService in subclassess
#
#
sub stopService
{
	my $self = shift;

	$self->_lock();
	try {
		$self->_stopService();
	} finally {
		$self->_unlock();
	};
}

sub makeBackup # (dir) 
{
	my ($self, $dir) = @_;
	# default empty implementation
}

sub restoreBackup # (dir) 
{
	my ($self, $dir) = @_;
	# default empty implementation
}

#
# Method: name 
#
#	Returns the module name of the current module instance   
#
# Returns:
#
#      	strings - name 
#
sub name
{
	my $self = shift;
	return $self->{name};
}

#
# Method: setName 
#
#	Sets the module name for the current module instance
#
# Parameters:
#
#      	name - module name
#
sub setName # (name) 
{
	my $self = shift;
	my $name = shift;
	$self->{name} = $name;
}

#
# Method: menu 
#
#	This method returns the menu for the module. What it returns 
#	it will be added up to the interface's menu. It should be 
#	overriden by subclasses as needed
sub menu
{
	# default empty implementation
	return undef;
}

#
# Method: summary 
#
#	This method returns the summary for the module. What it returns it will 
#	be added up to the common summry page. It should be overriden by 
#	subclasses as needed
#
sub summary
{
	# default empty implementation
	return undef;
}

#
# Method: statusSummary 
#
#	This method returns the summary for the module. What it returns it will 
#	be added up to the common summry page. It should be overriden by 
#	subclasses as needed
#
sub statusSummary
{
	# default empty implementation
	return undef;
}

#
# Method: domain 
#
#	Returns the locale domain for the current module instance 
#
# Returns:
#
#      	strings - locale domain
#
sub domain
{
	my $self = shift;

	if (defined $self->{domain}){
		return $self->{domain};
	} else {
		return 'ebox';
	}
}

#
# Method: rootCommands 
#
#	Returns the sudo commands the module will need to execute. 
#	For security reasons paths and arguments should be as much accurate 
#	as possible.
#
# Returns:
#
#      	array ref - each element contains a command 
#
sub rootCommands 
{
	my @array = ();
	return @array;
}

#
# Method: pidRunning 
#
#	Checks if a PID is running
#
# Parameters:
#	
#	pid - PID number 
#
# Returns:
#
#	boolean - True if it's running , otherise false
sub pidRunning
{
	my ($self, $pid) = @_;
	my $t = new Proc::ProcessTable;
	foreach my $proc (@{$t->table}) {
		($pid eq $proc->pid) and return 1;
	}
	return undef;
}

#
# Method: pidFileRunning 
#
#	Given a file holding a PID, it gathers it and checks if it's running
#
# Parameters:
#	
#	file - file name
#
# Returns:
#
#	boolean - True if it's running , otherise false
#
sub pidFileRunning
{
	my ($self, $file) = @_;
	(-f $file) or return undef;
	open(PIDF, $file) or return undef;
	my $pid = <PIDF>;
	chomp($pid);
	close(PIDF);
	defined($pid) or return undef;
	($pid ne "") or return undef;
	return $self->pidRunning($pid);
}

#
# Method: writeConfFile 
#
#	It executes a given mason component with the passed parameters over 
#	a file. It becomes handy to set configuration files for services. 
#	Also, its file 	permissions will be kept.
#      XXX : the correct behaviour will be to throw exceptions if file will not be stated and no defualts provided. Instead will provide hardcored defaults because we need to be backwards-compatible
#
# Parameters:
#	
#	file - file name which will be overwritten with the output of 
#	the execution
#	component - mason component
#	paramas - parameters for the mason component
#
# Returns:
#
#	boolean - True if it's running , otherise false
#
sub writeConfFile # (file, comp, params)
{
	my ($self, $file, $compname, $params, $defaults) = @_;
	my ($fh,$tmpfile) = tempfile(DIR => EBox::Config::tmp);
	unless($fh) {
		throw EBox::Exceptions::Internal(
			"Could not create temp file in " . EBox::Config::tmp);
	}
	my $interp = HTML::Mason::Interp->new(comp_root => EBox::Config::stubs,
		out_method => sub { $fh->print($_[0]) });
	my $comp = $interp->make_component(comp_file =>
		EBox::Config::stubs . "/" . $compname);
	$interp->exec($comp, @{$params});
	$fh->close();

	my $mode;
	my $uid;
	my $gid;
	if(my $st = stat($file)) {
	    $mode= sprintf("%04o", $st->mode & 07777); 
	    $uid = $st->uid;
	    $gid = $st->gid;

	} else {
	    defined $defaults or $defaults = {};
	    $mode = exists $defaults->{mode} ?  $defaults->{mode}  : '0755';
	    $uid  = exists $defaults->{uid}  ?  $defaults->{uid}   : 0;
	    $gid  = exists $defaults->{gid}  ?  $defaults->{gid}   : 0;
	}

	root("/bin/mv $tmpfile  $file");
	root("/bin/chmod $mode $file");
	root("/bin/chown $uid.$gid $file");
}


sub rootCommandsForWriteConfFile # (file)
{
	my ($self, $file) = @_;
	my @commands = ();
	push (@commands, "/bin/mv " . EBox::Config::tmp . "* " . $file);
	push (@commands, "/bin/chmod * " . $file);
	push (@commands, "/bin/chown * " . $file);
	push (@commands, rootCommandForStat($file));

	return @commands;
}

#sub logs
#{
#	my @array = ();
#	return \@array;
#}

1;
