# Copyright (C) 2011-2013 Zentyal S.L.
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

package EBox::Types::Action;

use base 'EBox::Types::MultiStateAction';

sub new
{
    my $class = shift;
    my %opts = @_;
    my $self = {@_};

    unless (defined $self->{enabled}) {
        $self->{enabled} = 1;
    }

    bless($self, $class);

    return $self;
}

sub action
{
    my ($self, $id) = @_;
    return $self;
}

1;
