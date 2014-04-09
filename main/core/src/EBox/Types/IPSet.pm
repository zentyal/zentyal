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

use strict;
use warnings;

package EBox::Types::IPSet;

use base 'EBox::Types::Abstract';

use EBox::Validate qw(:all);
use EBox::Gettext;
use Net::IP;

sub new
{
    my $class = shift;
    my %opts = @_;

    unless (exists $opts{'HTMLSetter'}) {
        $opts{'HTMLSetter'} ='/ajax/setter/ipsetSetter.mas';
    }
    unless (exists $opts{'HTMLViewer'}) {
        $opts{'HTMLViewer'} ='/ajax/viewer/textViewer.mas';
    }

    $opts{'type'} = 'ipset';
    my $self = $class->SUPER::new(%opts);

    bless ($self, $class);

    return $self;
}

sub paramExist
{
    my ($self, $params) = @_;

    my $set = $self->fieldName() . '_set';
    my $filterIp = $self->fieldName() . '_filterip';
    my $filterMask = $self->fieldName() . '_filtermask';

    return (defined $params->{$set} and defined $params->{$filterIp} and defined $params->{$filterMask});
}

sub printableValue
{
    my ($self) = @_;

    my $value = '';
    my $options = $self->options();
    if (defined $options) {
        my $set = $self->{set};
        if (defined $self->{set}) {
            foreach my $option (@{$options}) {
                if ($option->{'value'} eq $set) {
                    if ($option->{'printableValue'}) {
                        $value .= $option->{'printableValue'};
                    } else {
                        $value .= $value;
                    }
                }
            }
            my $filter = $self->_filter();
            if (defined $filter) {
                $value .= " on network $filter";
            }
        }
    }
    return $value;
}

sub _filter
{
    my ($self) = @_;

    my $value = undef;
    if (defined $self->{filterip} and defined $self->{filtermask}) {
        $value = $self->{filterip} . '/' . $self->{filtermask};
    }
    return $value;
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
    my $setA = $self->set();
    defined $setA or return undef;

    my $setB = $self->set();
    defined $setB or return undef;

    my $ret = $setA cmp $setB;
    if ($ret == 0) {
        my $ipA = new Net::IP($self->_filter());
        defined $ipA or return undef;

        my $ipB = new Net::IP($compareType->_filter());
        defined $ipB or return undef;

        if ($ipA->bincomp('lt', $ipB)) {
            $ret = -1;
        } elsif ($self->printableValue() eq $compareType->printableValue()) {
            $ret = 0;
        } else {
            $ret = 1;
        }
    }
    return $ret;
}

sub size
{
    my ($self) = @_;

    return $self->{size};
}

sub compareToHash
{
    my ($self, $hash) = @_;

    my $oldSet = $self->{set};
    my $oldFilterIp = $self->{filterip};
    my $oldFilterMask = $self->{filtermask};

    my $set = $self->fieldName() . '_set';
    my $ip = $self->fieldName() . '_filterip';
    my $mask = $self->fieldName() . '_filtermask';

    if ($oldSet ne $hash->{$set}) {
        return 0;
    }

    if ($oldFilterIp ne $hash->{$ip}) {
        return 0;
    }

    if ($oldFilterMask ne $hash->{$mask}) {
        return 0;
    }

    return 1;
}

sub fields
{
    my ($self) = @_;

    my $set = $self->fieldName() . '_set';
    my $ip = $self->fieldName() . '_filterip';
    my $mask = $self->fieldName() . '_filtermask';

    return ($set, $ip, $mask);
}

sub value
{
    my ($self) = @_;

    return ($self->{set}, $self->{filterip}, $self->{filtermask});
}

sub set
{
    my ($self) = @_;

    return $self->{set};
}

sub filterIp
{
    my ($self) = @_;

    return $self->{filterip};
}

sub filterMask
{
    my ($self) = @_;

    return $self->{filtermask};
}

# Group: Protected methods

sub _attrs
{
    return [ 'set', 'filterip', 'filtermask' ];
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

    my $set = $self->fieldName() . '_set';
    my $ip =  $self->fieldName() . '_filterip';
    my $mask =  $self->fieldName() . '_filtermask';

    unless (length $set) {
        throw EBox::Exceptions::InvalidData('data' => 'set name', 'value' => $set);
    }

    # Filter IP and mask are optional
    if (defined $params->{$ip}) {
        checkIP($params->{$ip}, __($self->printableName()));
        checkCIDR($params->{$ip} . "/$params->{$mask}", __($self->printableName()));
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
    my $set = $self->fieldName() . '_set';
    my $ip =  $self->fieldName() . '_ip';
    my $mask =  $self->fieldName() . '_mask';

    # Filter IP and mask are optional
    unless (defined $params->{$set}) {
        return 0;
    }

    # Check if has something, set field is not empty
    return ($params->{$set} ne '');
}

# Method: _setValue
#
#     Set the value defined as a string in the
#     printableValue. That is, to define an IP Address you must set
#     a valid CIDR IP Address.
#
#   setname [xxx.xxx.xxx.xxx/xx]
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

    my ($set, $filterIp, $filterMask) = ($value =~ /([^\[\]]+)\s*\[\s*([0-9.]+)\/([0-9]+)\s*\]/);

    my $params = {
        $self->fieldName() . '_set'  => $set,
        $self->fieldName() . '_filterip'   => $filterIp,
        $self->fieldName() . '_filtermask' => $filterMask,
    };

    $self->setMemValue($params);
}

sub isEqualTo
{
    my ($self, $other) = @_;
    if (not $other->isa(__PACKAGE__)) {
        return undef;
    }

    if ($self->set() ne $other->set()) {
        return undef;
    } elsif ($self->filterIp() ne $other->filterIp()) {
        return undef;
    } elsif ($self->filterMask() ne $other->filterMask()) {
        return undef;
    }

    return 1;
}

sub populate
{
    my ($self) = @_;

    unless (defined $self->{populate}) {
        throw EBox::Exceptions::Internal('No populate function has been ' .
                                         'defined and it is required to fill ' .
                                         'the options');
    }
    return $self->{populate};
}

sub options
{
    my ($self) = @_;

    my $populateFunc = $self->populate();
    return &$populateFunc($self->model());
}

1;
