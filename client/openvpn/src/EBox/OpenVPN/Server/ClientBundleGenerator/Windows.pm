package EBox::OpenVPN::Server::ClientBundleGenerator::Windows;

# package:
use strict;
use warnings;

use base 'EBox::OpenVPN::Server::ClientBundleGenerator';

use EBox::Config;

use File::Glob ':glob';

use constant ZIP_PATH => '/usr/bin/zip';

sub bundleFilename
{
    my ($class, $serverName) = @_;
    return EBox::Config::downloads() . "$serverName-client.zip";
}

sub createBundleCmds
{
    my ($class, $bundleFile, $tmpDir, %extraParams) = @_;

    my @cmds = (
        ZIP_PATH . " -j  $bundleFile $tmpDir/*",

    );

    if ($extraParams{installer}) {
        push @cmds, $class->_installerCmd($bundleFile);
    }

    return @cmds;
}

sub confFileExtension
{
    my ($class) = @_;
    return '.ovpn';
}

sub _installerCmd
{
    my ($class, $bundleFile) = @_;
    my $installerFile = $class->_windowsClientInstaller();

    return ZIP_PATH . " -g -j $bundleFile $installerFile";
}

sub _windowsClientInstaller
{
    my $dir = EBox::Config::share() . '/ebox/openvpn';

    my @candidates =
      sort bsd_glob("$dir/openvpn*install*exe");   # the sort is to
    # (hopefully ) to sort
    # by version number

    my ($installer) = pop @candidates;
    return $installer;
}

1;
