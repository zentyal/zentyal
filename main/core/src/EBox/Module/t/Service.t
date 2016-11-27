# Copyright (C) 2013 Zentyal S.L.
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

package EBox::CORE::Service::Test;

use base 'Test::Class';

use Test::More skip_all => 'FIXME';
use Test::Exception;
use Test::Deep;
use EBox::Global::TestStub;
use EBox::Module::Config::TestStub;
use EBox::Module::Config::TestStub;
use EBox::Model::Manager;
use Test::More;

sub setUpConfiguration : Test(startup)
{
    EBox::Global::TestStub::fake();
}

sub clearConfiguration : Test(shutdown)
{
    EBox::Module::Config::TestStub::setConfig();
}

sub test_one_level_of_dependencies : Test
{
    my $users = EBox::Global->modInstance('samba');
    is_deeply($users->enableModDependsRecursive(), [qw(ntp network dns)]);
}

sub test_two_level_of_dependencies : Test
{
    my $mail = EBox::Global->modInstance('mail');
    is_deeply($mail->enableModDependsRecursive(), [qw(ntp network firewall dns samba mail)]);
}


1;

END {
    EBox::CORE::Service::Test->runtests();
}
