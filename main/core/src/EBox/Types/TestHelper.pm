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

# this package is for helpinmg in creating types unit tests

package EBox::Types::TestHelper;

use Test::More;
use Test::Exception;
use TryCatch;
use EBox::TestStub;

sub setupFakes
{
    EBox::TestStub::fake();
}

# count as 3 tests
sub cloneTest
{
    my ($instance) = @_;

    my $clone;
    lives_ok {
        $clone = $instance->clone();
    } 'cloning instance';

    is_deeply $instance, $clone,
        'checking tht data is the same in original and clone';
    is ref $instance, ref $clone,
        'checking that original and clone are of the same class';
}

sub defaultValueOk
{
    my ($class, $value, %params) = @_;

    my @extraNewParams = exists $params{extraNewParams} ?
                                   @{ $params{extraNewParams} } :
                                   ();

    my $instance;
    try {
        $instance = $class->new(
                               fieldName => 'defaultValueTest',
                               printableName=>'defaultValueTest',
                               defaultValue => $value,
                               @extraNewParams
                              );
    } catch ($e) {
        diag "$e";
        fail "Cannot create a instance of $class with default value $value";
    }

    is $instance->value(),
        $value,
       "Checking that default value $value was set correctly for $class";
}

sub createOk
{
    return _createTest(1, @_);
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
    } else {
        $testName = "Creation of $class";
    }

    my $failed = 0;

    my %params = @p;
    my $noSetCheck = delete $params{noSetCheck};

    my $instance;
    try {
        $instance = $class->new(%params);
    } catch {
        $failed =1;

        if ($wantSuccess) {
            fail $testName;
        } else {
            pass $testName;
        }
    }

    $failed and
        return $instance;

    try {
        unless ($noSetCheck) {
            $instance->setValue($instance->printableValue);
        }
    } catch ($e) {
        $failed = 1;

        diag $e;

        if ($wantSuccess) {
            fail $testName;
        } else {
            pass $testName;
        }
    }

    $failed and
        return $instance;

    if ($wantSuccess) {
        pass $testName;
    } else {
        fail $testName;
    }

    return $instance;
}

1;
