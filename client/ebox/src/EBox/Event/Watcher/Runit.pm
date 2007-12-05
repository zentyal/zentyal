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

package EBox::Event::Watcher::Runit;

# Class: EBox::Event::Watcher::Runit
#
#   This class is a watcher which checks if a service has been
#   restarted certain times ($restart_max) within a time interval
#   ($time_interval).
#
#   These two configuration values can be set at: runitfinisher.conf
#   file
#

use base 'EBox::Event::Watcher::Base';

use constant WILD_SERVICES => EBox::Config::log() . 'runit/wild-services.log';

# eBox uses
use EBox::Event;
use EBox::Event::Watcher::Base;
use EBox::Exceptions::Internal;
use EBox::Gettext;
use EBox::Service;

# Core modules
use Error qw(:try);
use Fcntl qw(:flock); # Import LOCK * constants

# Group: Public methods

# Constructor: new
#
#        The constructor for <EBox::Event::Watcher::Runit>
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
#        <EBox::Event::Watcher::Runit> - the newly created object
#
sub new
  {

      my ($class) = @_;

      my $self = $class->SUPER::new(
                                    period      => 60,
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
#        Check if any service is being restarted many times within a
#        time interval.
#
# Overrides:
#
#        <EBox::Event::Watcher::Base::run>
#
# Returns:
#
#        undef - if no services are out of control (Chemical
#        Brothers!)
#
#        array ref - <EBox::Event> an event is sent when some service
#        is out of control
#
sub run
  {

      my ($self) = @_;

      # The wild services are stored within a file with the following
      # format:
      # wildService1\twildService2\twildService3

      if ( -f WILD_SERVICES ) {
      # Check if any service has been left
          open(my $wildServicesFile, '+<', WILD_SERVICES) or
            throw EBox::Exceptions::Internal('Cannot open for read/writing file ' .
                                             WILD_SERVICES . " : $!");

          my $line;
          try {
              # Lock the file for reading/writing
              flock( $wildServicesFile, LOCK_EX );
              $line = <$wildServicesFile>;
              # Truncate the file
              truncate ( $wildServicesFile, 0 );
          } finally {
              # Unlock the file
              flock( $wildServicesFile, LOCK_UN );
              close ( $wildServicesFile );
          };

          if ( defined ( $line )) {
              chomp($line);
              my @wildServices = split ( '\t', $line);
              if ( scalar ( @wildServices ) > 0 ) {
                  my @events = ();
                  my ( $restartMax, $timeInterval ) = ( EBox::Config::configkey('restart_max'),
                                                        EBox::Config::configkey('time_interval') );
                  foreach my $wildService (@wildServices) {
                      push ( @events, new EBox::Event(
                                   message => __x('The service {service} has been restarted ' .
                                                  '{restart} times in {time} seconds and it ' .
                                                  'has been stopped',
                                                  service => $wildService,
                                                  restart => $restartMax,
                                                  time    => $timeInterval,
                                                  ),
                                   level   => 'error',
                                                     ));
                  }
                  return \@events;
              }
          }
      }

      return undef;

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

      return __('Service');

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

      return __('Check if any service has been restarted many ' .
                ' times in a time interval');

  }


1;
