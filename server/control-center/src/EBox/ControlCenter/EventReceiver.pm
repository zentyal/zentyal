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

package EBox::ControlCenter::EventReceiver;

# Package: EBox::ControlCenter::EventReceiver
#
#       The public API for the Control Center event receiver module
#
use strict;
use warnings;

use vars qw(@INC);

BEGIN
  {

      @INC = qw(/usr/share/Perl5);

      use EBox;
      use EBox::Event;
      use EBox::Exceptions::MissingArgument;
      use Data::Dumper;

  }

# Group: Public API

# Procedure: informEvent
#
#      Get an event from an eBox and currently log out to a file
#
# Parameters:
#
#      eBoxCN - String the eBox common name within this control center
#      event - <EBox::Event> the event which is informed the eBox
#
# Returns:
#
#      boolean - indicating if the event has been successfully
#      received
#
sub informEvent
  {

      my ($className, $eBoxCN, $event) = @_;

      my $exc = undef;

      # Since there is an authentication process we can assume the
      # correctness for this eBox
      unless ( defined ( $eBoxCN )) {
          _launchException( new EBox::Exceptions::MissingArgument('eBoxCN'));
      }
      unless ( defined ( $event )) {
          _launchException( new EBox::Exceptions::MissingArgument('event'));
      }
      unless ( $event->isa('EBox::Event') ){
          _launchException( new EBox::Exceptions::InvalidType('event',
                                                              'EBox::Event'));
      }

      EBox::info("$eBoxCN has sent the event " . Dumper($event));

      return 1;

  }

# Group: Private API

# Procedure to launch the exception exc. It never returns.
sub _launchException # (exc)
  {

      my ($exc) = @_;

      die SOAP::Fault->faultstring($exc->stringify())
        ->faultdetail($exc);

  }

1;
