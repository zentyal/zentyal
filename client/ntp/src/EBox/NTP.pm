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

package EBox::NTP;

use strict;
use warnings;

use base qw(EBox::GConfModule EBox::ServiceModule::ServiceInterface);

use EBox::Objects;
use EBox::Gettext;
use EBox::Service;
use EBox::Menu::Item;
use EBox::Menu::Folder;
use Error qw(:try);
use EBox::Validate qw( :all );
use EBox::Sudo qw( :all );
use EBox;

use constant NTPCONFFILE => "/etc/ntp.conf";

sub _create 
{
	my $class = shift;
	my $self = $class->SUPER::_create(name => 'ntp', printableName => 'ntp',
						domain => 'ebox-ntp',
						@_);
	bless($self, $class);
	return $self;
}

sub isRunning
{
	my ($self) = @_;
	# return undef if service is not enabled
	# otherwise it might be misleading if time synchronization is set
	($self->service) or return undef;
	return EBox::Service::running('ebox.ntpd');
}

sub domain
{
	return 'ebox-ntp';
}

# Method: actions
#
# 	Override EBox::ServiceModule::ServiceInterface::actions
#
sub actions
{
	return [ 
	{
		'action' => __('Remove ntp init script links'),
		'reason' => __('eBox will take care of starting and stopping ' .
						'the services.'),
		'module' => 'ntp'
	}
    ];
}


# Method: usedFiles
#
#	Override EBox::ServiceModule::ServiceInterface::usedFiles
#
sub usedFiles
{
	return [
		{
		 'file' => NTPCONFFILE,
		 'module' => 'ntp',
 	 	 'reason' => 'ntp configuration file'
		}
	       ];
}

# Method: enableActions 
#
# 	Override EBox::ServiceModule::ServiceInterface::enableActions
#
sub enableActions
{
    root(EBox::Config::share() . '/ebox-ntp/ebox-ntp-enable');
}

# Method: serviceModuleName 
#
# 	Override EBox::ServiceModule::ServiceInterface::serviceModuleName
#
sub serviceModuleName
{
    return 'ntp';
}

sub _doDaemon
{
   my $self = shift;
	my $logger = EBox::logger();

  if (($self->service or $self->synchronized) and $self->isRunning) {
      EBox::Service::manage('ebox.ntpd','stop');
		sleep 2;
		if ($self->synchronized) {
			my $exserver = $self->get_string('server1');
			try { 
				root("/usr/sbin/ntpdate $exserver");
			} catch EBox::Exceptions::Internal with {
				$logger->info("Couldn't execute ntpdata");
			};
		}
      EBox::Service::manage('ebox.ntpd','start');
   } elsif ($self->service or $self->synchronized) {    
		if ($self->synchronized) {
			my $exserver = $self->get_string('server1');
			try { 
				root("/usr/sbin/ntpdate $exserver");
			} catch EBox::Exceptions::Internal with {
				$logger->info("Error no se pudo lanzar ntpdate");
			};
		}
      EBox::Service::manage('ebox.ntpd','start');
   } elsif ($self->isRunning) {
      		EBox::Service::manage('ebox.ntpd','stop');
		if ($self->synchronized) {
      			EBox::Service::manage('ebox.ntpd','start');
		}
   }
}

sub _stopService
{
      	EBox::Service::manage('ebox.ntpd','stop');
}

sub _configureFirewall($){
	my $self = shift;
	my $fw = EBox::Global->modInstance('firewall');
	
	if ($self->synchronized) {
		$fw->addOutputRule('udp', 123);
	} else {
		$fw->removeOutputRule('udp', 123);
	}
	
}

# Method: setService 
#
#       Enable/Disable the ntp service 
#
# Parameters:
#
#       enabled - boolean. True enable, undef disable
#       
sub setService # (active)
{
	my ($self, $active) = @_;
	($active and $self->service) and return;
	(!$active and !$self->service) and return;
	$self->enableService($active);
	$self->_configureFirewall;
}

# Method: service               
#               
#       Returns if the ntp service is enabled  
#                       
# Returns:      
#       
#       boolean - true if enabled, otherwise undef
sub service
{
   my $self = shift;

	return $self->isEnabled();
}

# Method: setSynchronized
#
#      Enable/disable the synchronization service to external ntp servers
#
# Parameters:
#
#       enabled - boolean. True enable, undef disable
#
sub setSynchronized # (synchro)
{
	my $self = shift;
	my $synchronized = shift;

	($synchronized and $self->synchronized) and return;
	(!$synchronized and !$self->synchronized) and return;
	$self->set_bool('synchronized', $synchronized);
	$self->_configureFirewall;
}

# Method: synchronized
#
#      Enable/disable the synchronization service to external ntp servers
#
# Returns:
#
#      boolean -  True enable, undef disable
#
sub synchronized
{
	my $self = shift;
	return $self->get_bool('synchronized');
}

