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

sub storeInGconf
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
