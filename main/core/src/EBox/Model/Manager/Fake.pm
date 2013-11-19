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

package EBox::Model::Manager::Fake;

use EBox::Model::Manager;
use EBox::Exceptions::DataInUse;
use Test::MockModule;
use Test::MockObject::Extends;

my $mockedModule;

sub overrideOriginal
{
    $mockedModule = new Test::MockModule('EBox::Model::Manager');
    $mockedModule->mock(instance => \&instance,
                        warnIfIdIsUsed => \&warnIfIdIsUsed,
                        removeRowsUsingId => \&removeRowsUsingId,
                        warnOnChangeOnId => \&warnOnChangeOnId,
                       );
}

sub restoreOriginal
{
    if ($mockedModule) {
        $mockedModule->unmock_all();
        $mockedModule = undef;
    }
}

my %modelsUsingId;

# $modelsUsingId{$modelName}->{$id} = [ 'table1, 'table2' , ..]
sub setModelsUsingId
{
    %modelsUsingId = @_;
}

my $_instance;
sub instance
{
    unless (defined $_instance) {
        $_instance = Test::MockObject::Extends->new('EBox::Model::Manager');
    }

    return $_instance;
}

sub warnIfIdIsUsed
{
    my ($self, $modelName, $id) = @_;

    my @tablesUsing;
    if ((exists $modelsUsingId{$modelName}) and $modelsUsingId{$modelName}) {
        my $idsByModelName =  $modelsUsingId{$modelName};
        if ((exists $idsByModelName->{$id}) and  $idsByModelName->{$id}) {
            @tablesUsing = @{ $idsByModelName->{$id}};
        }
    }

    if (@tablesUsing) {
        throw EBox::Exceptions::DataInUse(
                ('The data you are removing is being used by
                    the following sections:') . "@tablesUsing");
    }
}

sub warnOnChangeOnId
{
    my ($self, $contextName, $id, $changedElements, $oldRow) = @_;
    # we will not test the data table callback for now
    return $self->warnIfIdIsUsed($contextName, $id);
}

sub removeRowsUsingId
{
    my ($self, $contextName, $id) = @_;
    # do nothing
}

1;
