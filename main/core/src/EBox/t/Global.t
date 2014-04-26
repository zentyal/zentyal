# Copyright (C) 2009-2014 Zentyal S.L.
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

package EBox::Global::Test;

use parent 'Test::Class';

use Test::More;
use Test::MockObject;
use Test::Exception;

use EBox::Global::TestStub;

sub setUpConfiguration : Test(startup)
{
    EBox::Global::TestStub::fake();
}

sub global_use_ok : Test(startup => 1) {
    use_ok('EBox::Global');
}

sub sortModulesByDependenciesTest : Test(42)
{
    # caution! method does not resolve cyclic dependencies
    diag 'Testing sortModulesByDependencies with 40 modules';
    my %modDependencies =  (
        0 => [30],
        1 => [4, 5],
        6 => [1, 15],
        8 => [4],
        13 => [6, 15, 190], # unavaialble dependenciy and correct depedencies
        17 => [19],
        19 => [1],
        25 => [19],
        30 => [40],
        38 => [74],  # unavailable dependency
        40 => [12],
       );

    _checkSortModulesByDependencies(\%modDependencies);
}

sub sortOneModuleByDependenciesTest : Test(4)
{
    my @modules;
    my $dependenciesMethod = 'dependencies';

    diag 'Testing sortModulesByDependencies with one module without dependencies';
    my %modDependencies = (0 => []);
    _checkSortModulesByDependencies(\%modDependencies);

    diag 'Testing sortModulesByDependencies with one module with unsolved dependencies';
    %modDependencies = (0 => [1]);

    _checkSortModulesByDependencies(\%modDependencies);
}

sub sortTwoModulesByDependenciesTest : Test(12)
{
    my @modules;
    my $dependenciesMethod = 'dependencies';

    diag 'Testing sortModulesByDependencies with two modules: without dependencies and without all non-transitive dependencies combinations';
    my %modDependencies =  (
        0 => [],
        1 => [],
                           );
    _checkSortModulesByDependencies(\%modDependencies);

    %modDependencies =  (
        0 => [1],
        1 => [],
                           );

    _checkSortModulesByDependencies(\%modDependencies);

    %modDependencies =  (
        0 => [],
        1 => [0],
                           );
    _checkSortModulesByDependencies(\%modDependencies);

    diag 'Testing sortModulesByDependencies with two modules with one avaialble and one uanvailable dpendency';
    %modDependencies =  (
        0 => [],
        1 => [0, 5],
                           );
    _checkSortModulesByDependencies(\%modDependencies);
}


# modules name are numerical, no listed numbers are created as modules withotu dpeendencies
sub _checkSortModulesByDependencies
{
    my ($modDependencies_r) = @_;
    my @modules;
    my $dependenciesMethod = 'dependencies';

    my %modDependencies =  %{$modDependencies_r};
    my $maxMod = 0;
    foreach (keys %modDependencies) {
        if ($_ > $maxMod) {
            $maxMod = $_;
        }
    }

    foreach (0 .. $maxMod) {
        my $modName = $_;
        my $mod = Test::MockObject->new();
        $mod->set_always('name', $modName);
        my $dependencies_r = exists $modDependencies{$modName} ?
                                     $modDependencies{$modName} : [];
        $mod->set_always($dependenciesMethod, $dependencies_r);
        push @modules, $mod;
    }
    # end setup

    my @sortedModules;
    lives_ok {
        @sortedModules = @{
           EBox::Global->sortModulesByDependencies(\@modules, $dependenciesMethod)
        };
    } 'Sorting modules by dependencies';

    diag 'checking sorted by dependencies module list';
    my  %seen;
    foreach my $mod (@sortedModules) {
        my $name = $mod->name();
        my @unresolvedDependencies = map {
            $seen{$_} ? $_ : ()
        } @{ $mod->$dependenciesMethod() };

        if (@unresolvedDependencies) {
            fail(
"Module $name was listed before the dependencies: @unresolvedDependencies"
            );
        } else {
            pass "Module $name was listed after its available dependencies";
        }
    }
}

sub test_addModuleToSave : Test(7)
{
    my ($self) = @_;

    my $global = EBox::Global->getInstance();

    is_deeply($global->get_list('post_save_modules'), [], 'Empty post_save');
    lives_ok {
        $global->addModuleToPostSave('dns');
    } 'Adding a module to post-save process';
    is_deeply($global->get_list('post_save_modules'), ['dns'], 'A module in post_save');
    lives_ok {
        $global->addModuleToPostSave('module');
    } 'Adding another module to post-save process';
    is_deeply($global->get_list('post_save_modules'), ['dns', 'module'], 'Two modules in post_save');
    lives_ok {
        $global->addModuleToPostSave('module');
    } 'Adding the same module to post-save process';
    is_deeply($global->get_list('post_save_modules'), ['dns', 'module'], 'The same two modules in post_save');
    $global->unset('post_save_modules');
}

1;

END {
    EBox::Global::Test->runtests();
}
