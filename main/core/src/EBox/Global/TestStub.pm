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

package EBox::Global::TestStub;

use strict;
use warnings;

use Test::MockObject;
use Params::Validate;
use EBox::Global;
use EBox::TestStub;
use EBox::Config::TestStub;
use EBox::Test::RedisMock;

my %modulesInfo;

sub setAllEBoxModules
{
    my (%modulesByName) = @_;

    while (my ($name, $module) = each %modulesByName) {
        setEBoxModule($name, $module);
    }
}

sub setEBoxModule
{
    my ($name, $class, $depends) = @_;
    validate_pos(@_ ,1, 1, 0);

    defined $depends or
        $depends = [];

    $modulesInfo{$name} = {
        class => $class,
        depends => $depends,
        changed => 0,
    };
}

sub clear
{
    %modulesInfo = ();
}

sub  _fakedWriteModInfo
{
    my ($self, $name, $info) = @_;

    $modulesInfo{$name} = $info;
}

sub fake
{
    EBox::TestStub::fake();
    EBox::Config::TestStub::fake(modules => 'core/schemas/');
    EBox::Global->new(1, redis => EBox::Test::RedisMock->new());
    *EBox::GlobalImpl::modExists = \&EBox::GlobalImpl::_className;
}

# only for interface completion
sub unfake
{
}

1;
