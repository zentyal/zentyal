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

package EBox::Exceptions::RESTRequest;

use base 'EBox::Exceptions::External';

use EBox::Gettext;


# Constructor: new
#
#      An exception raised when a RESTRequest fails
#
# Parameters:
#
#      text - the localisated text to show to the user
#
sub new
{
    my ($class, $text, %args) = @_;

    local $Error::Depth = defined $Error::Depth ? $Error::Depth + 1 : 1;
    local $Error::Debug = 1;

    $Log::Log4perl::caller_depth++;
    $self = $class->SUPER::new($text, %args);
    $Log::Log4perl::caller_depth--;
    bless ($self, $class);

    $self->{result} = $args{result};
    return $self;
}

sub result
{
    my ($self) = @_;
    return $self->{result};
}

sub code
{
    my ($self) = @_;
    return $self->{result}->code();
}

1;
