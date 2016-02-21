# Copyright (C) 2008-2013 Zentyal S.L.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
use strict;
use warnings;

package EBox::OpenVPN::Server::ClientBundleGenerator::EBoxToEBox;

use base 'EBox::OpenVPN::Server::ClientBundleGenerator';

use EBox::Config;
use EBox::Gettext;
use EBox::Exceptions::External;
use File::Copy;
use File::Slurp qw(write_file read_file);

use TryCatch;

sub bundleFilename
{
    my ($class, $serverName, $cn) = @_;

    my $filename= "$serverName-ZentyalToZentyal";
    if ($cn) {
        $filename .= "-$cn";
    }
    $filename .= '.tar.gz';
    return EBox::Config::downloads() . $filename;
}

sub createBundleCmds
{
    my ($class, $bundleFile, $tmpDir) = @_;

    my @filesInTmpDir = `ls '$tmpDir'`;
    chomp @filesInTmpDir;

    return ("tar czf '$bundleFile' -C '$tmpDir' "
              . join(' ', map { qq{'$_'} } @filesInTmpDir));
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

    my $certificates_r =
      $class->_clientCertificatesPaths($server, $clientCertificate);

    my %certsToCopy = (
                      $certificates_r->{ca}   => $class->caFile($tmpDir),
                      $certificates_r->{cert} => $class->certFile($tmpDir),
                      $certificates_r->{key} =>  $class->privateKeyFile($tmpDir)
    );

    while (my ($src, $dst) = each %certsToCopy) {
        copy($src, $dst)
          or
          throw EBox::Exceptions::External("Cannot copy file $src to $dst: $!");
    }
}

sub _serverConfiguration
{
    my ($class, $server, $serversAddr_r, $tmpDir) = @_;

    my $confString;
    $confString .= 'proto,' . $server->proto() . ',';
    $confString .= 'ifaceType,' . $server->ifaceType() . ',';
    $confString .= 'ripPasswd,' . $server->ripPasswd() . ',';

    my $port = $server->port();
    $confString .= 'servers,';
    foreach my $addr (@{$serversAddr_r}) {
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

    my $tmpDir = EBox::Config::tmp() . '/EBoxToEBoxBundle.tmp';
    system "rm -rf $tmpDir";
    EBox::FileSystem::makePrivateDir($tmpDir);

    try {
        my $extractCmd = "tar xzf '$bundleFile' -C '$tmpDir'";
        EBox::Sudo::root($extractCmd);
    } catch {
        throw EBox::Exceptions::External(
__('This bundle is not a valid Zentyal-to-Zentyal configuration bundle. (Cannot unpack it)')
                                         );
    }

    $class->_checkBundleContents($tmpDir);

    my @initParams;
    try {
        push @initParams, $class->_serverConfigurationFromFile($tmpDir);

        push @initParams, (caCertificate => $class->caFile($tmpDir));
        push @initParams, (certificate   => $class->certFile($tmpDir));
        push @initParams, (certificateKey => $class->privateKeyFile($tmpDir));

        push @initParams, (bundle => $bundleFile);
        push @initParams, (tmpDir => $tmpDir);
    } catch ($e) {
        system "rm -rf '$tmpDir'";
        $e->throw();
    }

    return @initParams;
}

sub _checkBundleContents
{
    my ($class, $tmpDir) = @_;

    my $serverConfFile = $class->serverConfigurationFile($tmpDir);
    if (not -r $serverConfFile) {
        throw EBox::Exceptions::External(
__('This bundle is not a valid Zentyal-to-Zentyal configuration bundle. (Missing server configuration file)')
                                        );
    }

    my $caCertificate = $class->caFile($tmpDir);
    if (not -r $caCertificate) {
        throw EBox::Exceptions::External(
__('This bundle is not a valid Zentyal-to-Zentyal configuration bundle. (Missing CA certificate file)')
                                        );
    }

    my $certificate   = $class->certFile($tmpDir);
    if (not -r $certificate) {
        throw EBox::Exceptions::External(
__('This bundle is not a valid Zentyal-to-Zentyal configuration bundle. (Missing certificate file)')
                                        );
    }

    my $certificateKey = $class->privateKeyFile($tmpDir);
    if (not -r $certificateKey) {
        throw EBox::Exceptions::External(
__('This bundle is not a valid Zentyal-to-Zentyal configuration bundle. (Missing certificate private key file)')
                                        );
    }

}

sub _serverConfigurationFromFile
{
    my ($class, $tmpDir) = @_;
    my $file = $class->serverConfigurationFile($tmpDir);

    my $contents = read_file($file);
    my %conf = split ',', $contents;

    # convert ifaceType to tunInterface
    my $ifaceType = delete $conf{ifaceType};

    if ($ifaceType and ($ifaceType eq 'tun')) {
        $conf{tunInterface} = 1;
    } else {
        $conf{tunInterface} = 0;
    }

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
