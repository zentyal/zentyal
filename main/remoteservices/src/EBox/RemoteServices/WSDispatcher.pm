#!/usr/bin/perl -w

# Copyright (C) 2008-2014 Zentyal S.L.
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

package EBox::RemoteServices::WSDispatcher;

# Class: EBox::RemoteServices::WSDispatcher
#
#      A SOAP::Lite handle called by zentyal.psgi everytime
#      this SOAP service is required.
#

use Plack::Request;
use SOAP::Transport::HTTP::Plack;

my $server = new SOAP::Transport::HTTP::Plack();

sub psgiApp
{
    my ($env) = @_;

    return $server->dispatch_with(
        {
            'urn:EBox/Services/Jobs' => 'EBox::RemoteServices::Server::JobReceiver',
        }
       )->handler(new Plack::Request($env));
}

1;
