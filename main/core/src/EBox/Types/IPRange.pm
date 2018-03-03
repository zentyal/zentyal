# Copyright (C) 2011-2013 Zentyal S.L.
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

package EBox::Types::IPRange;

use base 'EBox::Types::Abstract';

use EBox::Validate qw(:all);
use EBox::Gettext;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::InvalidData;
use Net::IP;
use TryCatch;

use constant MAX_N_ADDRESS => 16777216; # we choose as max the number of
                                        # addresses for a net of class A

sub new
{
    my $class = shift;
    my %opts = @_;

    unless (exists $opts{'HTMLSetter'}) {
        $opts{'HTMLSetter'} ='/ajax/setter/ipRangeSetter.mas';
    }
    unless (exists $opts{'HTMLViewer'}) {
        $opts{'HTMLViewer'} ='/ajax/viewer/textViewer.mas';
    }

    $opts{'type'} = 'iprange';
    my $self = $class->SUPER::new(%opts);

    bless($self, $class);

    return $self;
}

sub paramExist
{
    my ($self, $params) = @_;

    my $begin = $self->fieldName() . '_begin';
    my $end = $self->fieldName() . '_end';

    return (defined($params->{$begin}) and defined($params->{$end}));
}

sub printableValue
{
    my ($self) = @_;

    if (defined($self->{'begin'}) and defined($self->{'end'})) {
        return "$self->{'begin'} - $self->{'end'}";
    } else {
        return "";
    }
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

    unless ((ref $self) eq (ref $compareType)) {
        return undef;
    }
    my $rangeA = $self->_rangeObject();
    my $rangeB = $compareType->_rangeObject();;

    if ($rangeA->bincomp('lt', $rangeB)) {
        return -1;
    } elsif ( $self->printableValue() eq $compareType->printableValue() ) {
        return 0;
    } else {
        return 1;
    }
}

sub size
{
    my ($self) = @_;
    return $self->{'size'};
}

sub compareToHash
{
    my ($self, $hash) = @_;

    my $oldBegin = $self->begin();
    my $oldEnd   = $self->end();

    my $begin = $self->fieldName() . '_begin';
    my $end = $self->fieldName() . '_end';

    if ($oldBegin ne $hash->{$begin}) {
        return 0;
    }

    if ($oldEnd ne $hash->{$end}) {
        return 0;
    }

    return 1;
}

sub _attrs
{
    return [ 'begin', 'end' ];
}

sub begin
{
    my ($self) = @_;
    return $self->{'begin'};
}

sub end
{
    my ($self) = @_;
    return $self->{'end'};
}

# Group: Protected methods

# Method: _paramIsValid
#
# Overrides:
#
#       <EBox::Types::Abstract::_paramIsValid>
#
sub _paramIsValid
{
    my ($self, $params) = @_;

    my $beginParam =  $self->fieldName() . '_begin';
    my $endParam =  $self->fieldName() . '_end';

    my $begin = $params->{$beginParam};
    my $end = $params->{$endParam};

    checkIP($begin, __('Begin of IP range'));
    checkIP($end, __('End of IP range'));

    my @beginParts = split '\.', $begin, 4;
    my @endParts = split '\.', $end, 4;
    foreach my $n (0 .. 3) {
        if ($beginParts[$n] < $endParts[$n]) {
            last;
        } elsif ($beginParts[$n] > $endParts[$n]) {
            throw EBox::Exceptions::InvalidData(
              data => $self->printableName(),
              value => $self->printableValue(),
              advice => __('End of range address should be smaller than start of range address')
                                               )
        }
    }

    my $range;
    try {
        $range = Net::IP->new("$begin - $end");
    } catch ($e) {
        throw EBox::Exceptions::InvalidData(
            data => $self->printableName(),
            value => $self->printableValue(),
            advice => "$e",
        );
    }

    if ($range->size() > MAX_N_ADDRESS) {
        my $advice = __x(
'The IP range contained {size} addresses, the maximum is {max} addresses',
                         size => $range->size(),
                         max => MAX_N_ADDRESS,
                        );
        throw EBox::Exceptions::InvalidData(
            data => $self->printableName(),
            value => $self->printableValue(),
            advice => $advice,
        );
    }

    return 1;
}

# Method: _paramIsSet
#
# Overrides:
#
#       <EBox::Types::Abstract::_paramIsSet>
#
sub _paramIsSet
{
    my ($self, $params) = @_;

    # Check if the parameter exist
    my $begin =  $self->fieldName() . '_begin';
    my $end =  $self->fieldName() . '_end';

    unless ( defined($params->{$begin}) and defined($params->{$end})) {
        return 0;
    }

    # Check if has something, begin field is not empty
    return ( $params->{$begin} ne '' );
}

# Method: _setValue
#
#     Set the value defined as a string in the
#     printableValue. That is, to define an IP Address you must set
#     a valid CIDR IP Address.
#
# Overrides:
#
#     <EBox::Types::Abstract::_setValue>
#
# Parameters:
#
#     value - String an IP address with CIDR notation
#
sub _setValue # (value)
{
    my ($self, $value) = @_;

    my ($begin, $end) = split ('\s*-\s*', $value);

    my $params = {
        $self->fieldName() . '_begin'   => $begin,
        $self->fieldName() . '_end' => $end,
    };

    $self->setMemValue($params);
}

# Method: addresses
#
#  return the addresses contained in the range
#
sub addresses
{
    my ($self) = @_;
    return $self->addressesFromBeginToEnd($self->begin(), $self->end());
}

# Class method: addressesFromBeginToEnd
#
#  return the addresses from begin IP to end IP, including both
#
# Warning:
#   it is not checked that begin <= end
#
sub addressesFromBeginToEnd
{
    my ($class, $begin, $end) = @_;
    defined $begin or
        throw EBox::Exceptions::MissingArgument('begin IP');
    defined $end or
        throw EBox::Exceptions::MissingArgument('nd IP');

    my $ipRange = Net::IP->new("$begin - $end");
    my @addresses;
    do {
        my $ip = $ipRange->ip();
        unless ($ip =~ /\.0$/) {
            push (@addresses, $ip);
        }
    } while (++$ipRange);

    return \@addresses;
}

sub isIPInside
{
    my ($self, $ip) = @_;
    my $ipB = Net::IP->new($ip);
    my $ipRange = $self->_rangeObject();
    my $res = $ipRange->overlaps($ipB);
    if (defined $res) {
        return $res ne  $Net::IP::IP_NO_OVERLAP ;
    } else {
        return undef;
    }
}

sub _rangeObject
{
    my ($self) = @_;
    return new Net::IP ($self->printableValue());
}

1;
