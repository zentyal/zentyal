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

package EBox::Types::Boolean;

use strict;
use warnings;

use base 'EBox::Types::Basic';

# Group: Public methods

sub new
{
        my $class = shift;
    	my %opts = @_;

        unless (exists $opts{'HTMLSetter'}) {
            $opts{'HTMLSetter'} ='/ajax/setter/booleanSetter.mas';
        }
        unless (exists $opts{'HTMLViewer'}) {
            $opts{'HTMLViewer'} ='/ajax/viewer/booleanViewer.mas';
        }
	$opts{'type'} = 'boolean';

        my $self = $class->SUPER::new(%opts);
        bless($self, $class);
        return $self;
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

        $self->{'value'} = $params->{$self->fieldName()};
        $self->{'value'} = 0 unless ( defined ($self->{'value'}) );

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

	if (defined($self->memValue())) {
        	$gconfmod->set_bool("$key/" . $self->fieldName(),
			$self->memValue());
	} else {
		$gconfmod->unset("$key/" . $self->fieldName());
	}
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
      my $param =  $params->{$self->fieldName()};

      if ( defined ( $param )) {
          return 1;
      } else {
          if ( $self->optional() ) {
              return 0;
          } else {
              # We assume when the parameter is compulsory and it is not
              # in params, that the type value is false. This is a side
              # effect from HTTP protocol which does not send a value when
              # a checkbox is not checked
              return 1;
          }
      }

  }





# Method: cmp
#
# Overrides:
#
#       <EBox::Types::Abstract::cmp>
#
sub cmp
{
    my ($self, $other) = @_;
    
    if ((ref $self) ne (ref $other)) {
        return undef;
    }

    my $ownValue = $self->value();
    my $otherValue = $other->value();


    if ($ownValue and (not $otherValue)) {
        return 1;
    }
    elsif ((not $ownValue) and $otherValue) {
        return -1;
    }
    else {
        # the two values are both true or false
        return 0;
    }

}


# Method: isEqualTo 
#
# Overrides:
#
#       <EBox::Types::Abstract::isEqualTo>
#
sub isEqualTo 
{
    my ($self, $other) = @_;
    return $self->cmp($other) == 0;
}

1;
