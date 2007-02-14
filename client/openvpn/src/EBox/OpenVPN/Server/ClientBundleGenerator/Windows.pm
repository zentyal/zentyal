package EBox::OpenVPN::Server::ClientBundleGenerator::Windows;
# package:
use strict;
use warnings;
use EBox::Config;

use base 'EBox::OpenVPN::Server::ClientBundleGenerator';


sub bundleFilename
{
  my ($class, $serverName) = @_;
  return EBox::Config::tmp() . "/$serverName-client.zip";
}

sub createBundleCmd
{
  my ($class, $bundleFile, $tmpDir) = @_;
  return "/usr/bin/zip -j  $bundleFile $tmpDir/*";
}


sub confFileExtension
{
  my ($class) = @_;
  return '.ovpn';
}




1;
