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

	return $self->{'value'};
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
