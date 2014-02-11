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

sub connection : Test(4)
{
    my ($self) = @_;
    my $class = $self->class;

    my $ldbInstance = $class->instance();

    can_ok($ldbInstance, 'connection');

    my $connection = undef;
    ok($connection = $ldbInstance->connection(), 'Got the LDB connection');
    isa_ok($connection, 'Net::LDAP');
    isa_ok($connection, 'Test::Net::LDAP::Mock');
}

sub url : Test(1)
{
    my ($self) = @_;
    my $class = $self->class;

    cmp_ok($class->url(), 'eq', 'ldapi://%2fvar%2flib%2fsamba4%2fprivate%2fldap_priv%2fldapi', "Getting the LDB's URL");
}

1;

END {
    EBox::LDB::Test->runtests();
}
