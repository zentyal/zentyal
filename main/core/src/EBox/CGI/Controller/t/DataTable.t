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
use Test::Exception;
use Test::Deep;

use lib '../..';

use EBox::TestStub;
use EBox::Global::TestStub;
use EBox::TestStubs;
use EBox::Test::CGI;
use EBox::Model::DataTable::Test;
use EBox::Types::Text;

use Plack::Request;

use_ok('EBox::CGI::Controller::DataTable');

EBox::TestStub::fake();
EBox::Global::TestStub::fake();

EBox::TestStubs::fakeModule(name => 'fakeModule');

EBox::TestStubs::fakeModule(
    name => 'audit',
    subs => [
        isEnabled => sub {
            return undef
        }
    ]
);

my $table = {
    tableDescription => [
        new EBox::Types::Text(
            fieldName => 'field1',
            printableName => 'field1',
        ),
    ],
    tableName => 'test',
};

my $model = EBox::Model::DataTable::Test::->_newDataTable($table);
isa_ok( $model, 'EBox::Model::DataTable');

my $rowId;

addRowTest();
removeRowTest();

sub addRowTest
{
    my $env = {};
    $env->{HTTP_HOST} = '192.168.1.1';
    $env->{HTTP_REFERER} = "https://$env->{HTTP_HOST}/fakeModule/View/DataTable";
    my $req = Plack::Request->new($env);
    my $parameters = $req->parameters();
    $parameters->set('action', 'add');
    $parameters->set('tablename', 'test');
    $parameters->set('directory', '/conf/fakeModule/DataTable');
    $parameters->set('field1', 'Foo');
    my $controller = new EBox::CGI::Controller::DataTable(
        tableModel => $model,
        request => $req
    );
    isa_ok($controller, 'EBox::CGI::Controller::DataTable');

    lives_ok {
        $rowId = $controller->addRow();
    } 'Adding a new row';

}

sub removeRowTest
{
    my $env = {};
    $env->{HTTP_HOST} = '192.168.1.1';
    $env->{HTTP_REFERER} = "https://$env->{HTTP_HOST}/fakeModule/View/DataTable";
    my $req = Plack::Request->new($env);
    my $parameters = $req->parameters();
    $parameters->set('action', 'del');
    $parameters->set('tablename', 'test');
    $parameters->set('directory', '/conf/fakeModule/DataTable');
    $parameters->set('id', $rowId);
    my $controller = new EBox::CGI::Controller::DataTable(
        tableModel => $model,
        request => $req
    );
    isa_ok($controller, 'EBox::CGI::Controller::DataTable');

    lives_ok {
        $controller->removeRow(id => $rowId);
    } 'Removing the previously added row';
}

1;
