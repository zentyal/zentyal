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

package EBox::DNS::Update::GSS;

use base 'EBox::DNS::Update';

use EBox::Gettext;
use EBox::Exceptions::External;
use EBox::Exceptions::MissingArgument;

use GSSAPI;
use Net::DNS;
use Net::DNS::RR;
use Net::DNS::Packet;
use Net::DNS::Resolver;
use Authen::Krb5::Easy qw(kinit kdestroy kerror);

sub new
{
    my ($class, %params) = @_;

    my $self = $class->SUPER::new(%params);
    bless ($self, $class);

    unless (defined $params{keytab}) {
        throw EBox::Exceptions::MissingArgument('keytab');
    }
    $self->{keytab} = $params{keytab};

    unless (defined $params{principal}) {
        throw EBox::Exceptions::MissingArgument('principal');
    }
    $self->{principal} = $params{principal};

    return $self;
}

# Method: _sigVerify
#
#   Verify a TSIG signature from a DNS server reply
#
sub _sigVerify
{
    my ($self, $gssContext, $packet) = @_;

    my $tsig;
    foreach my $rr ($packet->additional()) {
        next unless $rr->type() eq 'TSIG';
        $tsig = $rr;
        last;
    }
    unless (defined $tsig) {
        throw EBox::Exceptions::External(
            __('The DNS server has not signed the reply. Can not verify its authenticity.'));
    }

    my $sigdata = $tsig->sig_data($packet);
    my $mac = $tsig->{mac};
    my $status = $gssContext->verify_mic($sigdata, $mac, 0);
    unless ($status->major() == GSS_S_COMPLETE) {
        throw EBox::Exceptions::External(
            __x('Failed to verify MIC: {err}',
                err => $status->stringify()));
    }
}

# Method: _negotiateTKEY
#
#   Negotiate the TKEY with the server
#
sub _negotiateTKEY
{
    my ($self, $keyName, $gssName, $gssCred) = @_;

    my $resolver = $self->_resolver();

    my $flags = GSS_C_REPLAY_FLAG   | GSS_C_MUTUAL_FLAG |
                GSS_C_SEQUENCE_FLAG | GSS_C_CONF_FLAG   |
                GSS_C_INTEG_FLAG    | GSS_C_DELEG_FLAG;

    my $gssCtx = new GSSAPI::Context();
    my $status;
    my $gssInToken = '';
    my $gssOutToken;
    my $gssOidSet;
    my $gssTime;
    my $reply;

    my $count = 1;
    for (my $count = 1; $count <= 10; $count++)  {
        $status = $gssCtx->init($gssCred, $gssName, undef, $flags,
                                0, undef, $gssInToken, undef, $gssOutToken,
                                undef, undef);
        unless ($status->major() == GSS_S_CONTINUE_NEEDED or
                $status->major() == GSS_S_COMPLETE) {
            throw EBox::Exceptions::External(
                __x('GSS: failed to init security context: {err}',
                    err => $status->stringify()));
        }
        last if ($status->major() == GSS_S_COMPLETE and not defined $gssOutToken);

        my $query = new Net::DNS::Packet($keyName, 'TKEY', 'ANY');
        my $tkeyRR = new Net::DNS::RR(
            name        => $keyName,
            type        => 'TKEY',
            ttl         => 0,
            class       => 'ANY',
            mode        => 3,
            algorithm   => 'gss.microsoft.com',
            inception   => time,
            expiration  => time + 24*60*60,
            key         => $gssOutToken,
            other_data  => '',
        );
        $query->push(additional => $tkeyRR);
        $reply = $resolver->send($query);
        unless (defined $reply) {
            throw EBox::Exceptions::External(
                __x('GSS: Failed to send update: {err}.',
                    err => $resolver->errorstring()));
        }
        unless ($reply->header->rcode() eq 'NOERROR') {
            my $error = $reply->header->rcode();
            throw EBox::Exceptions::External(
                __x('GSS: Failed to send TKEY: {err}.',
                    err => $error));
        }
        my $tkey;
        foreach my $rr ($reply->answer()) {
            next unless $rr->type() eq 'TKEY';
    		$tkey = $rr;
            last;
	    }
        unless (defined $tkey) {
            throw EBox::Exceptions::External(
                __('Failed to negotiate security context with DNS server. ' .
                   'The server reply does not contain a TKEY record.')),
        }
        $gssInToken = $tkey->key();
    };

    # FIXME: According to RFC 3645, the response MUST be signed with a TSIG
    #        record (section 3.1.3.1). Bind does not, while MS DNS server does.
    #$self->_sigVerify($gssCtx, $reply);
    return $gssCtx;
}


# Method: _negotiateContext
#
#   Negotiate the GSS context with the server
#
sub _negotiateContext
{
    my ($self, $keyName) = @_;

    # Acquire kerberos credentials
    $self->_getCredentials();

    my $serverName = 'saucy.kernevil.lan'; # TODO
    my $realm = 'KERNEVIL.LAN';
    my $status;
    my $gssName;

    $status = GSSAPI::Name->import($gssName, "DNS/$serverName\@$realm");
    if ($status->major() != 0) {
        foreach my $error ($status->generic_message(), $status->specific_message()) {
            EBox::error("GSSAPI error: $error");
        }
        throw EBox::Exceptions::External("GSS: name import failed");
    }

    my ($gssCred, $gssOidSet, $gssTime);
    $status = GSSAPI::Cred::acquire_cred(undef, 120, undef, GSS_C_INITIATE,
                                         $gssCred, $gssOidSet, $gssTime);
    if ($status->major() != 0) {
        foreach my $error ($status->generic_message, $status->specific_message) {
            EBox::error("GSSAPI error: $error");
        }
        throw EBox::Exceptions::External("GSS: acquire credentials failed");
    }

    # Negotiate the TKEY
    return $self->_negotiateTKEY($keyName, $gssName, $gssCred);
}

sub _getCredentials
{
    my ($self) = @_;

    my $keytab = $self->{keytab};
    my $principal = $self->{principal};
    my $ret = kinit($keytab, $principal);
    unless ($ret == 1) {
        my $error = kerror();
        throw EBox::Exceptions::External($error);
    }
}

sub _sign
{
    my ($self) = @_;

    my $keyName = time . '.sig-saucy'; # TODO

    # Negotiate the GSS context
    my $gssCtx = $self->_negotiateContext($keyName);

    # Create the TSIG record
    my $tsig = new Net::DNS::RR(
        Name        => $keyName,
        Type        => 'TSIG',
        TTL         => 0,
        Class       => 'ANY',
        #Algorithm   => 'gss-tsig',
        Algorithm   => 'gss.microsoft.com',
        Time_Signed => time,
        Fudge       => 36000,
        Mac_Size    => 0,
        Mac         => '',
        Key         => $gssCtx,
        Sign_Func   => \&_gssSign,
        Other_Len   => 0,
        Other_Data  => '',
        Error       => 0,
        Mode        => 3,
    );

    # And push to the update packet
    my $packet = $self->_packet();
    $packet->push(additional => $tsig);
}

# Method: _gssSign
#
#   Signing callback function
#
sub _gssSign
{
    my ($key, $data) = @_;

    my $sig;
    $key->get_mic(0, $data, $sig);

    return $sig;
}

sub DESTROY
{
    kdestroy();
}

1;
