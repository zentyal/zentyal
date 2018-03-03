# Copyright (C) 2006-2007 Warp Networks S.L.
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

package EBox::Sudo::TestStub;

use EBox::Sudo;
use File::Temp qw(tempfile);
# XXX there are unclear situation with comamnds containig ';' but this is also de case of EBox::Sudo

use Readonly;
Readonly::Scalar our $GOOD_SUDO_PATH => $EBox::Sudo::SUDO_PATH;
Readonly::Scalar our $FAKE_SUDO_PATH => '';

Readonly::Scalar our $GOOD_STDERR_FILE => $EBox::Sudo::STDERR_FILE;

my ($fh,$tmpfile) = tempfile();
close $fh;

Readonly::Scalar our $FAKE_STDERR_FILE => $tmpfile;

{

no warnings 'redefine';

sub fake
{
    *EBox::Sudo::SUDO_PATH = \$FAKE_SUDO_PATH;
    *EBox::Sudo::STDERR_FILE = \$FAKE_STDERR_FILE;

    *EBox::Sudo::root = \&_fakeRoot;
    *EBox::Sudo::silentRoot = \&_fakeSilentRoot;
}

sub unfake
{
    *EBox::Sudo::SUDO_PATH = \$GOOD_SUDO_PATH;
    *EBox::Sudo::STDERR_FILE = \$GOOD_STDERR_FILE;

    delete $INC{'EBox/Sudo.pm'};
    eval 'use EBox::Sudo';
}

}

sub isFaked
{
    return $EBox::Sudo::SUDO_PATH ne $GOOD_SUDO_PATH;
}

sub _fakeRoot
{
    _fakeRootCommands(1, @_);
}

sub _fakeSilentRoot
{
    _fakeRootCommands(0, @_);
}

sub _fakeRootCommands
{
    my ($mode, @cmds) = @_;
    @cmds =  _filterCommands(@cmds);
    EBox::Sudo::_root(0, @cmds)
}

my @banFilters;
sub addCommandBanFilter
{
    my @filters = @_;
    push @banFilters, @filters;
}

sub _filterCommands
{
    my @cmds = @_;
    my @filtered;
    foreach my $cmd (@cmds) {
        my $ban;
        foreach my $banFilter (@banFilters) {
            if ($cmd =~ m/$banFilter/) {
                $ban = 1;
                last;
            }
        }
        if (not $ban) {
            push @filtered, $cmd;
        }
    }
    return @filtered;
}

1;
