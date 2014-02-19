# Copyright (C) 2014 Zentyal S.L.
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

use strict;
use warnings;

package EBox::DNS::Update::TSIG;

use base 'EBox::DNS::Update';

use EBox::DNS;
use EBox::Gettext;
use EBox::Exceptions::External;

use Net::DNS::Resolver;

sub new
{
    my ($class, %params) = @_;

    my $self = $class->SUPER::new(%params);
    bless ($self, $class);

    $self->{keyName} = $params{keyName};
    $self->{key} = $params{key};

    return $self;
}

sub _sign
{
    my ($self) = @_;

    my $packet = $self->{packet};
    my $keyName = $self->{keyName};
    my $key = $self->{key};
    my $tsig = $packet->sign_tsig($keyName, $key);
    unless (defined $tsig) {
        throw EBox::Exceptions::External(__("Failed to sign DNS packet."));
    }
}

sub send
{
    my ($self) = @_;

    my $serverName = $self->{serverName};
    my $resolver = new Net::DNS::Resolver();
    $resolver->nameservers($serverName);

    # Sign the update
    $self->_sign();

    # Send the update
    my $packet = $self->{packet};
    EBox::info($packet->string());
    my $reply = $resolver->send($packet);
    unless (defined $reply) {
        throw EBox::Exceptions::External(
            __x("Failed to send update to server {srv}: {err}.",
                srv => $serverName, err => $resolver->errorstring()));
    }
    if ($reply->header->rcode() ne 'NOERROR') {
        throw EBox::Exceptions::External(
            __x("Failed to update: {err}.",
                err => $reply->header->rcode()));
    }
}

1;
