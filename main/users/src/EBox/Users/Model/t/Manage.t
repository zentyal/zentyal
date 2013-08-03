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

use Test::More tests => 5;

use EBox::Global::TestStub;

use lib '../../../..';

EBox::Global::TestStub::fake();

my $users = EBox::Global->modInstance('users');

is_deeply $users->ousToHide(), [ 'postfix', 'Builtin', 'Kerberos', 'Zarafa' ], 'OUs to hide are the expected ones';

my $manage = $users->model('Manage');
isa_ok $manage, 'EBox::Users::Model::Manage', 'model can be instanced';

isnt $manage->_hiddenOU('Users'), 1, 'Users OU is not hidden';
is $manage->_hiddenOU('Kerberos'), 1, 'Kerberos OU is hidden';
is $manage->_hiddenOU('Builtin'), 1, 'Builtin OU is hidden';

1;
