package EBox::OpenVPN::Server::ClientBundleGenerator;
# package:
use strict;
use warnings;

use EBox::Global;
use EBox::Config;
use EBox::FileSystem;
use English qw(-no_match_vars);
use File::Basename;
use Error qw(:try);
use Params::Validate qw(validate_pos);


sub _generateClientConf
{
  my ($class, $server, $file, $certificatesPath_r) = @_;

  my @confParams;
  
  push @confParams, (
		     dev   => $server->ifaceType(),
		     proto => $server->proto() ,
		    );
  
  my @servers;
  my $port      = $server->port();
  my $localAddr = $server->localAddress();
  if ($localAddr) {
    @servers = ([$localAddr, $port]);
  }
  else {
    my $network = EBox::Global->modInstance('network');
    my @addrs = map { $network->ifaceAddress($_) } @{ $network->ExternalIfaces( )};
    @addrs  or throw Box::Exceptions::External(__(q{Can't get address for this server: no external interfaces present}));

    @servers  = map { [$_, $port] } @addrs;
  }

  @servers or throw EBox::Exceptions::External(__(q{Can't get address for this server}));
  push @confParams, (servers => \@servers);

  my %certificates = %{ $certificatesPath_r };
  # transform al lpaths in relative paths
  foreach my $path (values %certificates) {
    $path = basename $path;  
  }
  push @confParams, %certificates;

  push @confParams, (tlsRemote => $server->certificate);

  push @confParams, $class->confFileExtraParameters();

  my ($egid) = split '\s+', $EGID;
  my $fileOptions     = {
	uid  => $EUID, 
	gid  => $egid, 
	mode => '0666',
    };

  EBox::GConfModule->writeConfFile($file, 'openvpn/noebox-openvpn-client.conf.mas', \@confParams, $fileOptions);
}

sub confFileExtraParameters
{
  return ();
}


sub _copyCertFilesToDir
{
  my ($class, $certificatesPath_r, $dir) = @_;

  foreach my $file (values %{ $certificatesPath_r }) {
    EBox::Sudo::root("cp $file $dir/");
  }
}

# XXX subst $server->_checkCertificate with a public thing
sub _clientCertificatesPaths
{
  my ($class, $server, $clientCertificate) = @_;
  my %certificates;

  # CA certificate
  $certificates{ca}= $server->caCertificatePath;
    
  # client certificate
  my $certificate_r   = $server->_checkCertificate($clientCertificate);
  $certificates{cert} = $certificate_r->{path};

  # client private key
  my $ca = EBox::Global->modInstance('ca');
  my $keys = $ca->getKeys($clientCertificate);
  $certificates{key} = $keys->{privateKey};

  return \%certificates;
}

#  remember to call the bundle's destructor as soon as possible
#  XXX may be change the bundle so it call its destructor automatically when it falls out of scope
sub clientBundle
{
  my ($class, $server, $clientCertificate) = @_;
  validate_pos(@_, 1, 1, 1);
  
  ($clientCertificate ne $server->certificate()) or throw EBox::Exceptions::External(__(q{The client certificate can't be the same than the server}));
  
  my $bundle;
  my $tmpDir = EBox::Config::tmp() . '/' . $server->name . '-client.tmp';
  system "rm -rf $tmpDir";
  EBox::FileSystem::makePrivateDir($tmpDir);

  try {
    my $certificatesPath_r = $class->_clientCertificatesPaths($server, $clientCertificate);

    # client configuration file
    my $confFile = $class->_confFile($server, $tmpDir);
    $class->_generateClientConf($server, $confFile, $certificatesPath_r);

    $class->_copyCertFilesToDir($certificatesPath_r, $tmpDir);
    
    # create bundle in zip format
    $bundle  =  $class->_createBundle($server,  $tmpDir);
  }
  finally {
    system "rm -rf $tmpDir";
  };

  return  {
	   file       => $bundle,
	   destructor => sub {   
	     my $res = unlink $bundle;
	     $res or throw EBox::Exceptions::Internal('Can not remove  used openvpn client bundle');
	   } ,
	  };
}


sub _confFile
{
  my ($class, $server, $tmpDir) = @_;
  my $confFile = $tmpDir . '/' . $server->name . '-client';
  $confFile    .= $class->confFileExtension;
}

sub _createBundle
{
  my ($class, $server,  $tmpDir) = @_;


  my $bundle = $class->bundleFilename($server->name);
  my $createCmd    = $class->createBundleCmd($bundle, $tmpDir) ;

  try {
    EBox::Sudo::root($createCmd);

    EBox::Sudo::root("chmod 0600 $bundle");
    my ($egid) = split '\s+', $EGID;
    EBox::Sudo::root("chown $EUID.$egid $bundle");
  }
  otherwise {
    my $ex = shift;

    if (defined $bundle) {
      EBox::Sudo::root("rm -f $bundle");
    }

    $ex->throw();
  };

  return $bundle;
}

1;
