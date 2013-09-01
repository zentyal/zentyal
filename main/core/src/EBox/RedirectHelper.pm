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

# Class: EBox::RedirectHelper
#
#       This class exposes the interface to be implemented by those
#       modules willing to redirect its HTTP interface to its
#       applications from Zentyal Remote.
#
use strict;
use warnings;

package EBox::RedirectHelper;

sub new
{
    my $class = shift;
    my $self = {};
    bless($self, $class);
    return $self;
}

# Method: redirectionConf
#
#    Return the proxy redirection definition. It should match the
#    following description:
#
#    An array ref with the following hash ref:
#
#    url - the service name
#    target - the HTTP server where the proxy will redirect the
#             requests
#
#    absolute_url_patterns - an array ref with the absolute URL
#                            patterns the HTTP server will expect from
#                            its clients
#
#    referer_patterns - an array ref with the redirections to be done
#                       once the referer has the given values. It usually
#                       applies when the request is /
#
#    query_string_patterns - an array ref with the redirections to be
#                            done based on the query string. It
#                            usually applies when the request is /
#
# Example:
#
#     [ { url => 'apache',
#         target => 'http://localhost:80',
#         absolute_url_patterns => [ "index.html$", "^/status" ],
#         referer_patterns => [ "\.html$" ],
#         query_string_patterns => [ "^ohyeah=" ] } ]
#
sub redirectionConf
{
    return []
}


1;
