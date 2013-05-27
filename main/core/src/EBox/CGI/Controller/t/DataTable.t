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

use Test::More tests => 2;
use Test::Exception;
use Test::Deep;

use lib '../..';

use EBox::TestStub;
use EBox::Global::TestStub;
use EBox::TestStubs;
use EBox::Test::CGI;
use EBox::Model::DataTable::Test;

use_ok('EBox::CGI::Controller::DataTable');

EBox::TestStub::fake();
EBox::Global::TestStub::fake();

EBox::TestStubs::fakeModule(name => 'fakeModule');
my $model = EBox::Model::DataTable::Test::->_newPopulatedDataTable();
isa_ok( $model, 'EBox::Model::DataTable');

#my $rowId;

#addRowTest();
removeRowTest();

sub addRowTest
{
    my $controller = new EBox::CGI::Controller::DataTable(tableModel => $model);
    isa_ok($controller, 'EBox::CGI::Controller::DataTable');

    # XXX: How the hell do we pass arguments to the CGI?!!?!?!
    #EBox::Test::CGI::setCgiParams($controller, 'POSTDATA' => 'fakeModule_field1=Foo');

    #lives_ok {
    #    $rowId = $controller->addRow();
    #} 'Adding a new row';

}

sub removeRowTest
{
    my $controller = new EBox::CGI::Controller::DataTable(
        tableModel => $model,
    );

    # XXX: How the hell do we pass arguments to the CGI?!!?!?!
    #EBox::Test::CGI::setCgiParams($controller, 'POSTDATA' => 'fakeModule_field1=Foo');
    #lives_ok {
    #    $controller->removeRow(id => 1);
    #} 'Removing the previously added row';
}

1;
