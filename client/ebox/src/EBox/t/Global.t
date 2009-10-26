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

use Test::More (tests => 43);
use Test::MockObject;
use Test::Exception;

use lib  '../..';
use_ok('EBox::Global');

sortModulesByDependenciesTest();

sub sortModulesByDependenciesTest
{
    my @modules;
    my $dependenciesMethod = 'dependencies';

    # setup data for the test

    # caution! method does not resolve cyclic dependencies
    my %modDependencies =  (
        0 => [30],
        1 => [4, 5],
        6 => [1, 15],
        8 => [4],
        13 => [6, 15],
        17 => [19],
        19 => [1],
        25 => [19],
        30 => [40],
        40 => [12],
       );
    foreach (0 ..40) {
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
            pass "Module $name was listed after its dependencies";
        }
    }
    
}


1;
