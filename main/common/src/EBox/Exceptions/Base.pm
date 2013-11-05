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

sub stacktrace
{
    my ($self) = @_;

    my $trace = new Devel::StackTrace();
    my $msg = $self->{text};
    $msg .= ' at ';
    $msg .= $trace->as_string();

    return $msg;
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
        # only log first line,  to avoid reveal passwords
        $stacktrace  = (split "\n", $stacktrace)[0];
    }

    $self->_logfunc($log, $stacktrace);
    $Log::Log4perl::caller_depth -=3;
}

1;
