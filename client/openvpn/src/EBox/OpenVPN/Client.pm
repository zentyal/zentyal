package EBox::OpenVPN::Client;
# Description: Class for modelling each of the OpenVPN servers
use strict;
use warnings;

use base qw(EBox::OpenVPN::Daemon);

use EBox::Validate qw(checkPort checkAbsoluteFilePath checkHost);
use EBox::NetWrappers;
use EBox::Sudo;
use EBox::Gettext;
use Params::Validate qw(validate_pos SCALAR);
use File::Basename;
use Error qw(:try);

sub new
{
    my ($class, $name, $openvpnModule) = @_;
   
    my $prefix= 'client';

    my $self = $class->SUPER::new($name, $prefix, $openvpnModule);
      bless $self, $class;

    return $self;
}



# sub _setConfFilePath
# {
#   my ($self, $key, $path, $prettyName) = @_;

#   checkAbsoluteFilePath($path, __($prettyName));

#   if (!EBox::Sudo::fileTest('-f', $path)) {
#     throw EBox::Exceptions::External(__x('Inexistent file {path}', path => $path));
#   }

#   $self->setConfString($key, $path);
# }


sub setProto
{
    my ($self, $proto) = @_;

    if ($proto ne 'tcp'  and ($proto ne 'udp') ) {
	throw EBox::Exceptions::InvalidData(data => "client's protocol", value => $proto, advice => __("The protocol only may be tcp or udp.")  );
    }

    $self->setConfString('proto', $proto);
}

sub proto
{
    my ($self) = @_;
    return $self->getConfString('proto');
}


sub caCertificatePath
{
  my ($self) = @_;
  return $self->getConfString('caCertificatePath');
}

