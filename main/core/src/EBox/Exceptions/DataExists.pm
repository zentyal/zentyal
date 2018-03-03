# Copyright (C) 2004-2007 Warp Networks S.L.
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
# Class: EBox::Exceptions::DataExists
#
#       External exception raised when a user wants to add an element
#       to eBox which already exists.

package EBox::Exceptions::DataExists;

use base 'EBox::Exceptions::External';

use EBox::Gettext;

# Method: new
#
#  Parameters:
#    text - localized error text to be shown
#    data - Localized name for the repeated value, it will be used to build a
#           error text if text parameter is not given
#    value - Repeated value, it will be used to build  error text
#            if text parameter is not given
#
sub new
{
    my $class = shift;
    my %opts = @_;

    my $text = delete $opts{text};
    my $data = delete $opts{data};
    my $value = delete $opts{value};

    if (not $text) {
        $text = __x("{data} {value} already exists.", data => $data,
                             value => $value);
    }

    local $Error::Depth = defined $Error::Depth ? $Error::Depth + 1 : 1;
    local $Error::Debug = 1;

    $Log::Log4perl::caller_depth++;
    my $self = $class->SUPER::new($text, @_);
    $Log::Log4perl::caller_depth--;
    bless ($self, $class);
    return $self;
}

1;
