#!/usr/bin/perl -w
#
# Copyright (C) 2014 Zentyal S.L.
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

package EBox::Network::Test;

use base 'Test::Class';

use EBox::Test::RedisMock;

use Test::Exception;
use Test::More;

sub test_use_ok : Test(startup => 1)
{
    use_ok('EBox::Network') or die;
}

sub get_module : Test(setup)
{
    my ($self) = @_;
    my $redis = EBox::Test::RedisMock->new();
    $self->{mod} = EBox::Network->_create(redis => $redis);
}

sub test_flag_if_up : Test(8)
{
    my ($self) = @_;

    my $mod = $self->{mod};

    is($mod->flagIfUp(), undef, 'No flag at init');
    lives_ok { $mod->unsetFlagIfUp() } 'No problem at not deleting the flag';
    lives_ok { $mod->_flagIfUp([]) } 'No ifaces to set up';
    is($mod->flagIfUp(), undef, 'No flag yet');
    lives_ok { $mod->_flagIfUp(['eth0']) } 'eth0 to set up';
    is_deeply($mod->flagIfUp(), ['eth0'], 'Flag is set correctly');
    lives_ok { $mod->unsetFlagIfUp() } 'No problem at deleting the flag';
    is($mod->flagIfUp(), undef, 'Flag has been unset correctly');
}

1;

END {
    EBox::Network::Test->runtests();
}
