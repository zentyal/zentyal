# Copyright (C) 2005-2007 Warp Networks S.L.
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

# Class: EBox::Exceptions::DeprecatedMethod
#
#       Internal exception raised when a deprecated method has been
#       called at runtime

package EBox::Exceptions::DeprecatedMethod;

use base 'EBox::Exceptions::Internal';

use Log::Log4perl;
use EBox::Gettext;

sub new
{
    my $class = shift;

    local $Error::Depth = defined $Error::Depth ? $Error::Depth + 3 : 3;
    local $Error::Debug = 1;

    my ($package, $filename, $line, $subroutine) = caller(2);

    # this is to avoid anonymous subroutines created by try/catch
    if ($subroutine eq 'main::__ANON__') {
        # check for try presence
        my ($idle1, $idle2, $idle3, $subroutine4th) = caller(4);
        if ($subroutine4th eq 'Error::subs::try') {
            ($package, $filename, $line, $subroutine) = caller(5);
        }

    }

    my $errorTxt =
        "Call to deprecated method $subroutine in $filename line $line";

    $Log::Log4perl::caller_depth += 3;
    $self = $class->SUPER::new($errorTxt);
    $Log::Log4perl::caller_depth -= 3;

    bless ($self, $class);

    return $self;
}

1;
