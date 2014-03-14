# Copyright (C) 2012-2013 Zentyal S.L.
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

# Class: EBox::Exceptions::UnwillingToPerform
#
#   Internal exception raised when the requested action is
#   impossible to be performed
#

use strict;
use warnings;

package EBox::Exceptions::UnwillingToPerform;

use base 'EBox::Exceptions::External';

use EBox::Gettext;

sub new
{
    my $class = shift;
    my %opts = @_;

    my $reason = defined $opts{reason} ? $opts{reason} : __('Unknown');
    my $error = __x('The requested action cannot be performed. Reason: {r}',
                    r => $reason);

    local $Error::Depth = defined $Error::Depth ? $Error::Depth + 1 : 1;
    local $Error::Debug = 1;

    $Log::Log4perl::caller_depth++;
    my $self = $class->SUPER::new($error, @_);
    $Log::Log4perl::caller_depth--;

    bless ($self, $class);
    return $self;
}

1;
