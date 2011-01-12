# Copyright (C) 2009 EBox Technologies S.L.
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


#

use strict;
use warnings;

use Test::More (tests => 59);
use Test::MockObject;
use Test::Exception;

use lib  '../..';
use_ok('EBox::Global');

sortOneModuleByDependenciesTest();
sortTwoModulesByDependenciesTest();
sortModulesByDependenciesTest();

sub sortModulesByDependenciesTest
{

    # caution! method does not resolve cyclic dependencies
    diag 'Testing sortModulesByDependencies with 40 modules';
    my %modDependencies =  (
        0 => [30],
        1 => [4, 5],
        6 => [1, 15],
        8 => [4],
        13 => [6, 15, 190], # unavaialble dpendenciy and correct dpednecies
        17 => [19],
        19 => [1],
        25 => [19],
        30 => [40],
        38 => [74],  # unavailable dpendency
        40 => [12],
       );

    _checkSortModulesByDependencies(\%modDependencies);
}



sub sortOneModuleByDependenciesTest
{
    my @modules;
    my $dependenciesMethod = 'dependencies';


    diag 'Testing sortModulesByDependencies with one module without dependencies';
    my %modDependencies =  (
        0 => [],
                           );
    _checkSortModulesByDependencies(\%modDependencies);


    diag 'Testing sortModulesByDependencies with one module with unsolved dpendnecies';
    %modDependencies =  (
        0 => [1],
                           );

    _checkSortModulesByDependencies(\%modDependencies);


}


sub sortTwoModulesByDependenciesTest
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
           EBox::Global->sortModulesByDependencies(
                                 \@modules, $dependenciesMethod) 
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


1;
