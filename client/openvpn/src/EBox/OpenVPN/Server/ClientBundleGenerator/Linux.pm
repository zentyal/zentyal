package EBox::OpenVPN::Server::ClientBundleGenerator::Linux;
# package:
use strict;
use warnings;
use EBox::Config;

use base 'EBox::OpenVPN::Server::ClientBundleGenerator';


sub bundleFilename
{
  my ($class, $serverName) = @_;
  return EBox::Config::tmp() . "/$serverName-client.tar.gz";
}

sub createBundleCmd
{
  my ($class, $bundleFile, $tmpDir) = @_;
  return "tar czf $bundleFile -C $tmpDir .";
}

sub confFileExtension
{
  my ($class) = @_;
  return '.conf';
}

sub confFileExtraParameters
{
  my ($class) = @_;
  return ( userAndGroup => [qw(nobody nogroup)]);
}



1;
