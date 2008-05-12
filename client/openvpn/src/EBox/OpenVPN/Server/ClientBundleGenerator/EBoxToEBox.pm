package EBox::OpenVPN::Server::ClientBundleGenerator::EBoxToEBox;
use base 'EBox::OpenVPN::Server::ClientBundleGenerator';
# package:
use strict;
use warnings;


use EBox::Config;
use File::Copy;
use File::Slurp qw(write_file read_file);


use Error qw(:try);



sub bundleFilename
{
  my ($class, $serverName) = @_;
  return EBox::Config::tmp() . "/$serverName-EBoxToEBox.tar.gz";
}

sub createBundleCmds
{
  my ($class, $bundleFile, $tmpDir) = @_;
  return (
	  "tar czf $bundleFile -C $tmpDir ."
	  );
}



sub _createBundleContents
{
  my ($class, $server, $tmpDir, %params) = @_;

  my $clientCertificate = $params{clientCertificate};
  $class->_copyCerts($server, $clientCertificate, $tmpDir);

  my $serversAddr_r = $params{addresses};
  $class->_serverConfiguration($server, $serversAddr_r, $tmpDir);
}


sub _copyCerts
{
  my ($class, $server, $clientCertificate, $tmpDir) = @_;

  my $certificates_r = $class->_clientCertificatesPaths($server, $clientCertificate);

  my %certsToCopy = (
		     $certificates_r->{ca}   => $class->caFile($tmpDir),
		     $certificates_r->{cert} => $class->certFile($tmpDir),
		     $certificates_r->{key} =>  $class->privateKeyFile($tmpDir)
		    );

  while (my ($src, $dst) = each %certsToCopy) {
    copy ($src, $dst) or
      throw EBox::Exceptions::External("Cannot copy file $src to $dst: $!");
  }
}

sub _serverConfiguration
{
  my ($class, $server, $serversAddr_r, $tmpDir) = @_;


  my $confString;
  $confString .= 'proto,' . $server->proto() . ',';
  $confString .= 'ripPasswd,' . $server->ripPasswd() . ',';

  my $port = $server->port();
  $confString .= 'servers,';
  foreach my $addr (@{ $serversAddr_r }) {
    $confString .= "$addr:$port:";
  }


  my $file =  $tmpDir . '/' .  $class->serverConfigurationFile();
  write_file($file, $confString);
}

sub serverConfigurationFile
{
  my ($class, $tmpDir) = @_;
  return  "$tmpDir/server-conf.csv";
}


sub caFile
{
  my ($class, $tmpDir) = @_;
  return  "$tmpDir/ca.crt";
}

sub certFile
{
  my ($class, $tmpDir) = @_;
  return  "$tmpDir/cert.crt";
}


sub privateKeyFile
{
  my ($class, $tmpDir) = @_;
  return  "$tmpDir/privateKey.crt";
}

sub initParamsFromBundle
{
  my ($class, $bundleFile) = @_;



  my $tmpDir = EBox::Config::tmp() . '/EBoxToEBoxBundle.tmp' ;
  system "rm -rf $tmpDir";
  EBox::FileSystem::makePrivateDir($tmpDir);

  my $extractCmd = "tar xzf  $bundleFile -C $tmpDir";
  EBox::Sudo::root($extractCmd);
  
  my @initParams;
  try {
    push @initParams, $class->_serverConfigurationFromFile($tmpDir);

    push @initParams, (caCertificate => $class->caFile($tmpDir));
    push @initParams, (certificate   => $class->certFile($tmpDir));
    push @initParams, (certificateKey => $class->privateKeyFile($tmpDir));

    push @initParams, (bundle => $bundleFile);
    push @initParams, (tmpDir => $tmpDir);
  }
  otherwise {
    my $ex = shift @_;
    system "rm -rf $tmpDir";
    $ex->throw();

  };

  return @initParams;
}

sub _serverConfigurationFromFile
{
  my ($class, $tmpDir) = @_;
  my $file = $class->serverConfigurationFile($tmpDir);

  my $contents = read_file($file);
  my %conf = split ',', $contents;

  # server parameters need special treatment
  my %portByAddr = split ':', $conf{servers};
  my @servers = map {
    my $port = $portByAddr{$_};
    [$_ => $port ]
  } keys %portByAddr;


  $conf{servers} = \@servers;

  return %conf;
}


1;
