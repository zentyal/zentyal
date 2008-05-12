package EBox::OpenVPN::Server::ClientBundleGenerator;
# package:
use strict;
use warnings;

use EBox::Global;
use EBox::Config;
use EBox::Gettext;
use EBox::FileSystem;
use EBox::Validate;
use EBox::Exceptions::MissingArgument;

use English qw(-no_match_vars);
use File::Basename;
use Error qw(:try);
use Params::Validate qw(validate_pos);
use File::Slurp qw(read_file);



sub _generateClientConf
{
  my ($class, $server, $file, $certificatesPath_r, $serversAddr_r) = @_;

  my @confParams;
  
  push @confParams, (
		     dev   => $server->ifaceType(),
		     proto => $server->proto() ,
		    );
  
  my $port      = $server->port();
  my $checkLabel = __(q{Server's address});
  my @servers =  map  {  
                          EBox::Validate::checkHost($_, $checkLabel);
                         [$_, $port] 
		       }   @{ $serversAddr_r };
  @servers or throw EBox::Exceptions::External(__x('You must provide at least one address for the server {name}', name => $server->name));
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


sub serversAddr
{
  my ($class, $server,) = @_;
  validate_pos(@_, 1, 1);

  # get local addresses 
  my @localAddr;
  if ($server->localAddress()) {
    push @localAddr, $server->localAddress();
  }
  else {
    my $network = EBox::Global->modInstance('network');
    @localAddr = map { $network->ifaceAddress($_) } @{ $network->ExternalIfaces( )};
    @localAddr  or throw EBox::Exceptions::External(__(q{Can't get address for this server: no external interfaces present}));
  }

  my @externalAddr = $class->_resolveExternalAddr(@localAddr);
  return \@externalAddr;
}


sub IPResolvUrl
{
  return 'http://www.showmyip.com/simple/';
}

sub confFileExtraParameters
{
  return ();
}


sub _resolveExternalAddr
{
  my ($class, @localAddr) = @_;

  my $addrFile = EBox::Config::tmp() . '/openvpn-wget.html';
  if (-e $addrFile) {
    unlink $addrFile or throw EBox::Exceptions::Internal("Cannot remove temporal file $addrFile");
  }

  my %externalAddr;
  foreach my $local (@localAddr) {
    my $cmd = _getHtmlPageCmd($addrFile, $local);
    system $cmd;
    # we check -z because some http errrors don't cause wget to singal error but
    #  in these cases it does not write nothing in the output file (but cretes
    #  it) Maybe exists some case that doesn't signal error AND it writes
    #  something in the file, in that case we can 
    if ($? == 0 and (not -z $addrFile))  {
      my $contents = read_file($addrFile);
      my ($ipAddr) = split '\s', $contents, 2;
      if (EBox::Validate::checkIP($ipAddr)) {
	$externalAddr{$ipAddr} = 1;
      }
      else {
	EBox::error("Invalid IP address: $ipAddr. Discarding it");
      }
    } 
    
    if (-e $addrFile) {
      unlink $addrFile or throw EBox::Exceptions::Internal("Cannot remove temporal file $addrFile");
    }
  }

  return keys %externalAddr;
}


sub _getHtmlPageCmd
{
  my ($addrFile, $local) = @_;
  my $cmd = "wget -O $addrFile --bind-address=$local --tries=1 --timeout=6 " . IPResolvUrl();
  return $cmd;
}

sub _copyCertFilesToDir
{
  my ($class, $certificatesPath_r, $dir) = @_;

  foreach my $file (values %{ $certificatesPath_r }) {
    EBox::Sudo::root(qq{cp '$file' '$dir/'});
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
  my ($class, %params) = @_;
  # extract mandatory parameters
  my $server = $params{server};
  $server or throw EBox::Exceptions::MissingArgument('server');
  my $clientCertificate = $params{clientCertificate};
  $clientCertificate or throw EBox::Exceptions::MissingArgument('clientCertificate');
  my $serversAddr_r = $params{addresses};
  $serversAddr_r or throw EBox::Exceptions::MissingArgument('addresses');

  
  ($clientCertificate ne $server->certificate()) or throw EBox::Exceptions::External(__(q{The client certificate can't be the same than the server's one}));
  
  my $bundle;
  my $tmpDir = EBox::Config::tmp() . '/' . $server->name . '-client.tmp';
  system "rm -rf $tmpDir";
  EBox::FileSystem::makePrivateDir($tmpDir);

  try {
    $class->_createBundleContents($server, $tmpDir, %params);
    
    # create bundle itself
    $bundle  =  $class->_createBundle($server,  $tmpDir, %params);
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



sub _createBundleContents
{
  my ($class, $server, $tmpDir, %params) = @_;
  my $clientCertificate = $params{clientCertificate};
  my $serversAddr_r = $params{addresses};

    my $certificatesPath_r = $class->_clientCertificatesPaths($server, $clientCertificate);

    # client configuration file
    my $confFile = $class->_confFile($server, $tmpDir);
    $class->_generateClientConf($server, $confFile, $certificatesPath_r, $serversAddr_r);

    $class->_copyCertFilesToDir($certificatesPath_r, $tmpDir);
}

sub _confFile
{
  my ($class, $server, $tmpDir) = @_;
  my $confFile = $tmpDir . '/' . $server->name . '-client';
  $confFile    .= $class->confFileExtension;
}

sub _createBundle
{
  my ($class, $server,  $tmpDir, @extraParams) = @_;


  my $bundle = $class->bundleFilename($server->name);
  my @createCmds    = $class->createBundleCmds($bundle, $tmpDir, @extraParams) ;

  try {
    foreach my $cmd (@createCmds) {
      EBox::Sudo::root($cmd);
    }


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
