# Copyright (C) 2008 Warp Networks S.L.
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

package EBox::Model::DataTable::Test;

use lib '../../..';
use base 'EBox::Test::Class';

use strict;
use warnings;


use Test::More;;
use Test::Exception;
use Test::MockObject;
use Test::MockObject::Extends;
use Perl6::Junction qw(any);


use EBox::Types::Abstract;

use EBox::Model::Row;
use EBox::Model::DataTable;
use EBox::Types::Abstract;
use EBox::Types::HasMany;


sub setEBoxModules : Test(setup)
{
    EBox::TestStubs::fakeEBoxModule(name => 'fakeModule');

}

sub clearGConf : Test(teardown)
{
  EBox::TestStubs::setConfig();
}


sub deviantTableTest : Test(2)
{
    my ($self) = @_;

    my @cases;
    push @cases,  [  'empty table' => {
                         }

                  ];
    push @cases,  [  'empty tableDescription' => {
                            tableDescription => [],
                         }

                  ];

    
    foreach my $case_r (@cases) {
        my ($caseName, $table) = @{ $case_r };
        my $dataTable = Test::MockObject::Extends->new($self->_newDataTable);
        $dataTable->set_always('_table' => $table);
        dies_ok {
            $dataTable->table();
        } "expecting error eith deviant table case: $caseName";
    }


}


sub _newDataTable
{
    my $gconfmodule = EBox::Global->modInstance('fakeModule');

    my $dataTableDir = 'DataTable';


    my $dataTable  = EBox::Model::DataTable->new(
                                                 gconfmodule => $gconfmodule,
                                                 directory   => $dataTableDir,
                                                 domain      => 'domain',
                                                );


    return $dataTable;
}


1;
