# Copyright (C) 2004-2007 Warp Networks S.L
# Copyright (C) 2008-2011 Zentyal S.L.
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

# Class: EBox::Exceptions::DataExists
#
#       External exception raised when a user wants to add an element
#       to eBox which already exists.

package EBox::Exceptions::DataExists;

use base 'EBox::Exceptions::External';
use EBox::Gettext;

sub new # (data=>string,  value=>string)
{
    my $class = shift;
    my %opts = @_;


    my $data = delete $opts{data};
    utf8::decode($data);
    my $value = delete $opts{value};

    my $error = __x("{data} {value} already exists.", data => $data,
                             value => $value);

    local $Error::Depth = $Error::Depth + 1;
    local $Error::Debug = 1;

    $Log::Log4perl::caller_depth++;
    $self = $class->SUPER::new($error, @_);
    $Log::Log4perl::caller_depth--;
    bless ($self, $class);
    return $self;
}
1;
