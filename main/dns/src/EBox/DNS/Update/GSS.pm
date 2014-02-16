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

# Based on

use strict;
use warnings;

package EBox::DNS::Update::GSS;

use Net::DNS;
use GSSAPI;

use constant ALGORITHM => 'gss.microsoft.com';

sub new
{
    my ($class, %params) = @_;

    my $self = {};
    bless ($self, $class);

    $self->{gssCtx} = new GSSAPI::Context();
    $self->{gssName} = new GSSAPI::Name();


    $self->{domain} = $params{domain};
    $self->{realm} = uc ($params{domain});
    $self->{pending} = [];

    # find the name of the DNS server
    my $serverName = $self->_findServerName($domain);
    unless (defined $serverName) {
        throw EBox::Exceptions::External("Failed to find a DNS server name for $domain");
    }
    EBox::debug("Using DNS server name $serverName");
    $self->{serverName} = $serverName;

    # connect to the nameserver
	my $nameserver = Net::DNS::Resolver->new(nameservers => [$serverName], recurse => 0, debug => 0);
    unless (defined($nameserver) and (uc($nameserver->errorstring()) eq 'NOERROR')) {
        throw EBox::Exceptions::External("Failed to connect to nameserver for domain $domain");
    }
    $self->{nameserver} = $nameserver;

    return $self;
}

# Method: negotiate
#
#   Negotiate the GSS context with the server
#
sub negotiate
{
    my ($self) = @_;

    $self->_getCreds($serverName);

    # use a long random key name
    my $keyname = int(rand 1000000000) . 'sig-saucy'; #TODO

    # negotiate a TKEY key
    $self->_negotiateTKEY($keyname);
    unless (defined $self->{gssCtx}) {
        throw EBox::Exceptions::External('Failed to negotiate a TKEY');
    }
    EBox::debug("Negotiated TKEY $keyname");

}

# Method: add
#
#   Push an 'add' update request to the pending operations list
#
# Parameters:
#
#   host   - host name
#   ttl    - time to live
#   type   - record type
#   target - record target
#
sub add
{
    my ($self, $host, $ttl, $type, $target) = @_;

    my $domain = $self->{domain};
    push (@{$self->{pending}}, rr_add("$host.$domain. $ttl $type $target"));
}

# Method: del
#
#   Push a 'del' update request to the pending operations list
#
# Parameters:
#
#   host - host name
#   type - record type
#
sub del
{
    my ($self, $host, $type) = @_;

    my $domain = $self->{domain};
    push (@{$self->{pending}}, rr_del("$host.$domain. $type"));
}

# Method: send
#
#   Perform the pending dynamic updates signing the request with the negotiated key
#
sub send
{
    my ($self) = @_;

    my $domain = $self->{domain};

    # construct a signed update
    my $update = Net::DNS::Update->new($domain);

    $update->push('pre', yxdomain($domain));

    foreach my $op (@{$self->{pending}}) {
        $update->push('update', $op);
    }

    my $sig = Net::DNS::RR->new(
        Name => $keyname,
        Type => 'TSIG',
        TTL => 0,
        Class => 'ANY',
        Algorithm => ALGORITHM,
        Time_Signed => time,
        Fudge => 36000,
        Mac_Size => 0,
        Mac => '',
        Key => $self->{gssCtx},
        Sign_Func => \&_gssSign,
        Other_Len => 0,
        Other_Data => '',
        Error => 0,
        mode => 3,
    );

    $self->{update}->push('additional', $sig);

    # send the dynamic update
    my $update_reply = $nameserver->send($self->{update});

    # empty pending ops after send
    $self->{pending} = [];

    unless (defined $update_reply) {
        throw EBox::Exceptions::External('GSS: No reply to dynamic update');
    }

    # make sure it worked
    my $result = $update_reply->header->{'rcode'};
    if ($result ne 'NOERROR') {
        throw EBox::Exceptions::External("GSS: update failed with result code: $result");
    }
}

