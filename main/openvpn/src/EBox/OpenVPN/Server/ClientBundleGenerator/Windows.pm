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

package EBox::OpenVPN::Server::ClientBundleGenerator::Windows;

use base 'EBox::OpenVPN::Server::ClientBundleGenerator';
# package:

use EBox::Config;
use EBox::Exceptions::Internal;

use File::Glob ':glob';
use File::Slurp;

use constant ZIP_PATH => '/usr/bin/zip';

sub bundleFilename
{
    my ($class, $serverName, $cn) = @_;

    my $filename = "$serverName-client";
    if ($cn) {
        $filename .= "-$cn";
    }
    return EBox::Config::downloads() . "$filename.zip";
}

sub createBundleCmds
{
    my ($class, $bundleFile, $tmpDir, %extraParams) = @_;

    my @cmds = (
        ZIP_PATH . " -j '$bundleFile' '$tmpDir'/*",

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

sub mangleConfFile
{
    my ($class, $file) = @_;
    # convert to windowa format
    my @lines = File::Slurp::read_file($file);
    @lines = map {
        $_ =~ s{\n}{\r\n};
        $_
    } @lines;
    File::Slurp::write_file($file, \@lines);
}

sub _installerCmd
{
    my ($class, $bundleFile) = @_;
    my $installerFile = $class->_windowsClientInstaller();

    return ZIP_PATH . " -g -j '$bundleFile' '$installerFile'";
}

sub _windowsClientInstaller
{
    my $dir = EBox::Config::share() . 'zentyal-openvpn';

    my @candidates = bsd_glob("$dir/openvpn*install*exe");   # the sort is to
    if (not @candidates) {
        throw EBox::Exceptions::Internal("No windows installer found");
    }

    # (hopefully ) to sort
    # by version number

    my ($installer) = sort @candidates;

    return $installer;
}

1;
