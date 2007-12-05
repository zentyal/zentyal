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

package EBox::Event::Watcher::State;

# Class: EBox::Watcher::State;
#
# This class is a watcher which checks current state from eBox
#
use base 'EBox::Event::Watcher::Base';

# Constants:
#
use constant ADMIN_SERVICE => 'apache-perl';

# eBox uses
use EBox::Event;
use EBox::Service;
use EBox::Global;
use EBox::Gettext;

# Group: Public methods

# Constructor: new
#
#        The constructor for <EBox::Event::Watcher::State>
#
# Overrides:
#
#        <EBox::Event::Watcher::Base::new>
#
# Parameters:
#
#        - non parameters
#
# Returns:
#
#        <EBox::Event::Watcher::State> - the newly created object
#
sub new
  {

      my ($class) = @_;

      my $self = $class->SUPER::new(
                                    period      => 10 * 60,
                                    domain      => 'ebox',
                                   );
      bless( $self, $class);

      return $self;

  }

# Method: ConfigurationMethod
#
# Overrides:
#
#       <EBox::Event::Component::ConfigurationMethod>
#
sub ConfigurationMethod
{
    return 'none';
}

# Method: run
#
#        Check that Apache-perl from Web UI is up and running.
#        Optionally, if the soap module is already installed, check if
#        the corresponding Apache-soap is up and running.
#
# Overrides:
#
#        <EBox::Event::Watcher::Base::run>
#
# Returns:
#
#        array ref - <EBox::Event> an info event is sent if eBox is up and
#        running and a fatal event if eBox is down
#
sub run
  {

      my ($self) = @_;

      # Check apache-perl is up and running
      my $up = EBox::Service::running(ADMIN_SERVICE);
      my $gl = EBox::Global->getInstance(1);
      if ( $gl->modExists('soap') ){
          my $soap = $gl->modInstance('soap');
          if ( $soap->enabled() ) {
              $up = $up and $soap->running();
          }
      }

      my $event;
      if ( $up ) {
          $event = new EBox::Event(
                                   message => __('eBox is up and running'),
                                   level   => 'info',
                                  );
      } else {
          $event = new EBox::Event(
                                   message => __('eBox is critically down'),
                                   level   => 'fatal',
                                  );
      }

      return [ $event ];

  }

# Group: Protected methods

# Method: _name
#
# Overrides:
#
#        <EBox::Event::Watcher::Base::_name>
#
# Returns:
#
#        String - the event watcher name
#
sub _name
  {

      return __('State');

  }

# Method: _description
#
# Overrides:
#
#        <EBox::Event::Watcher::Base::_description>
#
# Returns:
#
#        String - the event watcher detailed description
#
sub _description
  {

      return __('Check if eBox is currently up or down');

  }

1;
