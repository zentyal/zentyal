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

use Test::More tests => 6;

use EBox::Global::TestStub;

EBox::Global::TestStub::fake();

my $users = EBox::Global->modInstance('samba');

is_deeply $users->ousToHide(), [ 'postfix', 'Builtin', 'Kerberos' ], 'OUs to hide are the expected ones';

my $manage = $users->model('Manage');
isa_ok $manage, 'EBox::Samba::Model::Manage', 'model can be instanced';

isnt $manage->_hiddenOU('OU=Users,DC=foo,DC=bar'), 1, 'Users OU is not hidden';
is $manage->_hiddenOU('OU=Kerberos,DC=foo,DC=bar'), 1, 'Kerberos OU is hidden';
is $manage->_hiddenOU('OU=Builtin,DC=foo,DC=bar'), 1, 'Builtin OU is hidden';
is $manage->_hiddenOU('OU=Kerberos,OU=foo,DC=bar,DC=baz'), undef, 'Only hide OUs under base DN';

1;
