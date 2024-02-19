# Copyright (C) 2012-2013 Zentyal S.L.
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
use warnings;
use strict;

package EBox::Util::SHM;

use EBox::Config;
use EBox::Exceptions::Internal;
use File::Basename;
use JSON::XS;

my $SHM_PATH = EBox::Config::shm();

sub setValue
{
    my ($dir, $name, $value) = @_;

    my $hash = hash($dir);
    $hash->{$name} = $value;
    setHash($dir, $hash);
}

sub setHash
{
    my ($key, $hash) = @_;

    my $path = "$SHM_PATH/";
    $path .= dirname($key);
    unless (-d $path) {
        system ("mkdir -p $path");
        EBox::Sudo::silentRoot("chown -R ebox:ebox $path");
    }
    $path = "$SHM_PATH/$key";

    open (my $fh, '>', $path) or
        throw EBox::Exceptions::Internal("SHM: Can't write to $path: $!");
    print $fh encode_json($hash);
    close ($fh);
}

sub value
{
    my ($dir, $name) = @_;

    my $hash = hash($dir);
    return $hash->{$name};
}

sub hash
{
    my ($key) = @_;

    my $path = "$SHM_PATH/$key";

    unless (-e $path) {
        return {};
    }

    open (my $fh, '<', "$SHM_PATH/$key") or
        throw EBox::Exceptions::Internal("SHM: Can't read $path: $!");

    my $value = <$fh>;
    close ($fh);

    unless ($value) {
        return {};
    }

    return decode_json($value);
}

sub deletekey
{
    my ($key) = @_;

    unlink ("$SHM_PATH/$key");
}

sub subkeys
{
    my ($dir) = @_;

    my $path = "$SHM_PATH/$dir";
    unless (-d $path) {
        return ();
    }

    opendir (my $dh, $path) or
        throw EBox::Exceptions::Internal("SHM: Can't open dir $path: $!");
    my @keys = readdir($dh);
    closedir ($dh) or
        throw EBox::Exceptions::Internal("SHM: Can't close dir handle for $path: $!");
    return @keys;
}

1;
