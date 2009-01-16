#!/usr/bin/perl -w

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

package EBox::RemoteServices::WSDispatcher;

# Class: EBox::RemoteServices::WSDispatcher
#
#      A SOAP::Lite handle called by apache-perl (mod_perl) everytime
#      a SOAP service is required.
#

use SOAP::Transport::HTTP;

use strict;
use warnings;

my $server = SOAP::Transport::HTTP::Apache
  ->dispatch_with(
      { 'urn:EBox/Services/Jobs' => 'EBox::RemoteServices::Server::JobReceiver' }
     );

# Method: handler
#
#     Handle the HTTP request
#
sub handler
{
    # Currently connection is just once basis
    $server->handler(@_);
}

1;
