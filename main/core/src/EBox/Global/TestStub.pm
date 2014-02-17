# Copyright (C) 2006-2007 Warp Networks S.L.
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
use strict;
use warnings;

package EBox::Global::TestStub;

use Test::MockObject;
use File::Slurp;
use Params::Validate;
use EBox::Global;
use EBox::TestStub;
use EBox::Config::TestStub;
use EBox::Test::RedisMock;

my $moduleDir = "/tmp/zentyal-modules-test-$$/";

sub setModule
{
    my ($name, $package, @depends) = @_;

    my $yaml = "class: $package\n";
    if (@depends) {
        $yaml .= "depends:\n";
        foreach my $dep (@depends) {
            $yaml .= "    - $dep\n";
        }
    }

    EBox::Config::TestStub::fake(modules => $moduleDir);
    system ("mkdir -p $moduleDir");

    write_file("${moduleDir}${name}.yaml", $yaml);
}

sub clear
{
    system ("rm -rf $moduleDir");
}

sub setAllModules
{
    my (%modulesByName) = @_;

    while (my ($name, $module) = each %modulesByName) {
        setModule($name, $module);
    }
}

# Procedure: fake
#
#     Fake Global class using a RedisMock
#
#     The installed modules are the ones available in schemas
#     directory passed in ZENTYAL_MODULES_SCHEMAS environment variable
#
sub fake
{
    my $tmpConfDir = '/tmp/zentyal-test-conf/';
    system ("rm -rf $tmpConfDir") if ( -e $tmpConfDir);
    ($? == 0) or die ("Can not clean temporally test dir $tmpConfDir");
    mkdir ($tmpConfDir);
    ($? == 0) or die ("Can not create the temporally test dir $tmpConfDir");
    my $tmpTmpDir = "${tmpConfDir}tmp";
    mkdir ($tmpTmpDir);
    ($? == 0) or die ("Can not create the temporally test tmp dir $tmpTmpDir");

    my $tmpEtcDir = '/tmp/zentyal-test-etc/';
    system ("rm -rf $tmpEtcDir") if ( -e $tmpEtcDir);
    ($? == 0) or die ("Can not clean temporally test dir $tmpEtcDir");
    mkdir ($tmpEtcDir);
    ($? == 0) or die ("Can not create the temporally test dir $tmpEtcDir");

    my @confdirs = `find . -name conf`;
    chomp (@confdirs);
    for my $dir (@confdirs) {
        system ("cp -r $dir/* $tmpEtcDir");
    }

    EBox::TestStub::fake();
    EBox::Config::TestStub::fake(
        modules => $ENV{ZENTYAL_MODULES_SCHEMAS},
        conf => $tmpConfDir,
        etc => $tmpEtcDir,
        tmp => $tmpTmpDir,
        user => 'nobody'
    );
    EBox::Global->new(1, redis => EBox::Test::RedisMock->new());
    *EBox::GlobalImpl::modExists = \&EBox::GlobalImpl::_className;
    # dont run scripts from zentyal directories
    *EBox::GlobalImpl::_runExecFromDir = sub {};
}

# only for interface completion
sub unfake
{
}

1;
