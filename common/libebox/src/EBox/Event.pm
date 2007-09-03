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

package EBox::Event;

# Class: EBox::Event
#
# This package is intended to support events. These events could be
# sent to the control center or it is also be recorded
#

use strict;
use warnings;

# Constants:
use constant LEVEL_VALUES => qw(info warn error fatal);

# eBox uses
use EBox::Config;

##################
# Dependencies
##################
use Perl6::Junction qw(any);

# Constructor: new
#
#      Create a new <EBox::Event> object
#
# Parameters:
#
#      message - String a i18ned message which will be dispatched
#
#      level - Enumerate the level of the event *(Optional)*
#              Possible values: 'info', 'warn', 'error' or 'fatal'.
#              Default: 'info'
#
#      dispatchTo - array ref containing the relative name for the
#      dispatchers you want to dispatch this event *(Optional)*
#      Default value: *any*, which means any available dispatcher will
#      dispatch the event. Concrete example: ControlCenter
#
#
#      - Named parameters
#
# Exceptions:
#
#      <EBox::Exceptions::MissingArgument> - thrown if any argument is
#      not present
#      <EBox::Exceptions::InvalidType> - thrown if any
#      argument is not from the correct type
#
sub new
  {

      my ($class, %args) = @_;

      my $self = {};
      bless ( $self, $class );

      defined ( $args{message} ) or
        throw EBox::Exceptions::MissingArgument('message');

      if ( defined ($args{level}) ) {
          unless ( $args{level} eq any(LEVEL_VALUES)) {
              throw EBox::Exceptions::InvalidType('level',
                        'enumerate type, possible values: ' . LEVEL_VALUES);
          }
      }
      $self->{message} = delete ( $args{message} );
      $self->{level} = delete ( $args{level} );
      $self->{level} = 'info' unless defined ( $self->{level} );
      $self->{dispatchers} = delete ( $args{dispatchTo} );
      $self->{dispatchers} = ['any'] unless defined ( $self->{dispatchers} );

      return $self;

  }

# Method: message
#
#     Accessor to the i18ned event message
#
# Returns:
#
#     String - the message
#
sub message
  {

      my ( $self ) = @_;

      return $self->{message};

  }

# Method: level
#
#     Accessor to the event level
#
# Returns:
#
#     Enum - the level can be 'info', 'warn', 'error' or 'fatal'
#
sub level
  {

      my ( $self ) = @_;

      return $self->{level};

  }

# Method: dispatchTo
#
#       Get the dispatcher to dispatch the message
#
# Returns:
#
#       array ref - the containing the relative name for the
#       dispatchers you want to dispatch this event
#
sub dispatchTo
  {

      my ($self) = @_;

      return $self->{dispatchers};

  }

1;
