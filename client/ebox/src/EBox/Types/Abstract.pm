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
