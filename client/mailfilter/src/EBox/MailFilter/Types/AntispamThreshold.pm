# Copyright (C) 2008 Warp Networks S.L.
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

package EBox::MailFilter::Types::AntispamThreshold;

use strict;
use warnings;

use base 'EBox::Types::Text';

# eBox uses
use EBox;
use EBox::Gettext;
use EBox::Exceptions::InvalidData;

use constant MAX => 100;
use constant MIN => -100;


# Group: Public methods

sub new
{
        my $class = shift;
        my %opts = @_;

        unless (exists $opts{'HTMLSetter'}) {
            $opts{'HTMLSetter'} ='/ajax/setter/textSetter.mas';
        }
        unless (exists $opts{'HTMLViewer'}) {
            $opts{'HTMLViewer'} ='/ajax/viewer/textViewer.mas';
        }
        

        $opts{'localizable'} = 0;
        my $self = $class->SUPER::new(%opts);

        bless($self, $class);
        return $self;
}




# Method: cmp
#
# Overrides:
#
#      <EBox::Types::String::cmp>
#
sub cmp
{
    my ($self, $compareType) = @_;

    unless ( $self->type() eq $compareType->type() ) {
        return undef;
    }

    return $self->value() <=> $compareType->value();

}


# Method: positive
#
#  wether only positive non-zero numbers are allowed
sub positive
{
    my ($self) = @_;
    return $self->{positive};
}


# Group: Protected methods

# Method: _storeInGConf
#
# Overrides:
#
#       <EBox::Types::Text::_storeInGConf>
#
sub _storeInGConf
{
        my ($self, $gconfmod, $key) = @_;

        my $keyField = "$key/" . $self->fieldName();

        if ($self->memValue()) {
                $gconfmod->set_string($keyField, $self->memValue());
        } else {
                $gconfmod->unset($keyField);
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

    my $value = $params->{$self->fieldName()};

    
    my $numberOk = 0;
    if ($value =~ m{\.$}) {
        # the number cannot end with decimal point
        $numberOk = 0;
    }
    else {
        my $floatRegex = '\d+\.?\d*';
        $numberOk = ($value =~ m{$floatRegex});
    }



    unless ($numberOk) {
        throw EBox::Exceptions::InvalidData( data   => $self->printableName(),
                                             value  => $value,
                                             advice =>
                __('Write down a decimal number')
                                           );
    }

    if ($self->positive() and ($value <= 0)) {
        my $advice = __('Only non-zero positive numbers are allowed');
        throw EBox::Exceptions::InvalidData( data   => $self->printableName(),
                                             value  => $value,
                                             advice => $advice
                        );
    }


    if ($value > MAX) {
        my $advice = __x('Write down a number lesser than {m}', m => MAX);
        throw EBox::Exceptions::InvalidData( data   => $self->printableName(),
                                             value  => $value,
                                             advice => $advice
                        );
    }
    elsif ($value < MIN) {
        my $advice = __x('Write down a number greater  than {m}', m => MIN);
        throw EBox::Exceptions::InvalidData( data   => $self->printableName(),
                                             value  => $value,
                                             advice => $advice
                        );
    }


    return 1;

}




1;
