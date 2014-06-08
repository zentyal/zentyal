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

package EBox::Samba::LDAP::Control::SDFlags;

use Net::LDAP::Control;
use Convert::ASN1;

use base 'Net::LDAP::Control';

BEGIN {
    EBox::Samba::LDAP::Control::SDFlags->register('1.2.840.113556.1.4.801');
};

sub init
{
    my ($self) = @_;

    delete $self->{asn};

    unless (exists $self->{value}) {
        $self->{asn} = $self->{flags} || 0x0000000F;
    }

    return $self;
}

sub flags
{
    my ($self, $newValue) = @_;

    if (defined $newValue) {
        delete $self->{value};
        return $self->{asn} = $newValue;
    }
    elsif (exists $self->{value}) {
        my $asq_asn = new Convert::ASN1();
        $asq_asn->prepare(q<  asq ::= SEQUENCE { value INTEGER } >);
        my $ctl_val = $asq_asn->decode(value => $self->{value});
        $self->{asn} ||= $ctl_val if (defined $ctl_val);
    }

    return $self->{asn};
}

sub value
{
    my ($self) = @_;

    unless (exists $self->{value}) {
        my $asq_asn = new Convert::ASN1();
        $asq_asn->prepare(q<  asq ::= SEQUENCE { value INTEGER } >);
        $self->{value} = $asq_asn->encode(value => $self->{asn})
            if (defined $self->{asn});
    }

    return $self->{value};
}

1;
