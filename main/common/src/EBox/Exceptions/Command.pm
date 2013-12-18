# Copyright (C) 2006-2007 Warp Networks S.L.
# Copyright (C) 2008-2013 Zentyal S.L.
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

# Class: EBox::Exceptions::Command
#
#       Internal exception raised when a command has failed, that is,
#       its returned value is different from zero.
#

use strict;
use warnings;

package EBox::Exceptions::Command;

use base 'EBox::Exceptions::Internal';

use Params::Validate qw(validate SCALAR ARRAYREF);

# Group: Public methods

# Constructor: new
#
#     This exception is taken to say the type of an argument is not
#     the correct one.
#
# Parameters:
#
#     (NAMED)
#     cmd  - String the launched command
#     output - array ref the standard output, every component is a line
#              *(Optional)* Default value: empty array
#     error  - array ref the standard error, every component is a line
#              *(Optional)* Default value: empty array
#     exitValue - Integer the returned value from the command
#
#     cmdType - String the command type. *(Optional)* Default value:
#     'eBox command'
#
#
# Returns:
#
#     The newly created <EBox::Exceptions::InvalidType> exception
#
sub new
{
  my $class  = shift @_;
  validate (@_, {
		 cmd => { type => SCALAR },
		 output => { type => ARRAYREF, default => []},
		 error =>  { type => ARRAYREF, default => []},
		 exitValue => { type => SCALAR },
		 cmdType => { type => SCALAR,  default => 'eBox command'},
		}
	   );

  my %params = @_;
  my $self;

  my $cmd    = $params{cmd};
  my $output = $params{output} ;
  my $error = $params{error};
  my $exitValue = $params{exitValue};
  my $cmdType = $params{cmdType};

  local $Error::Depth = defined $Error::Depth ? $Error::Depth + 1 : 1;
  local $Error::Debug = 1;

# we need this ugly workaround because Exceptions::Internal constructor logs the error parameter
  my $errorMsg = _errorMsg($cmdType, $cmd, $error, $output, $exitValue);

  $Log::Log4perl::caller_depth += 1;
  $self = $class->SUPER::new($errorMsg);
  $Log::Log4perl::caller_depth -= 1;

  $self->{cmd}    = $cmd;
  $self->{output} = $output;
  $self->{error}  = $error;
  $self->{exitValue} = $exitValue;

  bless ($self, $class);
  return $self;
}

# Method: cmd
#
#       Return the command string
#
# Returns:
#
#       String - the command string
#
sub cmd
{
  my ($self) = @_;
  return $self->{cmd};
}

# Method: output
#
#       Return the standard output in an array
#
# Returns:
#
#       Array ref - the standard output, one line per element
#
sub output
{
  my ($self) = @_;
  return $self->{output};
}

# Method: error
#
#       Return the standard error in an array
#
# Returns:
#
#       Array ref - the standard error, one line per element
#
sub error
{
  my ($self) = @_;
  return $self->{error};
}

# Method: exitValue
#
#       Return the exit value
#
# Returns:
#
#       Int - the exit value
#
sub exitValue
{
  my ($self) = @_;
  return $self->{exitValue};
}

# Group: Private methods
sub _errorMsg
{
  my ($cmdType, $cmd, $error, $output, $exitValue) = @_;
  my $errorStr = join ' ', @{ $error };
  my $outputStr = join ' ', @{ $output };

  $cmdType = '' unless defined($cmdType);

  return "$cmdType $cmd failed. \nError output: $errorStr\nCommand output: $outputStr. \nExit value: $exitValue";
}

1;
