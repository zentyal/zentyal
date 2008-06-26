package EBox::OpenVPN::Server::ClientBundleGenerator::Linux;

# package:
use strict;
use warnings;
use EBox::Config;

use base 'EBox::OpenVPN::Server::ClientBundleGenerator';

sub bundleFilename
{
    my ($class, $serverName) = @_;
    return EBox::Config::downloads() . "$serverName-client.tar.gz";
}

sub createBundleCmds
{
    my ($class, $bundleFile, $tmpDir) = @_;

    my @filesInTmpDir = `ls $tmpDir`;
    chomp @filesInTmpDir;

    return ("tar czf $bundleFile -C $tmpDir @filesInTmpDir");
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
