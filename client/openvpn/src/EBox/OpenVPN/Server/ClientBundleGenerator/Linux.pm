# Copyright (C) 2008-2010 eBox Technologies S.L.
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
#
package EBox::OpenVPN::Server::ClientBundleGenerator::Linux;

# package:
use strict;
use warnings;
use EBox::Config;

use base 'EBox::OpenVPN::Server::ClientBundleGenerator';

sub bundleFilename
{
    my ($class, $serverName, $cn) = @_;

    my $filename = "$serverName-client";
    if ($cn) {
        $filename .= "-$cn";
    }
    return EBox::Config::downloads() . "$filename.tar.gz";
}

sub createBundleCmds
{
    my ($class, $bundleFile, $tmpDir) = @_;

    my @filesInTmpDir = `ls '$tmpDir'`;
    chomp @filesInTmpDir;

    return ("tar czf '$bundleFile' -C '$tmpDir' "
              . join(' ', map { qq{'$_'} } @filesInTmpDir));
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
