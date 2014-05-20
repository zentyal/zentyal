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
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

# Class: EBox::Types::ReverseDnsZone
#
#   TODO Add documentation
#
use strict;
use warnings;

package EBox::DNS::Types::ReverseDnsZone;

use base 'EBox::Types::Abstract';

use Net::IP;

# Constructor: new
#
#   The constructor for the <EBox::DNS::Types::ReverseDnsZone>
#
# Returns:
#
#   The recently created <EBox::DNS::Types::ReverseDnsZone> object
#
sub new
{
    my $class = shift;
    my %opts = @_;

    unless (exists $opts{HTMLSetter}) {
        $opts{HTMLSetter} = '/dns/ajax/setter/reversednszone.mas';
    }
    unless (exists $opts{HTMLViewer}) {
        $opts{HTMLViewer} = '/ajax/viewer/textViewer.mas';
    }
    $opts{type} = 'reversednszone';

    my $self = $class->SUPER::new(%opts);
    bless ($self, $class);

    return $self;
}

sub paramExist
{
    my ($self, $params) = @_;

    my ($fieldGroup1, $fieldGroup2, $fieldGroup3) = $self->fields();

    return (defined $params->{$fieldGroup1} and
            defined $params->{$fieldGroup2} and
            defined $params->{$fieldGroup3});
}

sub printableValue
{
    my ($self) = @_;

    my ($group1, $group2, $group3) = $self->value();

    if (defined $group1 and defined $group2 and defined $group3) {
        return "$group3.$group2.$group1.in-addr.arpa";
    } elsif (defined $group1 and defined $group2) {
        return "$group2.$group1.in-addr.arpa";
    } elsif (defined $group1) {
        return "$group1.in-addr.arpa";
    } else {
        return '';
    }
}

sub value
{
    my ($self) = @_;

    my $group1 = $self->{group1};
    my $group2 = $self->{group2};
    my $group3 = $self->{group3};

    return ($group1, $group2, $group3);
}

# Method: mappedNetworkAddress
#
#   Return the mapped network address by the reverse zone in CIDR format
#   Example:
#       If the type instance is storing the a reverse zone
#       '45.168.192.in-addr.arpa', the return value will be '192.168.45.0/24'.
#       If it is storing '43.10.in-addr.arpa', the return value will be
#       '10.43.0.0/16'
#
sub mappedNetworkAddress
{
    my ($self) = @_;

    my ($fieldGroup1, $fieldGroup2, $fieldGroup3) = $self->fields();
    my $group1 = defined $self->{$fieldGroup1} ? $self->{$fieldGroup1} : '0';
    my $group2 = defined $self->{$fieldGroup2} ? $self->{$fieldGroup2} : '0';
    my $group3 = defined $self->{$fieldGroup3} ? $self->{$fieldGroup3} : '0';

    my $mask;
    if (defined $group3 and defined $group2 and defined $group1) {
        $mask = 24;
    } elsif (defined $group2 and defined $group1) {
        $mask = 16;
    } elsif (defined $group1) {
        $mask = 8;
    } else {
        throw EBox::Exceptions::Internal("Invalid value");
    }

    my $network = "$group3.$group2.$group1.0/$mask";

    return $network;
}

# Method: cmp
#
# Overrides:
#
#      <EBox::Types::Abstract::cmp>
#
sub cmp
{
    my ($self, $compareType) = @_;

    unless (ref $self eq ref $compareType) {
        return undef;
    }

    my $netA = $self->mappedNetworkAddress();
    my $netB = $compareType->mappedNetworkAddress();
    my $ipA = new Net::IP($netA);
    defined $ipA or return undef;
    my $ipB = new Net::IP($netB);
    defined $ipB or return undef;

    if ($ipA->bincomp('lt', $ipB)) {
        return -1;
    } elsif ($netA eq $netB) {
        return 0;
    } else {
        return 1;
    }
}

sub size
{
    my ($self) = @_;

    return $self->{size};
}

sub compareToHash
{
    my ($self, $hash) = @_;

    my ($group1, $group2, $group3) = $self->value();
    my ($fieldGroup1, $fieldGroup2, $fieldGroup3) = $self->fields();

    if ($group1 ne $hash->{$fieldGroup1}) {
        return 0;
    }
    if ($group2 ne $hash->{$fieldGroup2}) {
        return 0;
    }
    if ($group3 ne $hash->{$fieldGroup3}) {
        return 0;
    }

    return 1;
}

sub _attrs
{
    my ($self) = @_;

    return [ 'group1', 'group2', 'group3' ];
}

# Method: _paramIsValid
#
# Overrides:
#
#       <EBox::Types::Abstract::_paramIsValid>
#
sub _paramIsValid
{
    my ($self, $params) = @_;

    my ($fieldGroup1, $fieldGroup2, $fieldGroup3) = $self->fields();

    defined $params->{$fieldGroup1} or return 0;

    my $group1 = $params->{$fieldGroup1};
    my $group2 = $params->{$fieldGroup2};
    my $group3 = $params->{$fieldGroup3};

    if (defined $group1 and length $group1) {
        ($group1 >= 0 and $group1 <= 255) or return 0;
    }
    if (defined $group2 and length $group2) {
        ($group2 >= 0 and $group2 <= 255) or return 0;
    }
    if (defined $group3 and length $group3) {
        ($group3 >= 0 and $group3 <= 255) or return 0;
    }

    return 1;
}

# Method: _paramIsSet
#
# Overrides:
#
#   <EBox::Types::Abstract::_paramIsSet>
#
sub _paramIsSet
{
    my ($self, $params) = @_;

    my ($fieldGroup1, $fieldGroup2, $fieldGroup3) = $self->fields();

    # Only first group have to be present for A class network.
    defined $params->{$fieldGroup1} or return 0;
}

# Method: _setValue
#
# Overrides:
#
#   <EBox::Types::Abstract::_setValue>
#
# Parameters:
#
#   value - String a reverse zone name
#
sub _setValue
{
    my ($self, $value) = @_;

    my ($group1, $group2, $group3) =
        ($value =~ m/(\d+)\.(\d+)\.(\d+)\.in-addr\.arpa/);

    my ($fieldGroup1, $fieldGroup2, $fieldGroup3) = $self->fields();
    my $params = {
        $fieldGroup1 => $group1,
        $fieldGroup2 => $group2,
        $fieldGroup3 => $group3,
    };

    $self->setMemValue($params);
}

sub isEqualTo
{
    my ($self, $other) = @_;

    if (not $other->isa(__PACKAGE__)) {
        return undef;
    }

    my ($group1, $group2, $group3) = $self->value();
    my ($otherGroup1, $otherGroup2, $otherGroup3) = $other->value();

    ($group1 eq $otherGroup1) or return undef;
    ($group2 eq $otherGroup2) or return undef;
    ($group3 eq $otherGroup3) or return undef;

    return 1;
}

1;
