# Copyright (C) 2007 Warp Networks S.L.
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

# Class: EBox::Types::PortRange
#
#   Class to represent a type to store port ranges.
#   It has three possible values, the type of value stored is
#   stored in "range_type" and it can be:
#
#   "any" - it means all ports
#
#   "single_port" - just one port stored in single_port
#
#   "port_range" - two ports to indicate a range "from_port" and "to_port"
#
#   Use portRange() to check which type of port it has.
#   Use from(), to() to fetch port range.
#   Use single() to fetch single port.

#   Or you can use printableValue() to fecth an output which is nicely accepted
#   by iptables.
package EBox::Types::PortRange;

use strict;
use warnings;

use base 'EBox::Types::Abstract';

use EBox;
use EBox::Validate qw(checkPort);
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::External;
use EBox::Gettext;

# Constructor: new
#
#     Create a type which includes the protocol and the port from
#     Internet as a service
#
# Returns:
#
#     a <EBox::Types::PortRange> object
#
sub new
{
    my $class = shift;
    my %opts = @_;

    unless (exists $opts{'HTMLSetter'}) {
        $opts{'HTMLSetter'} ='/ajax/setter/portRangeSetter.mas';
    }
    unless (exists $opts{'HTMLViewer'}) {
        $opts{'HTMLViewer'} ='/ajax/viewer/textViewer.mas';
    }

    if ( defined ( $opts{'optional'} )
		    and $opts{'optional'} ) {
	    EBox::warn(q{PortRange type cannot be optional. You should select 'any' value});
    }
    
    $opts{optional} = 0;
    $opts{'type'} = 'portrange';

    my $self = $class->SUPER::new(%opts);

    # PortRange cannot be optional since you may select any
    $self->{'range_type'} = 'any' unless defined ( $self->{'range_type'} );
    bless($self, $class);
    return $self;
}

# Method: paramExist
#
#    Overrides <EBox::Types::Abstract::paramExist> method
#
sub paramExist
{
    my ($self, $params) = @_;

    my $name = $self->fieldName();
    my $type = $params->{$name . '_range_type'};

    return undef unless($type);
    
    return 1 if ($type eq 'any');

    if ($type eq 'range') {
        return undef unless(exists $params->{$name . '_from_port'} 
                            and exists $params->{$name . '_to_port'});
    } else {
        return undef unless (exists $params->{$name . '_single_port'});
    }
}

# Method: value 
#
#    Overrides <EBox::Types::Abstract::Value> method
#
sub value
{
    my ($self) = @_;

    my $type = $self->rangeType();
    if ($type eq 'range') {
        return $self->from() . ':' . $self->to() ;
    } elsif ($type eq 'single') {
        return $self->single();
    } else {
        return 'any';
    }
}


# Method: printableValue
#
#    Overrides <EBox::Types::Abstract::printableValue> method
#
sub printableValue
{
    my ($self) = @_;

    my $value = $self->value();

    if ($value eq 'any') {
        return __('any');
    }

    return $value;
}


# Method: compareToHash
#
#    Overrides <EBox::Types::Abstract::compareToHash> method
#
sub compareToHash
{
    my ($self, $hash) = @_;

    my $name = $self->fieldName();
    my $type = $hash->{$name . '_range_type'};
    my $from = $hash->{$name . '_from_port'};
    my $to = $hash->{$name . '_to_port'};
    my $single = $hash->{$name . '_single_port'};

    if ($self->rangeType() ne $type) {
        return 0;
    }

    if ($self->rangeType() eq 'single') {
        return 0 if ($single ne $self->single());
    }

    if ($self->rangeType() eq 'range') {
        return 0 if (($from ne $self->from()) or ($to ne $self->to()));
    }

    return 1;
}

# Method: isEqualTo
#
#    Overrides <EBox::Types::Abstract::isEqualTo> method
#
sub isEqualTo
{
    my ($self, $newObject) = @_;

    return ($self->printableValue() eq $newObject->printableValue());
}

# Method: fields
#
#    Overrides <EBox::Types::Abstract::fields> method
#
sub fields
{
    my ($self) = @_;

    my $name = $self->fieldName();
    my $type = $name . '_range_type';
    my $from = $name . '_from_port';
    my $to = $name . '_to_port';
    my $single = $name . '_single_port';

    return ($type, $from, $to, $single);
}

###
# Own methods
###

