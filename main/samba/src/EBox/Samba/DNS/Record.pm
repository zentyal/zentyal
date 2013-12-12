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

package EBox::Samba::DNS::Record;

sub new
{
    my ($class, %params) = @_;

    throw EBox::Exceptions::MissingArgument('type')
        unless defined $params{type};

    my $self = {};
    $self->{type} = $params{type};

    bless ($self, $class);

    return $self;
}

sub type
{
    my ($self) = @_;

    return $self->{type};
}

sub _decode_DNS_COUNT_NAME
{
    my ($self, $blob) = @_;

    my ($length,
        $labelCount,
        $rawName) = unpack ('C C a*', $blob);

    my @labels;
    for (my $i=1; $i <= $labelCount; $i++) {
        my ($labelLength, $label) = unpack ("C \@0C/a*", $rawName);
        push (@labels, $label);
        $rawName = substr ($rawName, $labelLength+1);
    }
    return join ('.', @labels);
}

1;
