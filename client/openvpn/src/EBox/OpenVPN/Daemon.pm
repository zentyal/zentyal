package EBox::OpenVPN::Daemon;
# package: Parent class for the distinct types of OpenVPN daemons
use strict;
use warnings;

use base qw(EBox::OpenVPN::ModulePartition);


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


1;
