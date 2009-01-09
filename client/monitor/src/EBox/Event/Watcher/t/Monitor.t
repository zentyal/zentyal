#!/usr/bin/perl -w

# Copyright (C) 2008 eBox Technologies S.L.
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

# A module to test Monitor module

use Test::More qw(no_plan);
use Test::Exception;

my @trueCases = (
    'Host ebox-ubuntu-0.11.99, plugin load type load: Data source "midterm" is currently 0.490000. That is below the failure threshold of 1.000000.',
    'Host ebox-ubuntu-0.11.99, plugin load type load: Data source "shortterm" is currently 0.490000. That is below the failure threshold of 1.000000.',
);

my @falseCases = (
    'Host ebox-ubuntu-0.11.99, plugin load type load: Data source "longterm" is currently 0.490000. That is below the failure threshold of 1.000000.',
    'Host ebox-ubuntu-0.11.99, plugin cpu (instance 0) type cpu (instance user): Data source "value" is currently 0.000000. That is below the warning threshold of 2.000000.',
);

BEGIN {
    diag ( 'Starting EBox::Event::Watcher::Monitor test' );
    use_ok( 'EBox::Event::Watcher::Monitor' )
      or die;
}

my $watcher;
lives_ok {
    $watcher = EBox::Event::Watcher::Monitor->new();
} 'Creating a monitor watcher';

throws_ok {
    $watcher->_filterDataSource('plugin foobar type foobar Data Source "value"');
} 'EBox::Exceptions::DataNotFound', 'Filter a not good measure';

throws_ok {
    $watcher->_filterDataSource('gadfafda');
} 'EBox::Exceptions::MissingArgument', 'Filter an impossible log message';

foreach my $case (@trueCases) {
    ok($watcher->_filterDataSource($case));
}

foreach my $case (@falseCases) {
    ok(! $watcher->_filterDataSource($case));
}

push(@trueCases, @falseCases);
foreach my $case (@trueCases) {
    ok($watcher->_i18n('failure', $case));
    print $watcher->_i18n('error', $case) . $/;
}

1;
