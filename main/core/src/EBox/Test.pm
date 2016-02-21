# Copyright (C) 2004-2007 Warp Networks S.L.
# Copyright (C) 2008-2013 Zentyal S.L.
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

package EBox::Test;

use base 'Exporter';

# package: EBox::Test
#
#  Contains specifically-ebox checks and helper.
#
# deprecated:
#     activateEBoxTestStubs fakeModule setConfig setConfigKeys
#     this was moved to EBox::TestStub

use Test::More;
use Test::Builder;

use TryCatch;
use Params::Validate;

our @EXPORT_OK = ('checkModuleInstantiation', @deprecatedSubs);
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

my $Test = Test::Builder->new;

# Function: checkModuleInstantiation
#
#    Checks we can use the module package correctly (like Test::More::use_ok) and that we can instantiate correctly using the methods from EBox::Global.
#   That counts as 1 test for the plan.
#
#
# Parameters:
#         $moduleName    - name of the module
#         $modulePackage - package of the module
#
# Usage example:
#    checkModuleInstantiation('dhcp', 'EBox::DHCP');
#
sub checkModuleInstantiation
{
    my ($moduleName, $modulePackage) = @_;
    validate_pos(@_, 1, 1);

    eval "use $modulePackage";
    if ($@) {
        $Test->ok(0, "$modulePackage failed to load: $@");
        return;
    }

    my $global = EBox::Global->getInstance();
    defined $global or die "Cannot get a instance of the global module";

    my $instance;
    my $modInstanceError = 0;

    try {
        $instance = $global->modInstance($moduleName);
    } catch {
        $modInstanceError = 1;
    }

    if ($modInstanceError or !defined $instance) {
        $Test->ok(0, "Cannot create an instance of the EBox's module $moduleName");
        return;
    }

    my $refType = ref $instance;

    if ($refType eq $modulePackage) {
        $Test->ok(1, "$moduleName instantiated correctly");
    } elsif (defined $refType) {
        $Test->ok(0, "The instance returned of $moduleName is not of type $modulePackage instead is a $refType");
    } else {
        $Test->ok(0, "The instance returned of $moduleName is not a blessed reference");
    }
}

sub checkModels
{
    my ($mod, @modelsNames) = @_;

    my @failedModels;
    foreach my $name (@modelsNames) {
        try {
            $mod->model($name);
        } catch {
            push @failedModels, $name;
        }
    }

    my $modName = $mod->name();
    if (@failedModels) {
        $Test->ok(0, "Module $modName failed when loading the models: @failedModels");
    } else {
        $Test->ok(1, "Module $modName loaded the models");
    }
}

sub checkComposites
{
    my ($mod, @compositesNames) = @_;

    my @failedComposites;
    foreach my $name (@compositesNames) {
        try {
            $mod->composite($name);
        } catch {
            push @failedComposites, $name;
        }
    }

    my $modName = $mod->name();
    if (@failedComposites) {
        $Test->ok(0, "Module $modName failed when loading the composites: @failedComposites");
    } else {
        $Test->ok(1, "Module $modName loaded the composites");
    }
}

1;
