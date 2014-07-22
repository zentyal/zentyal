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

package EBox::Samba::DNS::Node;

use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::Internal;
use EBox::Samba::DNS::RecordCNAME;
use EBox::Samba::DNS::RecordSOA;
use EBox::Samba::DNS::RecordSRV;
use EBox::Samba::DNS::RecordTXT;
use EBox::Samba::DNS::RecordNS;
use EBox::Samba::DNS::RecordMX;
use EBox::Samba::DNS::RecordA;

use constant DNS_TYPE_A     => 0x0001;
use constant DNS_TYPE_NS    => 0x0002;
use constant DNS_TYPE_TXT   => 0x0010;
use constant DNS_TYPE_SRV   => 0x0021;
use constant DNS_TYPE_MX    => 0x000F;
use constant DNS_TYPE_SOA   => 0x0006;
use constant DNS_TYPE_CNAME => 0x0005;

sub new
{
    my ($class, %params) = @_;

    throw EBox::Exceptions::MissingArgument('entry | dn')
        unless defined $params{entry} or defined $params{dn};

    my $self = {};
    bless ($self, $class);
    if (defined $params{entry}) {
        $self->{entry} = $params{entry};
    } else {
        my $dn = $params{dn};
        my $ldap = EBox::Global->modInstance('samba')->ldap();
        my $params = {
            base => $dn,
            scope => 'base',
            filter => '(objectClass=dnsNode)',
            attrs => ['*']
        };
        my $res = $ldap->search($params);
        throw EBox::Exceptions::Internal("Node $dn could not be found")
            unless ($res->count() > 0);
        throw EBox::Exceptions::Internal("Expected only one entry")
            unless ($res->count() == 1);
        $self->{entry} = $res->entry(0);
    }
    return $self;
}

sub dn
{
    my ($self) = @_;

    return $self->{entry}->dn();
}

sub name
{
    my ($self) = @_;

    return $self->{entry}->get_value('name');
}

sub records
{
    my ($self) = @_;

    my $records = [];
    my @blobs = $self->{entry}->get_value('dnsRecord');
    foreach my $blob (@blobs) {
        my $record = $self->_decodeDnsRecord($blob);
        push (@{$records}, $record) if defined $record;
    }
    return $records;
}

# Method: decodeDnsRecord
#
#   Decodes a DnsRecord blob as documented here:
#   http://msdn.microsoft.com/en-us/library/ee898781.aspx
#
sub _decodeDnsRecord
{
    my ($self, $blob) = @_;

    my ($dataLength, # 2 bytes | Length (bytes) of the data field
        $type,       # 2 bytes | The resource record's type
        $version,    # 1 byte  | Version number associated with the resource record attribute. The value MUST be 0x05.
        $rank,       # 1 byte  | The least-significant byte of one of the RANK* flag values
        $flags,      # 2 bytes | Not used. The value MUST be 0x0000.
        $serial,     # 4 bytes | The serial number of the SOA record of the zone containing this resource record
        $ttl,        # 4 bytes | See dwTtlSeconds
        $reserved,   # 4 bytes | This field is reserved for future use. The value MUST be 0x00000000.
        $timestamp,  # 4 bytes | See dwTimeStamp
        $data) = unpack ('S S C C S L N L L a*', $blob);

    unless ($version == 0x05) {
        EBox::error("Wrong DNS record version '$version' found");
        return undef;
    }

    return new EBox::Samba::DNS::RecordCNAME(data => $data) if ($type == DNS_TYPE_CNAME);
    return new EBox::Samba::DNS::RecordSOA(data => $data) if ($type == DNS_TYPE_SOA);
    return new EBox::Samba::DNS::RecordSRV(data => $data) if ($type == DNS_TYPE_SRV);
    return new EBox::Samba::DNS::RecordTXT(data => $data) if ($type == DNS_TYPE_TXT);
    return new EBox::Samba::DNS::RecordNS(data => $data)  if ($type == DNS_TYPE_NS);
    return new EBox::Samba::DNS::RecordMX(data => $data)  if ($type == DNS_TYPE_MX);
    return new EBox::Samba::DNS::RecordA(data => $data)   if ($type == DNS_TYPE_A);

    EBox::warn("Unknown DNS record type '$type' found");

    return undef;
}

1;
