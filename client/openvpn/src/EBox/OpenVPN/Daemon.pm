package EBox::OpenVPN::Daemon;
# package: Parent class for the distinct types of OpenVPN daemons
use strict;
use warnings;

use base qw(EBox::OpenVPN::ModulePartition EBox::NetworkObserver);


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


sub iface
{
  my ($self) = @_;

  my $ifaceType = 'tap';
  my $number    = $self->ifaceNumber();
  return "$ifaceType$number";
} 


sub user
{
    my ($self) = @_;
    return $self->_openvpnModule->user();
}


sub group
{
    my ($self) = @_;
    return $self->_openvpnModule->group();
}

sub dh
{
    my ($self) = @_;
    return $self->_openvpnModule->dh();
}

sub confFile
{
    my ($self, $confDir) = @_;
    my $confFile = $self->name() . '.conf';
    my $confFilePath = defined $confDir ? "$confDir/$confFile" : $confFile;

    return $confFilePath;
}

sub writeConfFile
{
    my ($self, $confDir) = @_;

    my $confFilePath   = $self->confFile($confDir);
    my $templatePath   = $self->confFileTemplate();
    my $templateParams = $self->confFileParams();

    my $defaults     = {
	uid  => $self->user,
	gid  => $self->group,
	mode => '0400',
    };


    EBox::GConfModule->writeConfFile($confFilePath, $templatePath, $templateParams, $defaults);
}


sub confFileTemplate
{
  throw EBox::Exceptions::NotImplemented();
}

# must return a array ref
sub confFileParams
{
  throw EBox::Exceptions::NotImplemented();
}

# XXX RIP/quagga stuff
sub ripDaemon
{
  throw EBox::Exceptions::NotImplemented();
}




sub running
{
    my ($self) = @_;
    my $bin = $self->_openvpnModule->openvpnBin;
    my $name = $self->name;

    system "/usr/bin/pgrep -f $bin.*$name";

    return ($? == 0) ? 1 : 0;
}


1;
