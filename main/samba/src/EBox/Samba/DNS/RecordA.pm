# Copyright (C) 2013 Zentyal S.L.
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

use EBox::Exceptions::MissingArgument;

package EBox::Samba::DNS::RecordA;

use base 'EBox::Samba::DNS::Record';

sub new
{
    my $class = shift;
    my %params = @_;

    my $self = $class->SUPER::new(type => 'A');

    throw EBox::Exceptions::MissingArgument('data')
        unless defined $params{data};

    bless ($self, $class);
    $self->_decode($params{data});

    return $self;
}

sub _decode
{
    my ($self, $data) = @_;

    my ($a, $b, $c, $d) = unpack ('C C C C', $data);
    $self->{address} = "$a.$b.$c.$d";
}

sub address
{
    my ($self) = @_;

    return $self->{address};
}

1;
