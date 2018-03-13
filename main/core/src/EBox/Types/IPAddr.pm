# Copyright (C) 2007 Warp Networks S.L.
# Copyright (C) 2008-2013 Zentyal S.L.
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

package EBox::Types::IPAddr;

use base 'EBox::Types::Abstract';

use EBox::Validate qw(:all);
use EBox::Gettext;
use EBox::Exceptions::MissingArgument;
use Net::IP;

sub new
{
    my $class = shift;
    my %opts = @_;

    unless (exists $opts{'HTMLSetter'}) {
        $opts{'HTMLSetter'} ='/ajax/setter/ipaddrSetter.mas';
    }
    unless (exists $opts{'HTMLViewer'}) {
        $opts{'HTMLViewer'} ='/ajax/viewer/textViewer.mas';
    }

    $opts{'type'} = 'ipaddr';
    my $self = $class->SUPER::new(%opts);

    bless($self, $class);

    return $self;
}

sub paramExist
{
    my ($self, $params) = @_;

    my $ip = $self->fieldName() . '_ip';
    my $mask = $self->fieldName() . '_mask';

    return (defined($params->{$ip}) and defined($params->{$mask}));
}

sub printableValue
{
    my ($self) = @_;

    if (defined($self->{'ip'}) and defined($self->{'mask'})) {
        return "$self->{'ip'}/$self->{'mask'}";
    } else {
        return '';
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

    unless ( (ref $self) eq (ref $compareType) ) {
        return undef;
    }
    my $ipA = new Net::IP($self->printableValue());
    defined $ipA or
        return undef;
    my $ipB = new Net::IP($compareType->printableValue());
    defined $ipB or
        return undef;

    if ( $ipA->bincomp('lt', $ipB) ) {
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

    my ($oldIp, $oldMask) = $self->_ipNetmask();
    my $ip = $self->fieldName() . '_ip';
    my $mask = $self->fieldName() . '_mask';

    if ($oldIp ne $hash->{$ip}) {
        return 0;
    }

    if ($oldMask ne $hash->{$mask}) {
        return 0;
    }

    return 1;
}

sub fields
{
    my ($self) = @_;

    my $ip = $self->fieldName() . '_ip';
    my $mask = $self->fieldName() . '_mask';

    return ($ip, $mask);
}

sub value
{
    my ($self) = @_;
    return $self->_ipNetmask();
}

sub ip
{
    my ($self) = @_;

    return $self->{'ip'};
}

sub mask
{
    my ($self) = @_;

    return $self->{'mask'};
}

# Group: Protected methods

sub _attrs
{
    return [ 'ip', 'mask' ];
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

    my $ip =  $self->fieldName() . '_ip';
    my $mask =  $self->fieldName() . '_mask';

    checkIP($params->{$ip}, __($self->printableName()));
    checkCIDR($params->{$ip} . "/$params->{$mask}", __($self->printableName()));

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
    my $ip =  $self->fieldName() . '_ip';
    my $mask =  $self->fieldName() . '_mask';

    unless ( defined($params->{$ip}) and defined($params->{$mask})) {
        return 0;
    }

    # Check if has something, ip field is not empty
    return ( $params->{$ip} ne '' );
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

    my ($ip, $netmask) = split ('/', $value);

    my $params = {
        $self->fieldName() . '_ip'   => $ip,
        $self->fieldName() . '_mask' => $netmask,
    };

    $self->setMemValue($params);
}

# Group: Private methods

# Helper funcionts
sub _ipNetmask
{
    my ($self) = @_;

    return ($self->{'ip'}, $self->{'mask'});
}

sub isEqualTo
{
    my ($self, $other) = @_;
    if (not $other->isa(__PACKAGE__)) {
        return undef;
    }

    local $SIG{__WARN__};
    if ($self->ip() ne $other->ip()) {
        return undef;
    } elsif ($self->mask() ne $other->mask()) {
        return undef;
    }

    return 1;
}

1;