sub setCaCertificatePath
{
  my ($self, $path) = @_;
  my $prettyName = q{Certification Authority's certificate};
#  $self->_setConfFilePath('caCertificatePath', $path, $prettyName);
  $self->_setPrivateFile('caCertificatePath', $path, $prettyName);
}


sub certificatePath
{
  my ($self) = @_;
  return $self->getConfString('certificatePath');
}

sub setCertificatePath
{
  my ($self, $path) = @_;
  my $prettyName = q{client's certificate};
#  $self->_setConfFilePath('certificatePath', $path, $prettyName);
 $self->_setPrivateFile('certificatePath', $path, $prettyName);
}


sub certificateKey
{
  my ($self) = @_;
  return $self->getConfString('certificateKey');
}

sub setCertificateKey
{
  my ($self, $path) = @_;
  my $prettyName = q{certificate's key};
#  $self->_setConfFilePath('certificateKey', $path, $prettyName);
  $self->_setPrivateFile('certificateKey', $path, $prettyName);
}


sub privateDir
{
  my ($self) = @_;

  my $openVPNConfDir = $self->_openvpnModule->confDir();
  my $dir = $self->confFile($openVPNConfDir) . '.d';

  if (not EBox::Sudo::fileTest('-d', $dir)) {
    # create dir if it does not exist
    EBox::Sudo::root("mkdir --mode 0500  $dir");
    EBox::Sudo::root('chown '. $self->user . '.' . $self->group . " $dir");
  } 

  return $dir;
}

sub _setPrivateFile
{
  my ($self, $type, $path, $prettyName) = @_;

  # basic file check
  checkAbsoluteFilePath($path, __($prettyName));
  if (!EBox::Sudo::fileTest('-f', $path)) {
    throw EBox::Exceptions::External(__x('Inexistent file {path}', path => $path));
  }

  my $privateDir = $self->privateDir();
  
  my $newPath = "$privateDir/$type"; 

  try {
    EBox::Sudo::root("chmod 0400 $path");
    EBox::Sudo::root("chown 0.0 $path");
    EBox::Sudo::root("mv $path $newPath");
  }
  otherwise {
    EBox::Sudo::root("rm -f $newPath");
    EBox::Sudo::root("rm -f $path");
  };

  $self->setConfString($type, $newPath);


}




sub setService # (active)
{
  my ($self, $active) = @_;
  ($active and $self->service)   and return;
  (!$active and !$self->service) and return;

  if ($active) {
    if ($self->_availableIfaces() == 0) {
      throw EBox::Exceptions::External('Can not activate OpenVPN clients because there is not any netowrk interface available');
    }
  }

  $self->setConfBool('active', $active);
}


sub service
{
   my ($self) = @_;
   return $self->getConfBool('active');
}


sub confFileTemplate
{
  my ($self) = @_;
  return "openvpn/openvpn-client.conf.mas";
}

sub confFileParams
{
  my ($self) = @_;
  my @templateParams;

  push @templateParams, (dev => $self->iface);

  my @paramsNeeded = qw(caCertificatePath certificatePath certificateKey  user group proto );
  foreach my $param (@paramsNeeded) {
    my $accessor_r = $self->can($param);
    defined $accessor_r or die "Can not found accesoor for param $param";
    my $value = $accessor_r->($self);
    defined $value or next;
    push @templateParams, ($param => $value);
  }

  push @templateParams, (servers =>  $self->servers() );


  return \@templateParams;
}

sub servers
{
  my ($self) = @_;

  my @serverAddrs = @{ $self->allConfEntriesBase('servers') };
  my @servers = map {
    my $port = $self->getConfInt("servers/$_");
    [ $_ => $port ]
  } @serverAddrs;

  
  return \@servers;
}


sub setServers
{
  my ($self, $servers_r) = @_;
  my @servers = @{ $servers_r };
  (@servers > 0) or throw EBox::Exceptions::External(__('You must supply at least one server for the client'));


  foreach my $serverParams_r (@servers) {
    $self->_checkServer(@{  $serverParams_r  });
  }

  $self->deleteConfDir('servers');

  foreach my $serverParams_r (@servers) {
    my ($addr, $port) = @{  $serverParams_r  };
    $self->setConfInt("servers/$addr", $port);
  }
}


sub addServer
{
  my ($self, $addr, $port) = @_;

  $self->_checkServer($addr, $port);

  $self->setConfInt("servers/$addr", $port);
}



sub _checkServer
{
  my ($self, $addr, $port) = @_;

  checkHost($addr, __(q{Server's address}));
  checkPort($port, __(q{Server's port}));
}

sub removeServer
{
  my ($self, $addr) = @_;

  my $serverKey = "servers/$addr";

  if (!$self->confDirExists($serverKey)) {
    throw EBox::Exceptions::External("Requested server does not exist");
  }


  $self->unsetConf($serverKey);
}

sub init
{
    my ($self, %params) = @_;

    (exists $params{proto}) or throw EBox::Exceptions::External __("A IP protocol must be specified for the server");
    (exists $params{caCertificatePath}) or throw EBox::Exceptions::External __("A path to the CA certificate must be specified");
    (exists $params{certificatePath}) or throw EBox::Exceptions::External __("A path to the client certificate must be specified");
    (exists $params{certificateKey}) or throw EBox::Exceptions::External __("A path to the client certificate key must be specified");
    (exists $params{servers}) or throw EBox::Exceptions::External __("Servers msut be supplied yo yhe client");
    exists $params{service} or $params{service} = 0;


    my @attrs = qw(proto caCertificatePath certificatePath certificateKey servers service);
    foreach my $attr (@attrs)  {
	if (exists $params{$attr} ) {
	    my $mutator_r = $self->can("set\u$attr");
	    defined $mutator_r or die "Not mutator found for attribute $attr";
	    $mutator_r->($self, $params{$attr});
	}
    }
}


sub ripDaemon
{
  my ($self) = @_;
  
  my $iface = $self->iface();
  return { iface => $iface, redistribute => 1 };
}

sub ifaceMethodChanged
{
  my ($self, $iface, $oldmethod, $newmethod) = @_;
  if ($newmethod eq 'nonset') {
    return 1 if $self->_availableIfaces() == 1;
  }

  return undef;
}


sub vifaceDelete
{
  my ($self, $iface, $viface) = @_;

  return 1 if $self->_availableIfaces() == 1;
  return undef;
}


sub freeIface
{
  my ($self, $iface) = @_;
  my $ifaces = $self->_availableIfaces();
  if ($ifaces == 1) {
    $self->setService(0);
    EBox::warn("OpenVPN client " . $self->name . " was deactivated because there is not any network interfaces available");
  }
}

sub freeViface
{
  my ($self, $iface, $viface) = @_;
  $self->freeIface($viface); 
}


sub _availableIfaces
{
  my ($self) = @_;

  my $network = EBox::Global->modInstance('network');
  my @ifaces = @{ $network->ExternalIfaces };
  # XXX it should care of internal ifaces only until we close #391
  push @ifaces, @{ $network->InternalIfaces };

  return scalar @ifaces;
}


1;
