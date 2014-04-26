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

package EBox::CGI::ShowTrace;

use parent qw(EBox::CGI::ClientBase);

use EBox::View::StackTrace;

sub _print
{
    my ($self) = @_;

    my $response = $self->response();
    my $trace = EBox::TraceStorable::retrieveTrace($self->request()->env());

    if ($trace) {
        $response->body($trace->as_html());
    } else {
        $self->SUPER::_print();
    }
}

1;
