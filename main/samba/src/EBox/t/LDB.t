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

package EBox::LDB::Test;

use EBox::Global::TestStub;
use base 'EBox::Test::LDBClass';

use Test::More;

sub class
{
    'EBox::LDB'
}

sub ldbCon : Test(4)
{
    my ($self) = @_;
    my $class = $self->class;

    my $ldbInstance = $class->instance();

    can_ok($ldbInstance, 'ldbCon');

    my $ldbCon = undef;
    ok($ldbCon = $ldbInstance->ldbCon(), 'Got the ldbConnection');
    isa_ok($ldbCon, 'Net::LDAP');
    isa_ok($ldbCon, 'Test::Net::LDAP::Mock');
}

1;

END {
    EBox::LDB::Test->runtests();
}
