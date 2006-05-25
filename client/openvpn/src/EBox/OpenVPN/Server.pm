package EBox::OpenVPN::Server;
# Description: Class for modelling each of the OpenVPN servers
use strict;
use warnings;

use EBox::Validate qw(checkPort checkAbsoluteFilePath checkIP);
use EBox::NetWrappers;
use Perl6::Junction qw(all);

sub new
{
    my ($class, $name, $confModule) = @_;
    
    my $confKeysBase = "servers/$name";
    if (!$confModule->dir_exists($confKeysBase) ) {
	throw EBox::Exceptions::Internal("Tried to instantiate a server with a name not found in module configuration: $name");
    }

    my $self = {  confModule => $confModule, confKeysBase => $confKeysBase   };
    bless $self, $class;

    return $self;
}

sub _confKey
{
    my ($self, $key) = @_;
    return $self->{confKeysBase} . "/$key";
}

sub _confModule
{
    my ($self) = @_;
    return $self->{confModule};
}

sub _getConfString
{
    my ($self, $key) = @_;
    $key = $self->_confKey($key);
    $self->_confModule->get_string($key);
}

sub _setConfString
{
    my ($self, $key, $value) = @_;
    $key = $self->_confKey($key);
    $self->_confModule->set_string($key, $value);
}

sub _setConfPath
{
    my ($self, $key, $value) = @_;
    checkAbsoluteFilePath($value);
    $self->_setConfString($key, $value);
}


sub _getConfInt
{
    my ($self, $key) = @_;
    $key = $self->_confKey($key);
    $self->_confModule->get_int($key);
}

sub _setConfInt
{
    my ($self, $key, $value) = @_;
    $key = $self->_confKey($key);
    $self->_confModule->set_int($key, $value);
}


sub _getConfBool
{
    my ($self, $key) = @_;
    $key = _confKey($key);
    $self->_confModule->get_bool($key);
}

sub _setConfBool
{
    my ($self, $key, $value) = @_;
    $key = _confKey($key);
    $self->_confModule->set_bool($key, $value);
}


sub setProto
{
    my ($self, $proto) = @_;
    if ($proto ne 'tcp'  and ($proto ne 'udp') ) {
	throw EBox::Exceptions::InvalidData(data => "server's protocol", value => $proto, advice => __("The protocol only may be tcp or udp.")  );
    }

    $self->_setConfString('proto', $proto);
}

sub proto
{
    my ($self) = @_;
    return $self->_getConfString('proto');
}


sub setPort
{
  my ($self, $port) = @_;

  checkPort($port, "server's port");
  if ( $port < 1024 ) {
      throw EBox::Exceptions::InvalidData(data => "server's port", value => $port, advice => __("The port must be a non-privileged port")  );
    }

    $self->_setConfInt('port', $port);
}

sub port
{
    my ($self) = @_;
    return $self->_getConfInt('port');
}

sub setLocal
{
  my ($self, $localIP) = @_;

  checkIP($localIP, "Local IP address that will be listenned by server");

  my @localAddresses = EBox::NetWrappers::list_local_addresses();
  if ($localIP ne all(@localAddresses)) {
 throw EBox::Exceptions::InvalidData(data => "Local IP address that will be listenned by server", value => $localIP, advice => __("This address does not correspond to any local address")  );
  }

  $self->_setConfString('local', $localIP);
}

sub local
{
    my ($self) = @_;
    return $self->_getConfInt('local');
}






1;
