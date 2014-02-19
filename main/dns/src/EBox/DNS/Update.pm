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

sub new
{
    my ($class, %params) = @_;

    my $self = {};
    bless ($self, $class);

    # Find the name of the DNS server
    my $domain = $params{domain};
    #my $serverName = $self->_findServerName($domain);
    #my $sysinfo = EBox::Global->modInstance('sysinfo');
    #my $serverName = $sysinfo->fqdn();
    my $serverName = '127.0.0.1';
    EBox::info("Using DNS server $serverName to update the domain $domain");

    $self->{domain} = $domain;
    $self->{serverName} = $serverName;
    $self->{packet} = new Net::DNS::Update($domain, 'IN');

    return $self;
}

# Method: add
#
#   Push an 'add' update request to the pending operations list
#
# Parameters:
#
#   record - The record to add
#
sub add
{
    my ($self, $record) = @_;

    my $domain = $self->{domain};
    my $packet = $self->{packet};
    $packet->push(update => rr_add($record));
}

# Method: del
#
#   Push a 'del' update request to the pending operations list
#
# Parameters:
#
#   record - The record to delete
#
sub del
{
    my ($self, $record) = @_;

    my $domain = $self->{domain};
    my $packet = $self->{packet};
    $packet->push(update => rr_del($record));
}

# Method: send
#
#
#
sub send
{
    throw EBox::Exceptions::NotImplemented('send', __PACKAGE__);
}

# Method: _sign
#
#
#
sub _sign
{
    my ($self) = @_;

    throw EBox::Exceptions::NotImplemented('_sign', __PACKAGE__);
}

# Method: _findServerName
#
#   Find the authoritative name server for the domain. Uses the NS record.
#
sub _findServerName
{
	my ($self, $domain) = @_;

	my $resolver = new Net::DNS::Resolver();
	my $reply = $resolver->query("$domain.", 'NS');
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
