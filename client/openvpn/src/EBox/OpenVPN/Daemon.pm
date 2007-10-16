package EBox::OpenVPN::Daemon;
# package: Parent class for the distinct types of OpenVPN daemons
use strict;
use warnings;

use base qw(EBox::GConfModule::Partition EBox::NetworkObserver);

use File::Slurp;
use Error qw(:try);

sub new
{
    my ($class, $name, $daemonPrefix, $openvpnModule) = @_;
    
    my $confKeysBase = "$daemonPrefix/$name";
    if (!$openvpnModule->dir_exists($confKeysBase) ) {
	throw EBox::Exceptions::Internal("Tried to instantiate a daemon with a name not found in module configuration: $name");
    }


    my $self = $class->SUPER::new($confKeysBase, $openvpnModule);
    $self->{name} = $name;
      
    bless $self, $class;

    return $self;
}


sub _openvpnModule
{
    my ($self) = @_;
    return $self->fullModule();
}

#
# Method: init
#
#   Must be implimented by child to do initalisation stuff
#
#  Parametes:
#        $name        - the name of the daemon
#        @params      - initialization parameters, may be different for each daemon type
#
sub init
{
  throw EBox::Exceptions::NotImplemented();
}


#
# Method: name
#
#  Returns:
#    the name of the daemon
sub name
{
    my ($self) = @_;
    return $self->{name};
}


sub  ifaceNumber
{
  my ($self) = @_;
  return $self->getConfInt('iface_number');
}

#
# Method: iface
#
#   get the iface device name used for this daemon
#
# Returns:
#    - the device name
sub iface
{
  my ($self) = @_;

  my $ifaceType = $self->ifaceType();
  my $number    = $self->ifaceNumber();
  return "$ifaceType$number";
} 


#
# Method: ifaceType
#
#   get the iface device type used for this daemon
#
# Returns:
#    - the device type
sub ifaceType
{
  my ($self) = @_;
  return 'tap';
}

#
# Method: user
#
#    Return the user will be used to run the  daemon
#    after root drops privileges
#  Returns:
#    string - the user which will be run the daemon after the initialization
sub user
{
    my ($self) = @_;
    return $self->_openvpnModule->user();
}

#
# Method: group
#
#    Return the user will be used to run the  daemon
#    after root drops privileges
#
#  Returns:
#    string - the group which will be run the daemon after the initialization
sub group
{
    my ($self) = @_;
    return $self->_openvpnModule->group();
}

#
# Method: dh
#
#  Returns:
#    the diffie-hellman parameters file used by the daemon
sub dh
{
    my ($self) = @_;
    return $self->_openvpnModule->dh();
}


sub logFile
{
  my ($self) = @_;
  return $self->_logFile('');
}


sub statusLogFile
{
  my ($self) = @_;
  return $self->_logFile('status-');
}



sub _logFile
{
  my ($self, $prefix) = @_;
  my $logDir = $self->_openvpnModule->logDir();
  my $file = $logDir . "/$prefix"  . $self->name() . '.log';
  return $file;
}


# Method: setInternal
#
#  set the daemon's internal state
#
# Parameters:
#    internal - bool. 
sub setInternal
{
    my ($self, $internal) = @_;

   $self->setConfBool('internal', $internal);
}


# Method: internal
#
#   tell wether the client must been internal for users in the UI or nodaemon
#   is a internal daemon used and created by other EBox services
#
# Returns:
#  returns the client's internal state
sub internal
{
    my ($self) = @_;
    return $self->getConfBool('internal');
}


#
# Method: confFile
#
#   get the configuration file for this daemon
#
#  Parameters:
#     confDir - directory where the configuration file will be stored
#
# Returns:
#    - the path of the configuration file
sub confFile
{
    my ($self, $confDir) = @_;
    my $confFile = $self->name() . '.conf';
    my $confFilePath = defined $confDir ? "$confDir/$confFile" : $confFile;

    return $confFilePath;
}

#
# Method: writeConfFile
#
#   write the daemon's configuration file
#
#  Parameters:
#     confDir - directory where the configuration file will be stored
#
sub writeConfFile
{
    my ($self, $confDir) = @_;

    my $confFilePath   = $self->confFile($confDir);
    my $templatePath   = $self->confFileTemplate();
    my $templateParams = $self->confFileParams();

    push @{ $templateParams },
      (
       logFile       => $self->logFile(),
       statusLogFile => $self->statusLogFile(),
      );

    my $defaults     = {
	uid  => 0,
	gid  => 0,
	mode => '0400',
    };


    EBox::GConfModule->writeConfFile($confFilePath, $templatePath, $templateParams, $defaults);
}


