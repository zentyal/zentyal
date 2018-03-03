# Copyright (C) 2007 Warp Networks S.L.
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

package EBox::OpenVPN::Server::ClientBundleGenerator;

use EBox::Global;
use EBox::Config;
use EBox::Gettext;
use EBox::FileSystem;
use EBox::Validate;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::External;

use English qw(-no_match_vars);
use File::Basename;
use TryCatch;
use Params::Validate qw(validate_pos);
use File::Slurp qw(read_file);

sub _generateClientConf
{
    my ($class, $server, $file, $certificatesPath_r, $serversAddr_r, %extraParams) = @_;

    my @confParams;

    push @confParams,
      (
        dev   => $server->ifaceType(),
        proto => $server->proto(),
      );

    my $port      = $server->port();
    my $checkLabel = __(q{Server's address});
    my @servers =  map  {
        EBox::Validate::checkHost($_, $checkLabel);
        [$_, $port]
    }   @{$serversAddr_r};
    @servers
      or throw EBox::Exceptions::External(
              __x(
                  'You must provide at least one address for the server {name}',
                  name => $server->name
              )
      );
    push @confParams, (connStrategy => $extraParams{connStrategy});
    push @confParams, (servers => \@servers);

    my %certificates = %{$certificatesPath_r};

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

    EBox::Module::Base::writeConfFileNoCheck($file,
                                     'openvpn/noebox-openvpn-client.conf.mas',
                                     \@confParams, $fileOptions);
    $class->mangleConfFile($file);
}

sub mangleConfFile
{
    # no mangling by default
}

sub confFileExtraParameters
{
    return ();
}

sub _copyCertFilesToDir
{
    my ($class, $certificatesPath_r, $dir) = @_;

    foreach my $file (values %{$certificatesPath_r}) {
        EBox::Sudo::root(qq{cp '$file' '$dir/'});
    }
}

sub _clientCertificatesPaths
{
    my ($class, $server, $clientCertificate) = @_;
    my %certificates;

    # CA certificate
    $certificates{ca}= $server->caCertificatePath;

    # client certificate
    my $certificate_r   = $server->checkCertificate($clientCertificate);
    $certificates{cert} = $certificate_r->{path};

    # client private key
    my $ca = EBox::Global->modInstance('ca');
    my $keys = $ca->getKeys($clientCertificate);
    $certificates{key} = $keys->{privateKey};

    return \%certificates;
}

sub clientBundle
{
    my ($class, %params) = @_;

    # extract mandatory parameters
    my $server = $params{server};
    $server or throw EBox::Exceptions::MissingArgument('server');
    my $clientCertificate = $params{clientCertificate};
    $clientCertificate
      or throw EBox::Exceptions::MissingArgument('clientCertificate');
    my $serversAddr_r = $params{addresses};
    $serversAddr_r or throw EBox::Exceptions::MissingArgument('addresses');

    ($clientCertificate ne $server->certificate())
      or throw EBox::Exceptions::External(
         __(q{The client certificate can't be the same than the server's one}));

    my $bundle;
    my $tmpDir = EBox::Config::tmp() . $server->name . '-client.tmp';
    system "rm -rf '$tmpDir'";
    EBox::FileSystem::makePrivateDir($tmpDir);

    try {
        $class->_createBundleContents($server, $tmpDir, %params);

        # create bundle itself
        $bundle  =  $class->_createBundle($server,  $tmpDir, %params);
    } catch ($e) {
        system "rm -rf '$tmpDir'";
        $e->throw();
    }
    system "rm -rf '$tmpDir'";

    return basename($bundle);
}

sub _createBundleContents
{
    my ($class, $server, $tmpDir, %params) = @_;
    my $clientCertificate = $params{clientCertificate};
    my $serversAddr_r = $params{addresses};

    my $certificatesPath_r =
      $class->_clientCertificatesPaths($server, $clientCertificate);

    # client configuration file
    my $confFile = $class->_confFile($server, $tmpDir);
    $class->_generateClientConf($server, $confFile, $certificatesPath_r,
                                $serversAddr_r, %params);

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
    my ($class, $server,  $tmpDir, %extraParams) = @_;

    my $cn = $extraParams{clientCertificate};
    my $bundle = $class->bundleFilename($server->name, $cn);
    my @createCmds    =
      $class->createBundleCmds($bundle, $tmpDir, %extraParams);

    try {
        foreach my $cmd (@createCmds) {
            EBox::Sudo::root($cmd);
        }

        EBox::Sudo::root("chmod 0600 '$bundle'");
        my ($egid) = split '\s+', $EGID;
        EBox::Sudo::root("chown $EUID.$egid '$bundle'");
    } catch ($e) {
        if (defined $bundle) {
            EBox::Sudo::root("rm -f '$bundle'");
        }

        $e->throw();
    }

    return $bundle;
}

1;