# find a server name for a domain - currently uses the NS record
sub _findServerName
{
	my ($self, $domain) = @_;

	my $res = Net::DNS::Resolver->new;
	my $srv_query = $res->query("$domain.", "NS");
	unless (defined $srv_query) {
		return undef;
	}
	my $server_name;
	foreach my $rr (grep { $_->type eq 'NS' } $srv_query->answer) {
		$server_name = $rr->nsdname;
	}
	return $server_name;
}

sub _getCreds
{
    my ($serverName) = @_;

    my $realm = $self->{realm};

    my $status;

    # use a principal name of DNS/fqdn@REALM
	$status = GSSAPI::Name->import($self->{gssName}, "DNS/" . $serverName . "@" . uc($realm));
    if ($status->major() != 0) {
        foreach my $error ($status->generic_message, $status->specific_message) {
            EBox::error("GSSAPI error: $error");
        }
        throw EBox::Exceptions::External("GSS: name import failed");
    }

	$status = GSSAPI::Cred::acquire_cred(undef, 120, undef, GSS_C_INITIATE,
			                             $gssCred, $gssOidSet, $gssTime);
    if ($status->major() != 0) {
        foreach my $error ($status->generic_message, $status->specific_message) {
            EBox::error("GSSAPI error: $error");
        }
        throw EBox::Exceptions::External("GSS: acquire credentials failed");
    }

	EBox::debug('creds acquired');
}


sub _negotiateTKEY
{
	my ($self, $keyname) = @_;

    my $nameserver = $self->{nameserver};
    my $domain = $self->{domain};
    my $server_name = $self->{serverName};

    my $status;
	my $flags = GSS_C_REPLAY_FLAG | GSS_C_MUTUAL_FLAG |
		        GSS_C_SEQUENCE_FLAG | GSS_C_CONF_FLAG |
		        GSS_C_INTEG_FLAG | GSS_C_DELEG_FLAG;

    my $gssToken = undef;
    my $gssToken2 = '';
    my $gssReply;

    do {
	    $status = $self->{gssCtx}->init($gssCred, $self->{gssName}, undef, $flags, 0, undef, $gssToken2, undef, $gssToken, undef, undef);
	    my $gssQuery = new Net::DNS::Packet($keyname, 'TKEY', 'ANY');
        my $tkeyRR = Net::DNS::RR->new(
			name    => $keyname,
			type    => 'TKEY',
			ttl     => 0,
			class   => 'ANY',
			mode    => 3,
			algorithm => ALGORITHM,
			inception => time,
			expiration => time + 24*60*60,
			key => $gssToken,
			other_data => '',
		);
	    $gssQuery->push(additional => $tkeyRR);

        $gssReply = $nameserver->send($gssQuery);
        unless (defined($gssReply) and ($gssReply->header->{'rcode'} eq 'NOERROR')) {
            throw EBox::Exceptions::External("GSS: failed to send TKEY");
        }

        $gssToken2 = ($gssReply->answer)[0]->{"key"};
	} while ($status->major() == GSS_S_CONTINUE_NEEDED);

    if ($status->major() == GSS_S_COMPLETE) {
        EBox::debug('Negotiation completed');
    } else {
        throw EBox::Exceptions::External('GSS: negotiation failed');
    }

    # FIXME: bind does not sign the replies, remove the return when fixed
    return;

    EBox::debug('Verifying signature on the TKEY reply');
    my $rc = $self->_sigVerify($self->{gssCtx}, $gssReply);
    if (!$rc) {
        EBox::error("Failed to verify TKEY reply: $rc");
        return undef;
    }
    EBox::debug('Verification successful');
}

# signing callback function for TSIG module
sub _gssSign
{
	my ($key, $data) = @_;
	my $sig;
	$key->get_mic(0, $data, $sig);
	return $sig;
}

# verify a TSIG signature from a DNS server reply
sub _sigVerify
{
	my ($self, $context, $packet) = @_;

    my @tsig = $packet->additional();
    EBox::debug("additional has " . scalar(@tsig));

	my $tsig = $tsig[0];
	EBox::debug('calling sig_data');
	my $sigdata = $tsig->sig_data($packet);

    EBox::debug('sig_data_done');

	return $self->{gssCtx}->verify_mic($sigdata, $tsig->{'mac'}, 0);
}

1;