# Method: setServers
#
#	Sets the external ntp servers to synchronize from
#
# Parameters:
#
#	server1 - primary server
#	server2 - secondary server
#	server3 - tertiary server
#
sub setServers # (server1, server2, server3)
{
        my ($self, $s1, $s2, $s3) = @_;

	if (!(defined $s1 and ($s1 ne''))) {
	  throw EBox::Exceptions::DataMissing (data => __('Primary server'));
	}
	_checkServer($s1, __('primary server'));

	
	if (defined $s2 and ($s2 ne '')) {
	  if ($s2 eq $s1) {
	    throw EBox::Exceptions::External (__("Primary and secondary server must be different"))
	  }

	  _checkServer($s2, __('secondary server'));
	}
	else {
	  if (defined($s3) and ($s3 ne "")) {
	    throw EBox::Exceptions::DataMissing (data => __('Secondary server'));
	  }

	  $s2 = '';
	}


	if (defined $s3 and ($s3 ne '')) {
	  if ($s3 eq $s1) {
	    throw EBox::Exceptions::External (__("Primary and tertiary server must be different"))
	  }
	  if ($s3 eq $s2) {
	    throw EBox::Exceptions::External (__("Primary and secondary server must be different"))
	  }

	  _checkServer($s3, __('tertiary server'));	  
	}
	else {
	  $s3 = '';
	}

	$self->set_string('server1', $s1);
	$self->set_string('server2', $s2);
	$self->set_string('server3', $s3);
}

sub _checkServer
{
  my ($server, $serverName) = @_;

  if ($server =~ m/^[.0-9]*$/) {  # seems a IP address
    checkIP($server, __x('{name} IP address', name => $serverName));
  }
  else {
    checkDomainName($server, __x('{name} host name', name => $serverName));
  }
  
}


# Method: servers 
#
#	Returns the list of external ntp servers
#
# Returns:
#
#	array - holding the ntp servers
sub servers {
	my $self = shift;
	my @servers;
	
	@servers = grep { defined $_ and ($_ ne '')   } ($self->get_string('server1'),	$self->get_string('server2'),	$self->get_string('server3'));

	return @servers;
}

# Method: _regenConfig
#
#       Overrides base method. It regenertates the configuration
#       for squid and dansguardian.
#
sub _regenConfig
{
	my $self = shift;

	$self->_setNTPConf;
	$self->_doDaemon();
}

sub _setNTPConf
{
	my $self = shift;
	my @array = ();
	my @servers = $self->servers;
	my $synch = 'no';
	my $active = 'no';
	
	($self->synchronized) and $synch = 'yes';
	($self->service) and $active = 'yes';

	push(@array, 'active'	=> $active);
	push(@array, 'synchronized'  => $synch);
	push(@array, 'servers'  => \@servers);

	$self->writeConfFile(NTPCONFFILE, "ntp/ntp.conf.mas", \@array);
}

sub _restartAllServices
{
	my $self = shift;
	my $global = EBox::Global->getInstance();
	my @names = grep(!/^network$/, @{$global->modNames});
	@names = grep(!/^firewall$/, @names);
	my $log = EBox::logger();
	my $failed = "";
	$log->info("Restarting all modules");
	foreach my $name (@names) {
		my $mod = $global->modInstance($name);
		try {
			$mod->restartService();
		} catch EBox::Exceptions::Internal with {
			$failed .= "$name ";
		};
	}
	if ($failed ne "") {
		throw EBox::Exceptions::Internal("The following modules ".
			"failed while being restarted, their state is ".
			"unknown: $failed");
	}
	
	$log->info("Restarting system logs");
	try {
		root("/etc/init.d/sysklogd restart");
		root("/etc/init.d/klogd restart");
		root("/etc/init.d/cron restart");
	} catch EBox::Exceptions::Internal with {
	};
	
}

# Method: setNewDate
#
#	Sets the system date
#
# Parameters:
#
#	day - 
#	month -
#	year -
#	hour -
#	minute -
#	second -
sub setNewDate # (day, month, year, hour, minute, second)
{
	my $self = shift;
	my $day = shift;
	my $month = shift;
	my $year =  shift;
	my $hour = shift;
	my $minute = shift;
	my $second = shift;

	my $newdate = "$year-$month-$day $hour:$minute:$second";
	my $command = "/bin/date --set \"$newdate\"";
	root($command);

	my $global = EBox::Global->getInstance(1);
	$self->_restartAllServices;
}

# Method: setNewTimeZone
#
#	Sets the system's time zone 
#
# Parameters:
#
#	continent - 
#	country -
sub setNewTimeZone # (continent, country))
{
	my $self = shift;
	my $continent = shift;
	my $country = shift;

	my $command = "ln -s /usr/share/zoneinfo/$continent/$country /etc/localtime";
	$self->set_string('continent', $continent);
	$self->set_string('country', $country);
	root("rm /etc/localtime");
	root($command);
#	my $global = EBox::Global->getInstance(1);
#	$self->_restartAllServices;
}	

# Method: menu 
#
#       Overrides EBox::Module method.
#
sub menu
{
        my ($self, $root) = @_;
        my $folder = new EBox::Menu::Folder('name' => 'EBox',
                                            'text' => __('System'));

        $folder->add(new EBox::Menu::Item('url' => 'NTP/Datetime',
                                          'text' => __('Date/time')));

        $folder->add(new EBox::Menu::Item('url' => 'NTP/Timezone',
                                          'text' => __('Time zone')));
        $root->add($folder);
}


1;
