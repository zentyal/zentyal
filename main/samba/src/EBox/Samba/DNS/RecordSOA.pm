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

package EBox::Samba::DNS::RecordSOA;

use base 'EBox::Samba::DNS::Record';

sub new
{
    my $class = shift;
    my %params = @_;

    my $self = $class->SUPER::new(type => 'SOA');

    throw EBox::Exceptions::MissingArgument('data')
        unless defined $params{data};

    bless ($self, $class);
    $self->{data} = $self->_decode_DNS_RPC_RECORD_SOA($params{data});

    return $self;
}

sub _decode_DNS_RPC_RECORD_SOA
{
    my ($self, $blob) = @_;

    my ($serialNumber,
        $refresh,
        $retry,
        $expire,
        $minimumTTL,
        $primaryNS,
        $hostmaster,
    ) = unpack ('N N N N N Z* Z*', $blob);

    $self->{serial} = $serialNumber;
    $self->{refresh} = $refresh;
    $self->{retry} = $retry;
    $self->{expire} = $expire;
    $self->{minimumTTL} = $minimumTTL;
    $self->{primaryNS} = $self->_decode_DNS_COUNT_NAME($primaryNS);
    $self->{hostmaster} = $self->_decode_DNS_COUNT_NAME($hostmaster);
}

sub serial
{
    my ($self) = @_;

    return $self->{serial};
}

sub refresh
{
    my ($self) = @_;

    return $self->{refresh};
}

sub retry
{
    my ($self) = @_;

    return $self->{retry};
}

sub expire
{
    my ($self) = @_;

    return $self->{expire};
}

sub minTTL
{
    my ($self) = @_;

    return $self->{minimumTTL};
}

sub primaryNS
{
    my ($self) = @_;

    return $self->{primaryNS};
}

sub hostmaster
{
    my ($self) = @_;

    return $self->{hostmaster};
}

1;
