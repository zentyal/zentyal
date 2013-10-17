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

package EBox::Exceptions::Base;

use base 'Error';

use EBox;
use EBox::Gettext;

use Log::Log4perl;

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

    local $Error::Depth = $Error::Depth + 1;
    local $Error::Debug = 1;

    $self = $class->SUPER::new(-text => $text, @_);
    if (exists $opts{silent} and $opts{silent}) {
        $self->{silent} = 1;
    } else {
        $self->{silent} = 0;
    }

    bless ($self, $class);
    return $self;
}

sub toStderr
{
    my $self = shift;
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
