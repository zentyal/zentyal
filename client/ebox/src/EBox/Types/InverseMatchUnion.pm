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

# Class: EBox::Types::InverseMatchUnion
#
# 	This class inherits from <EBox::Types:Union> to add
# 	inverse match support
#
#   FIXME: This package shouldn't exist as we should provide inverse match
#   feature form abstract types and provide a real OO approach, not this
#   ugly repetition of code in InverseMatch* types.
#
#   We are repeating ourselves, this sucks so freaking much.
#   
#
package EBox::Types::InverseMatchUnion;

use strict;
use warnings;

use base 'EBox::Types::Union';

# Group: Public methods

sub new
{
	my $class = shift;
	my %opts = @_;

	unless (exists $opts{'HTMLSetter'}) {
		$opts{'HTMLSetter'} ='/ajax/setter/inverseMatchUnionSetter.mas';
	}
	$opts{'type'} = 'union';
	
	my $self = $class->SUPER::new(%opts);
	bless($self, $class);
	return $self;
}

sub inverseMatchField
{
    my ($self) = @_;

    return $self->fieldName() . '_inverseMatch';
}

#sub restoreFromHash
#{
#    my ($self, $hash) = @_;
#
#    $self->SUPER::restoreFromHash($hash);
#
#    $self->{'inverseMatch'} = $hash->{$self->fieldName() . '_inverseMatch'};
#}
#
#sub storeInGconf
#{
#    my ($self, $gconfmod, $key) = @_;
#
#    $self->SUPER::storeInGconf($gconfmod, $key);
#    $gconfmod->set_bool("$key/" . $self->inverseMatchField(),
#            $self->inverseMatch());
#}


sub compareToHash
{
    my ($self, $hash) = @_;

    unless  ($self->inverseMatch() 
            eq $hash->{$self->inverseMatchField()}) {

        return undef;
    }

    return $self->SUPER::compareToHash($hash);
}

sub isEqualTo
{
    my ($self, $newObject) = @_;

    unless  ($self->SUPER::isEqualTo($newObject)) {
        return undef;

    }

    return ($self->inverseMatch() eq $newObject->inverseMatch());
}

sub printableValue
{
    my ($self) = @_;

    my $printValue = $self->SUPER::printableValue();

    if ($self->inverseMatch()) {
        $printValue = "! $printValue";
    }

    return $printValue;
}

sub fields
{
    my ($self) = @_;

    return ($self->inverseMatchField(), $self->SUPER::fields());
}

sub inverseMatch 
{
    my ($self) = @_;

    return $self->{'inverseMatch'};

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

    $self->SUPER::_setMemValue($params);

    $self->{'inverseMatch'} = $params->{$self->inverseMatchField()};
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

    $self->SUPER::_storeInGConf($gconfmod, $key);
    $gconfmod->set_bool("$key/" . $self->inverseMatchField(),
            $self->inverseMatch());
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

    $self->SUPER::_restoreFromHash($hash);

    $self->{'inverseMatch'} = $hash->{$self->fieldName() . '_inverseMatch'};
}

1;
