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

package EBox::TestStub;

# Description: Test stub for EBox perl package.
# It changes the log process to use stdout instead of a file just writable by ebox
#

use EBox;
use Test::MockObject;
use Log::Log4perl qw(:easy);

my $logLevel;

sub fake
{
    my ($minLogLevel) = @_;
    (defined $minLogLevel) or $minLogLevel = 'debug';

    my %logLevelsByName = (
        'debug' => $DEBUG,
        'info'  => $INFO,
        'warn'  => $WARN,
        'error'  => $ERROR,
        'fatal'  => $FATAL,
    );

    (exists $logLevelsByName{$minLogLevel}) or die "Incorrect log level: $minLogLevel";
    $logLevel = $logLevelsByName{$minLogLevel};

    Test::MockObject->fake_module('EBox', logger => \&_mockedLogger);
}

sub unfake
{
    delete $INC{'EBox.pm'};
    {

        eval q{{no warnings 'redefine'; use EBox;}};
        ($@) and die "Error unfaking EBox: $@";
    }
}

my $loginit;

sub _mockedLogger
{
    my ($cat) = @_;

    defined($cat) or $cat = caller;
    unless ($loginit) {
        Log::Log4perl->easy_init({ level  => $logLevel, layout => '# [EBox log]%d %m%n' });
        $loginit = 1;
    }

    return Log::Log4perl->get_logger($cat);
}

1;
