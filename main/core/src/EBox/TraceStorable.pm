# Copyright (C) 2014 Zentyal S.L.
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

package EBox::TraceStorable;

# Package: EBox::TraceStorable
#
#    Manage the traces from <EBox::Middleware::UnhandledError> to be
#    displayed between requests
#

use Storable;

use constant TRACE_PREFIX => '/var/lib/zentyal/tmp/trace-';

# Procedure: storeTrace
#
#     Store a trace using Storable serialiser
#
# Parameters:
#
#     trace - <Devel::StackTrace> the trace to store
#     env - Hash ref the PSGI environment
#
sub storeTrace
{
    my ($trace, $env) = @_;

    my $appName = _getAppName($env);
    return unless ($appName);
    my $traceFile = TRACE_PREFIX . $appName;

    local $Storable::forgive_me = 1;
    Storable::store($trace, $traceFile);
}

# Procedure: retrieveTrace
#
#     Retrieve a stored trace
#
# Parameters:
#
#     env - Hash ref the PSGI environment
#
# Returns:
#
#     <Devel::StackTrace> - the trace retrieved
#
#     undef - if there is no trace
#
sub retrieveTrace
{
    my ($env) = @_;

    my $appName = _getAppName($env);
    return undef unless ($appName);
    my $traceFile = TRACE_PREFIX . $appName;

    if (-f $traceFile) {
        my $trace = Storable::retrieve($traceFile);
        unlink($traceFile);
        return $trace;
    }
    return undef;
}

# Get the app name
sub _getAppName
{
    my ($env) = @_;

    if (exists $env->{'psgix.session'} and exists $env->{'psgix.session'}->{app}) {
        return $env->{'psgix.session'}->{app};
    } else {
        return undef;
    }
}

1;
