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

package EBox::Types::Int;

use strict;
use warnings;

use base 'EBox::Types::Basic';


sub new
{
        my $class = shift;
	my %opts = @_;
	my $self = $class->SUPER::new(@_);


        bless($self, $class);
        return $self;
}

sub paramIsValid
{
	my ($self, $params) = @_;

	my $value = $params->{$self->fieldName()};

	unless (defined($value)) {
		return 0;
	}

	unless ($value =~ /^[0-9]+$/) {
		return 0;
	}

	return 1;

}

sub size
{
	my ($self) = @_;

	return $self->{'size'};
}

sub storeInGConf
{
	my ($self, $gconfmod, $key) = @_;

	my $fieldKey ="$key/" . $self->fieldName();

	if (defined($self->memValue()) and $self->memValue() ne '') {
		$gconfmod->set_int($fieldKey, $self->memValue());
	} else {
		$gconfmod->unset($fieldKey);
	}
}

sub HTMLSetter
{
	
	return 'textSetter';

}

sub HTMLViewer
{
        return 'textViewer';
}

1;
