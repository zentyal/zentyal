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

use constant TRACE_FILE => '/var/lib/zentyal/tmp/trace';

# Procedure: storeTrace
#
#     Store a trace using Storable serialiser
#
# Parameters:
#
#     trace - <Devel::StackTrace> the trace to store
#
sub storeTrace
{
    my ($trace) = @_;

    local $Storable::forgive_me = 1;
    Storable::store($trace, TRACE_FILE);
}

# Procedure: retrieveTrace
#
#     Retrieve a stored trace
#
# Returns:
#
#     <Devel::StackTrace> - the trace retrieved
#
#     undef - if there is no trace
#
sub retrieveTrace
{
    my ($trace) = @_;

    if (-e TRACE_FILE) {
        my $trace = Storable::retrieve(TRACE_FILE);
        unlink(TRACE_FILE);
        return $trace;
    }
    return undef;
}

1;
