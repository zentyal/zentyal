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

# TODO 
# 	Document this class
#	Fix the method naming, some names such as
#	setMemValue and memValue are so broken!!!
#
package EBox::Types::Abstract;
use strict;
use warnings;

sub new
{
        my $class = shift;
	my %opts = @_;
	my $self = {@_};

        bless($self, $class);
        return $self;
}


sub type
{
	my ($self) = @_;

	return $self->{'type'};

}

sub class
{
	my ($self) = @_;

	return $self->{'class'};
}

sub unique
{
	my ($self) = @_;

	return $self->{'unique'};
}

sub editable
{
	my ($self) = @_;

	return $self->{'editable'};
}

sub fieldName
{
	my ($self) = @_;

	return $self->{'fieldName'};
}

sub fields
{
	my ($self) = @_;

	return ($self->fieldName());
}

sub printableName
{
	my ($self) = @_;

	return $self->{'printableName'};
}

sub printableValue
{
	my ($self) = @_;

	return $self->filter();
}

# Method: filter
#
# 	This method is used to filter the output of printableValue
#
# Returns:
#	
#	Output filtered
sub filter
{
	my ($self) = @_;

	my $filterFunc = $self->{'filter'};
	if ($filterFunc) {
		return (&$filterFunc($self->{'value'}));
	} else {
		return $self->{'value'};
	}

}


sub value
{
	my ($self) = @_;

	return $self->{'value'};
}

sub trailingText
{
	my ($self) = @_;

	return $self->{'trailingText'};
}

sub leadingText
{
	my ($self) = @_;

	return $self->{'leadingText'};
}

sub setOptional # (optional)
  {

    my ($self, $optional) = @_;

    $self->{'optional'} = $optional;

  }

sub optional
{
	my ($self) = @_;

	return $self->{'optional'};
}

sub paramExist
{

}

sub paramIsValid
{

}

sub storeInGConf
{

}

sub restoreFromGconf
{

}

sub setMemValue
{

}

sub memValue
{

}

sub compareToHash
{

}

sub isEqualTo
{

}

sub HTMLSetter
{

}

1;
