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

package EBox::TC;

use strict;
use warnings;

use EBox::Sudo qw( :all );
use Error qw( :try );

use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::Sudo::Command;

# Constants
use constant TC_CMD => '/sbin/tc';

# Constructor: new
#
#         Construct a new TC class which executes tc commands.
#
# Returns:
#
#         A recently created EBox::TC object
sub new
{
	my $class = shift;
	my $self = {};

	bless($self, $class);

	return $self;
}

# Method: tc
#
#       Execute tc command with options
#
# Parameters:
#
#       opts - options passed to tc
#
# Returns:
#
#       array ref - the output of iptables command in an array
#
# Exceptions:
#
#       <EBox::Exceptions::MissingArgument> - if no opts are passed
#       <EBox::Exceptions::Sudo::Command> - if tc does NOT properly
#
#
sub tc
{
	my ($self, $opts) = @_;

	throw EBox::Exceptions::MissingArgument( __('options') )
	  unless ($opts);

	try {
	  root( TC_CMD . " $opts");
	} catch EBox::Exceptions::Sudo::Command with {
	  # Catching exception from tc command
	  my $exception = shift;
	  if ( $exception->exitValue() == 2 ) {
	    # RTNETLINK answers: No such file or directory
	    # Trying to delete qdisc where nothing it is in
	    EBox::warn("No qdisc to remove");
	  }
	  else {
	    $exception->throw();
	  }
	  ;
	}

}

# Method: reset
#
#        Restore default values to Linux kernel to the given interface
#
# Parameters:
#
#        interface - interface to restore default
#
# Exceptions:
#
#       <EBox::Exceptions::MissingArgument> - if no interface is given
#
sub reset
  {

    my ($self, $interface) = @_;

    throw EBox::Exceptions::MissingArgument( __('Interface') )
      unless ($interface);

    $self->tc("qdisc del dev $interface root");

  }

# Method: execute
#
#        Execute a serie of tc commands
#
# Parameters:
#
#        tcCommands_ref - an array reference to a serie of tc commands
#        (each command have only the arguments)
#

sub execute # (tcCommands_ref)
  {

    my ($self, $tcCommands_ref) = @_;

    foreach my $tcCommand (@{$tcCommands_ref}) {
      EBox::info("tc $tcCommand");
      $self->tc( $tcCommand );
    }

  }

1;
