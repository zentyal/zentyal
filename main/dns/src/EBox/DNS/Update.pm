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

package EBox::DNS::Update;

use Net::DNS;
use Net::DNS::Resolver;
use Net::DNS::Update;
use EBox::Gettext;
use EBox::Exceptions::External;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::NotImplemented;

sub new
{
    my ($class, %params) = @_;

    my $self = {};
    bless ($self, $class);

    unless (defined $params{domain}) {
        throw EBox::Exceptions::MissingArgument('domain');
    }
    my $domain = $params{domain};
    my $server = '127.0.0.1';

    $self->{domain} = $domain;
    $self->{server} = $server;
    $self->{packet} = new Net::DNS::Update($domain, 'IN');

    return $self;
}

# Method: add
#
#   Push an 'add' update request to the update packet
#
# Parameters:
#
#   record - The record to add
#
sub add
{
    my ($self, $record) = @_;

    unless (defined $record) {
        throw EBox::Exceptions::MissingArgument('record');
    }

    my $domain = $self->{domain};
    my $packet = $self->{packet};
    $packet->push(update => rr_add($record));
}

# Method: del
#
#   Push a 'del' update request to the update packet
#
# Parameters:
#
#   record - The record to delete
#
sub del
{
    my ($self, $record) = @_;

    unless (defined $record) {
        throw EBox::Exceptions::MissingArgument('record');
    }

    my $domain = $self->{domain};
    my $packet = $self->{packet};
    $packet->push(update => rr_del($record));
}

# Method: send
#
#   Sign and send the update to the server.
#
sub send
{
    my ($self) = @_;

    # Get the resolver
    my $resolver = $self->_resolver();

    # Sign the update
    $self->_sign();

    # Send the update
    my $packet = $self->_packet();
    EBox::debug($packet->string());
    my $reply = $resolver->send($packet);
    EBox::debug($reply->string());
    unless (defined $reply) {
        throw EBox::Exceptions::External(
            __x("Failed to send update: {err}.",
                err => $resolver->errorstring()));
    }
    if ($reply->header->rcode() ne 'NOERROR') {
        throw EBox::Exceptions::External(
            __x("Failed to update: {err}.",
                err => $reply->header->rcode()));
    }
}

# Method: _sign
#
#   Child classes must implement this method to sign the update packet.
#
sub _sign
{
    my ($self) = @_;

    throw EBox::Exceptions::NotImplemented('_sign', __PACKAGE__);
}

# Method: _packet
#
#   Return the update packet.
#
sub _packet
{
    my ($self) = @_;

    return $self->{packet};
}

# Method: _resolver
#
#   Return the resolver.
#
sub _resolver
{
    my ($self) = @_;

    unless (defined $self->{resolver}) {
        my $resolver = new Net::DNS::Resolver();
        my $address = $self->{server};
        $resolver->nameservers($address);
        $self->{resolver} = $resolver;
    }

    return $self->{resolver};
}

# Method: _findServerName
#
#   Find the authoritative name server for the domain. Uses the NS record.
#
sub _findServerName
{
	my ($self, $domain) = @_;

    unless (defined $domain) {
        throw EBox::Exceptions::MissingArgument('domain');
    }

	my $resolver = new Net::DNS::Resolver();
	my $reply = $resolver->query($domain, 'NS');
	unless (defined $reply) {
        throw EBox::Exceptions::External(
            __x("Failed to query the {dom} zone NS record: {err}",
                dom => $domain, err => $resolver->errorstring()));
	}
	my $serverName;
	foreach my $rr ($reply->answer()) {
        next unless $rr->type() eq 'NS';
		$serverName = $rr->nsdname();
        last;
	}

    unless (defined $serverName) {
        throw EBox::Exceptions::External(
            __x("Failed to query the {dom} zone NS record: Record not found.",
                dom => $domain));
    }

	return $serverName;
}

1;
