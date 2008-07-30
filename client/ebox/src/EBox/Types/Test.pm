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

package EBox::Types::Test;

#

use strict;
use warnings;


use Test::More;
use Error qw(:try);



sub defaultValueOk
{
    my ($class, $value) = @_;
    my $instance;
    try {
        $instance = $class->new(
                               fieldName => 'defaultValueTest',
                               printableName=>'defaultValueTest',
                               defaultValue => $value
                              );
    }
    otherwise {
        fail "Cannot create a instance of $class with default value $value";
    };

    is $instance->value(),
        $value,
       "Checking that default value $value was set correctly for $class";
}

sub createOk
{
    _createTest(1, @_);
}

sub createFail
{
    _createTest(0, @_);
}

sub _createTest
{
    my ($wantSuccess, $class, @p) = @_;
    eval "use $class";
    if ($@) {
        die "Incorrect class $class: $@";
    }

    my $testName;
    if (@p % 2) {
        # odd number of elements
        $testName = pop @p;
    }
    else {
        $testName = "Creation of $class";
    }


    my $failed = 0;

    my %params = @p;

    my $instance;
    try {
        $instance = $class->new(%params);
    }
    otherwise {
        $failed =1;

        if ($wantSuccess) {
            fail $testName;
        }
        else {
            pass $testName
        }

    };

    $failed and
        return;
    
    
    try {
        $instance->setValue($instance->printableValue);
    }
    otherwise {
        $failed = 1;

        my $ex = shift @_;
        diag $ex;

        if ($wantSuccess) {
            fail $testName;
        }
        else {
            pass $testName
        }

    };

    $failed and
        return;

    if ($wantSuccess) {
        pass $testName;
    }
    else {
        fail  $testName
    }
}




1;