# Method: rangeTtype
#
#   Return the port range type which can be:
#
#       any
#       single
#       range
#
# Returns:
#
#   string containing the type
sub rangeType
{
    my ($self) = @_;

    return $self->{'range_type'};
}

# Method: from 
#
#   Return the "from" port 
#
# Returns:
#
#   string - containing the port
sub from 
{
    my ($self) = @_;

    return $self->{'from'};
}

# Method: to 
#
#   Return the "to" port 
#
# Returns:
#
#   string - containing the port
sub to 
{
    my ($self) = @_;

    return $self->{'to'};
}

# Method: single 
#
#   Return the single port 
#
# Returns:
#
#   string - containing the port
sub single 
{
    my ($self) = @_;

    return $self->{'single'};
}

# Method: rangeTypes
#
#     Get the range available (Static method)
#
# Returns:
#
#     array ref - the range types in a hash with the following elements
#              - value - the  range name
#              - printableValue - the protocol printable name
#
sub rangeTypes
  {

    my ($self) = @_;

    my @rangeTypes = (
		     {
		      value => 'any',
		      printableValue => __('Any'),
		     },
		     {
		      value => 'single',
		      printableValue => 'Single port',
		     },
		     {
		      value => 'range',
		      printableValue => 'Port range',
		     },
		    );

    return \@rangeTypes;
 }

# Group: Protected methods

# Method: _setMemValue
#
# Overrides:
#
#       <EBox::Types::Abstract::_setMemValue>
#
sub _setMemValue
  {

      my ($self, $params) = @_;

      my $name = $self->fieldName();
      $self->{'range_type'} = $params->{$name . '_range_type'};
      $self->{'from'} = $params->{$name . '_from_port'};
      $self->{'to'} = $params->{$name . '_to_port'};
      $self->{'single'} = $params->{$name . '_single_port'};

  }

# Method: _storeInGConf
#
# Overrides:
#
#       <EBox::Types::Abstract::_storeInGConf>
#
sub _storeInGConf
{
    my ($self, $gconfmod, $key) = @_;

    my $typeKey = "$key/" . $self->fieldName() . '_range_type';
    my $fromKey = "$key/" . $self->fieldName() . '_from_port';
    my $toKey = "$key/" . $self->fieldName() . '_to_port';
    my $singleKey = "$key/" . $self->fieldName() . '_single_port';

    for my $key ($fromKey, $toKey, $singleKey) {
        $gconfmod->unset($key);
    }

    my $type = $self->rangeType();
    $gconfmod->set_string($typeKey, $type);

    if ($type eq 'range') {
        $gconfmod->set_string($fromKey, $self->from());
        $gconfmod->set_string($toKey, $self->to());
    } elsif ($type eq 'single') {
        $gconfmod->set_string($singleKey, $self->single());
    }

}

# Method: _restoreFromHash
#
# Overrides:
#
#       <EBox::Types::Abstract::_restoreFromHash>
#
sub _restoreFromHash
{
    my ($self, $hash) = @_;

    my $name = $self->fieldName();
    $self->{'range_type'} = $hash->{$name . '_range_type'};
    $self->{'from'} = $hash->{$name . '_from_port'};
    $self->{'to'} = $hash->{$name . '_to_port'};
    $self->{'single'} = $hash->{$name . '_single_port'};

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

    my $name = $self->fieldName();
    my $type = $params->{$name . '_range_type'};

    return 1 if ($type eq 'any');

    if ($type eq 'range') {
        my $from = $params->{$name . '_from_port'};
        my $to = $params->{$name . '_to_port'};
        checkPort($from, $self->printableName());
        checkPort($to, $self->printableName());
        if ($to < $from) {
            throw EBox::Exceptions::InvalidData( data => $self->printableName(),
                      value => $from . ':' . $to,
                      advice => __x('"From" {from} must be greater than "To" {to}',
                                    from => $from, to => $to));
        }
    } else {
      checkPort($params->{$name . '_single_port'}, $self->printableName());
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

    my $name = $self->fieldName();
    my $type = $params->{$name . '_range_type'};

    return undef unless($type);

    return 1 if ($type eq 'any');

    if ($type eq 'range') {
        return undef unless(exists $params->{$name . '_from_port'} 
                            and ($params->{$name . '_from_port'} ne '')
                            and exists $params->{$name . '_to_port'}
                            and ($params->{$name . '_to_port'}) ne '');
    } else {
        return undef unless (exists $params->{$name . '_single_port'}
                             and ($params->{$name . '_single_port'} ne ''));
    }

    return 1;

}

1;
