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

package EBox::Model::Composite::Test;

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
use EBox::Model::DataForm;
use EBox::Model::Composite;
use EBox::Model::ModelManager;
use EBox::Types::Abstract;
use EBox::Types::HasMany;
use EBox::Types::Text;



{
    my $rowIdUsed;

    no warnings 'redefine';
    sub EBox::Model::ModelManager::warnIfIdIsUsed
    {
        my ($self, $context, $id) = @_;
        if (not defined $rowIdUsed) {
            return;
        }
        elsif ($rowIdUsed eq $id) {
            throw EBox::Exceptions::DataInUse('fake warnIfIdIsUsed: row in use');
        }
       
    }

    sub EBox::Model::ModelManager::warnOnChangeOnId
    {
        my ($self, $tableName, $id) = @_;
        if (not defined $rowIdUsed) {
            return;
        }
        elsif ($rowIdUsed eq $id) {
            throw EBox::Exceptions::DataInUse('fake warnIfIdIsUsed: row in use');
        }
    }

    sub EBox::Model::ModelManager::removeRowsUsingId
    {
        # do nothing
    }

    sub EBox::Model::ModelManager::modelActionTaken
    {
        # do nothing
    }



    sub setRowIdInUse
    {
        my ($rowId) = @_;
        $rowIdUsed = $rowId;
    }
}

sub setEBoxModules : Test(setup)
{
    EBox::TestStubs::fakeEBoxModule(name => 'fakeModule');

}

sub clearGConf : Test(teardown)
{
  EBox::TestStubs::setConfig();
}


sub deviantDescriptionTest : Test(2)
{
    my ($self) = @_;
    my %cases = (
                 'select layout text but select layout was not setted'      => {
                                        name => 'ctest',
                                        printableName => 'ctest',
                                        layout        => 'tabbed',
                                        selectMessage => 'select',
                                       },
                 'empty name' =>  {
                                        name => '',
                                        printableName => 'ctest',
                                                                   
                                       },
                );

    while (my ($testName, $description) = each %cases) {
        CompositeSubclass->setNextDescription($description);
        my $composite;

        dies_ok {
            $composite = new CompositeSubclass();
        } $testName

        
    }

}


sub descriptionTest : Test(2)
{
    my ($self) = @_;
    my %cases = (
                 'empty descrition' => {},
                 'description'      => {
                                        name => 'ctest',
                                        printableName => 'ctest',
                                       }
                );

    while (my ($testName, $description) = each %cases) {
        CompositeSubclass->setNextDescription($description);
        my $composite;

        lives_ok {
            $composite = new CompositeSubclass();
        } $testName;
        
    }

}



package CompositeSubclass;
use base 'EBox::Model::Composite';

my $nextDescription;


sub _description
{
    return $nextDescription;
}


sub setNextDescription
{
    my ($class, $desc) = @_;
    $nextDescription = $desc;
}

1;