#
# Method: confFileTemplate
#
#   Abstract method. Must return the configuration file template
#
# Returns:
#   the mason path of the configuration file template
sub confFileTemplate
{
  throw EBox::Exceptions::NotImplemented();
}


#
# Method: delete
#
#   This method is called to make the Daemon delete itself
#
#  Warning:
#    discard and do NOT use again the daemon object or any instance of it remaining after calling this method
sub delete
{
  my ($self) = @_;
  $self->isa (__PACKAGE__) or 
    throw EBox::Exceptions::Internal('This must be called as method');


  # notify openvpn of the removal soit can make the clean up in the next restart
  my $daemonClass = ref $self;
  my @daemonFiles = $self->daemonFiles;
  $self->_openvpnModule->notifyDaemonDeletion( $self->name, 
					       daemonClass => $daemonClass,
					       files => \@daemonFiles,
					     );

  # delete itself..
  my $daemonDir = $self->confKeysBase();
  $self->_openvpnModule->delete_dir($daemonDir);

  # invalidate object instance
  $_[0] = undef;
}

#
# Method: daemonFiles
#
#    Get a list with the files and directories generated by the daemon. Paths
#    must be absolute. Directories contents are not included
#
#    This is a default implementation, specifics daemon may want to override this to include their 
#      additional files
#
# Returns: 
#  a list with each path as string
sub daemonFiles
{
  my ($self) = @_;

  my $confDir  = $self->_openvpnModule->confDir();
  my $confFile = $self->confFile($confDir);

  return ($confFile);
}



#
# Method: confFileParams
#
#   Abstract method. Must return the configuration file template parameters
#
# Returns:
#   a reference to the parameter's list
sub confFileParams
{
  throw EBox::Exceptions::NotImplemented();
}

#
# Method: ripDaemon
#
#   Abstract method. Must return the configuration file template
#
# Returns:
#   undef if no ripDaemon is needed by the openvpn's daemon
#   if the ripDaemons is needed it must return a hash refrence with the
#   following keys:
#       iface        - the iface where the rip daemon needs to be active
#       redistribute - wether the daemon wants to redistribute routes or not
sub ripDaemon
{
  throw EBox::Exceptions::NotImplemented();
}

#
# Method: start
#
#  Start the daemon
sub start
{
  my ($self) = @_;

  if ($self->running) {
    EBox::error($self->name . ' openvpn daemon is already running. We will stop it');
    $self->stop;
  }

  my $command = $self->_rootCommandForStartDaemon();
  EBox::Sudo::root($command);
}

#
# Method: stop
#
#  Stop the daemon
sub stop
{
  my ($self) = @_;

  my $pid = $self->pid();
  defined $pid or return; # if there isn't pid the daemon isn't running

  EBox::Sudo::root("kill $pid");
  EBox::Sudo::root('rm ' . $self->_pidFile);
}



# XXX very fragile method!!! if the stop() methods request any attribute other
# than name it will break!!
sub stopDeletedDaemon
{
  my ($class, $name) = @_;

  $class->isa('EBox::OpenVPN::Daemon') or
    throw EBox::Exceptions::Internal("$class is not a openvpn's daemon class");

  my $daemon = { name => $name };
  bless $daemon, $class;

  $daemon->stop();

}


sub _rootCommandForStartDaemon
{
  my ($self) = @_;

  my $name    = $self->name;
  my $bin     = $self->_openvpnModule->openvpnBin();
  my $confDir = $self->_openvpnModule->confDir();
  my $confFilePath =   $self->confFile($confDir);
  my $pidFile = $self->_pidFile();

  return "$bin --daemon $name --writepid $pidFile --config $confFilePath";
}



sub _pidFile
{
  my ($self) = @_;
  return '/var/run/openvpn.' . $self->name . '.pid';

}


#
# Method: pid
#
# Returns:
#     the pid of the daemon or undef if isn't running
sub pid
{
  my ($self) = @_;
  try {
    my $pid = File::Slurp::read_file($self->_pidFile);
    return $pid;

  }
  otherwise {
  return undef;
  } 


}



#
# Method: running
#
# Returns:
#    bool - wether the daemon is running
sub running
{
  my ($self) = @_;
  my $pid = $self->pid;
  return defined $pid;
}





#
# Method: summary
#
#   Abstract method. May be implemented by any daemon which wants his summary section
#
# Returns:
#     the summary data as list; the first element will be the title of the summary 
#     section and the following pairs will be usd to build EBox::Summary::Value objects
sub summary
{
  my ($self) = @_;
  return ();
}

1;
