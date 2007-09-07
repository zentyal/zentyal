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

package EBox::Event::Dispatcher::Log;

# Class: EBox::Dispatcher::Log
#
# This class is a dispatcher which sends the event to the eBox log.
#
use base 'EBox::Event::Dispatcher::Abstract';

################
# Dependencies
################
use Data::Dumper;

# eBox uses
use EBox;
use EBox::Gettext;
use EBox::Exceptions::MissingArgument;

# Group: Public methods

# Constructor: new
#
#        The constructor for <EBox::Event::Dispatcher::Log>
#
#
# Returns:
#
#        <EBox::Event::Dispatcher::Log> - the newly created object
#
sub new
  {

      my ($class) = @_;

      my $self = $class->SUPER::new('ebox');
      bless( $self, $class);

      return $self;

  }

# Method: ConfigurationMethod
#
# Overrides:
#
#       <EBox::Event::Dispatcher::Abstract::ConfigurationMethod>
#
sub ConfigurationMethod
  {

      return 'none';

  }

# Method: configured
#
# Overrides:
#
#        <EBox::Event::Dispatcher::Abstract::configured>
#
sub configured
  {

      return 'true';

  }

# Method: send
#
#        Send the event to the eBox log system
#
# Overrides:
#
#        <EBox::Event::Dispatcher::Abstract::send>
#
sub send
  {

      my ($self, $event) = @_;

      defined ( $event ) or
        throw EBox::Exceptions::MissingArgument('event');

      EBox::info(Dumper($event));

      return 1;

  }

# Group: Protected methods

# Method: _receiver
#
# Overrides:
#
#       <EBox::Event::Dispatcher::Abstract::_receiver
#
sub _receiver
  {

      return __('Log file');

  }

# Method: _name
#
# Overrides:
#
#       <EBox::Event::Dispatcher::Abstract::_name>
#
sub _name
  {

      return __('Log');

  }

1;
