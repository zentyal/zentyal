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

package EBox::Types::Select;

use strict;
use warnings;

use base 'EBox::Types::Basic';
use EBox;


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
 
        $gconfmod->set_string("$key/" . $self->fieldName(), $self->memValue());
}

sub HTMLSetter
{

        return 'selectSetter';

}

sub addOptions
{
	my ($self, $options) = @_;

	$self->{'options'} = $options;
}

sub options
{
	my ($self) = @_;

	return $self->{'options'};
}

sub printableValue
{
	my ($self) = @_;

	return '' unless (defined($self->{'options'}));

	foreach my $option (@{$self->options()}) {
		if ($option->{'value'} eq $self->{'value'}) {
			return $option->{'printableValue'};
		}
	}
	
}

sub value
{
	my ($self) = @_;

	return $self->{'value'};
}

sub HTMLViewer
{
	return 'textViewer';
}

1;
