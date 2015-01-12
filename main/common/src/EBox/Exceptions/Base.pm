# Copyright (C) 2004-2007 Warp Networks S.L.
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

package EBox::Exceptions::Base;

use EBox;
use EBox::Gettext;

use Log::Log4perl;
use Devel::StackTrace;

use overload (
    '""'     => 'stringify',
    fallback => 1
);

# Constructor: new
#
#      Create a new exception base class
#
# Parameters:
#
#      text - String the exception text (Positional)
#
#      Named parameters:
#
#         silent - Boolean indicating not logging when it sets to true
#
sub new # (text)
{
    my $class = shift;
    my $text = shift;
    my (%opts) = @_;

    my $self = { text => $text };
    if (exists $opts{silent} and $opts{silent}) {
        $self->{silent} = 1;
    } else {
        $self->{silent} = 0;
    }

    # Store the trace
    $self->{trace} = new Devel::StackTrace(ignore_class => __PACKAGE__,
                                           message => $text,
                                           no_refs => 1);

    bless ($self, $class);
    return $self;
}

sub text
{
    my ($self) = @_;

    return $self->{text};
}

sub stringify
{
    my ($self) = @_;
    return $self->{text} ? $self->{text} : 'Died';
}

# Method: stacktrace
#
# Returns:
#
#   String - the exception text appended using 'at' with the trace as
#            string
#
sub stacktrace
{
    my ($self) = @_;

    my $msg = $self->{text};
    $msg .= ' at ';
    $msg .= $self->{trace}->as_string();

    return $msg;
}

# Method: trace
#
# Returns:
#
#     <Devel::StackTrace> - the stack trace obj when the exception was
#                           created
#
sub trace
{
    my ($self) = @_;

    return $self->{trace};
}

sub throw
{
    my $self = shift;

    unless (ref $self) {
        $self = $self->new(@_);
    }

    die $self;
}

sub toStderr
{
    my ($self) = @_;
    print STDERR "[EBox::Exceptions] ". $self->stringify() ."\n";
}

sub _logfunc # (logger, msg)
{
    my ($self, $logger, $msg) = @_;
    $logger->debug($msg);
}

sub log
{
    my ($self) = @_;
    if ($self->{silent}) {
        return;
    }

    my $log = EBox::logger();
    $Log::Log4perl::caller_depth +=3;
    my $stacktrace = $self->stacktrace();
    if ($stacktrace =~ m/^\s*EBox::.*Auth::.*$/m) {
        # only log first line to avoid reveal passwords
        $stacktrace  = (split "\n", $stacktrace)[0];
    }

    $self->_logfunc($log, $stacktrace);
    $Log::Log4perl::caller_depth -=3;
}

sub setSilent
{
    my ($self, $silent) = @_;
    $self->{silent} = $silent;
}

# Function: rethrowSilently
#
#   Throws again the error as a silently exception. Can also be called as
#   exception object method
#
#  Parameters: 
#         error - the error, can be a ebox ecception, a error object or a
#                 error string 
#
#  Raises:
#      - an appropiate EBox::Exception with the silently option
sub rethrowSilently
{
    my ($error) = @_;
    if (not defined $error) {
        EBox::Exception::MissingArgument('Exception to rethrown');
    }

    my $class = ref $error;
    if (not $class) {
        EBox::Exceptions::External->throw($error, silent => 1);
    } elsif ($error->isa('EBox::Exceptions::Base')) {
        $error->setSilent(1);
        $error->throw();
    } else {
        EBox::Exceptions::Internal->throw("$error", silent => 1);
    }
}

1;
