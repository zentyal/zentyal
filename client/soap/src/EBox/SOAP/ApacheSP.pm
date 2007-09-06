#!/usr/bin/perl -w

# Copyright (C) 2007 Warp Networks S.L.
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

package EBox::SOAP::ApacheSP;

# Class: EBox::SOAP::ApacheSP
#
#      A SOAP::Lite handle called by apache-perl (mod_perl) everytime
#      a SOAP service is required.
#

use SOAP::Transport::HTTP;

use strict;
use vars qw(@ISA);
use Data::Dumper;
use EBox::Config;
use EBox::Exceptions::Internal;

my $server = SOAP::Transport::HTTP::Apache
  -> objects_by_reference(qw(EBox::SOAP::Global))
  -> dispatch_to('/root/SOAP/Module', 'EBox::SOAP::Global');

sub handler
  {
    # Currently connection is just once basis
    _saveSession();
    $server->handler(@_);
  }

# Procedure: _saveSession
#
#     Save the SOAP session in a file
#     File structure: TIMESTAMP<NL><EOF>
#
sub _saveSession
  {

    my $sessionFile;
    open ($sessionFile, '>', EBox::Config->soapSession() )
      or EBox::Exceptions::Internal('Could not open ' .
				    EBox::Config->soapSession());

    print $sessionFile time() . $/;
    close($sessionFile);

  }

1;
