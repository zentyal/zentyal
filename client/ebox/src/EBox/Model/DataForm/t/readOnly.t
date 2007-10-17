# Copyright (C) 2007 Warp Networks S.L.
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

# Unit test to check ModelManager

use strict;
use warnings;

use lib '../../..';

use Test::More tests => 10;
use Test::Exception;
use Test::Deep;

use EBox::Global;
use EBox::Logs;

BEGIN {
    diag ( 'Starting read only form unit test' );
    use_ok( 'EBox::Model::DataForm::ReadOnly' );
    use_ok( 'EBox::Test::StaticForm');
}


my $logs = EBox::Global->modInstance('logs');
my $model = new EBox::Test::StaticForm( gconfmodule => $logs,
                                        directory   => '1');

isa_ok( $model, 'EBox::Test::StaticForm');

throws_ok {
    $model->setRow();
} 'EBox::Exceptions::Internal', 'Set row launches an exception';

throws_ok {
    $model->setTypedRow();
} 'EBox::Exceptions::Internal', 'Set typed row launches an exception';

cmp_deeply( $model->row()->{printableValueHash},
            {
             compulsory_addr     => '10.0.0.0/24',
             compulsory_boolean  => 0,
             compulsory_int      => 12,
             compulsory_text     => 'bar',
             compulsory_mac      => '00:00:00:FA:BA:DA',
             compulsory_password => 'fabada',
             port_range          => '20:2000',
             compulsory_service  => 'ICMP',
            },
            'Get the static row from the content method return value');

1;
