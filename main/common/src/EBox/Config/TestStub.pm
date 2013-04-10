# Copyright (C) 2008-2012 eBox Technologies S.L.
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

package EBox::Config::TestStub;

use EBox::Config;
use Test::MockModule;
use Test::MockObject;
use Perl6::Junction qw(all);
use EBox::Config;
use Error qw(:try);

# XXX: Derivated paths are totally decoupled from their base path (datadir, sysconfdir, localstatedir, libdir)
# possible solution 1: rewrite EBox::Config so the derivated elements use a sub to get the needed element
# possible solution 2: rewrite this package to have specialized fakes for those subs

my $fakedModule;

sub fake
{
    my %fakedConfig = @_;
    $fakedModule = new Test::MockModule('EBox::Config');
    if (not exists $fakedConfig{user}) {
        $fakedConfig{user} = 'ebox';
    }
    if (not exists $fakedConfig{group}) {
        $fakedConfig{group} = 'ebox';
    }
    setConfigKeys(%fakedConfig);
}

sub unfake
{
    $fakedModule = undef;
}

sub setConfigKeys
{
    my %fakedConfig = @_;
    if (not $fakedModule) {
        die "EBox::Config not faked";
    }
    while (my ($key, $value) = each %fakedConfig) {
        if (not EBox::Config->can($key)) {
            die "Invalid EBox::Config key $key";
        }
        $fakedModule->mock($key => $value);
    }
}

1;
