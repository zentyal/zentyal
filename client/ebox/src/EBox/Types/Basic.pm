package EBox::Types::Basic;
use strict;
use warnings;

use base 'EBox::Types::Abstract';

use EBox::Exceptions::MissingArgument;

sub new
{
        my $class = shift;
	my %opts = @_;
	my $self = $class->SUPER::new(@_);

        bless($self, $class);
        return $self;
}

sub paramExist
{
	my ($self, $params, $field) = @_;

	return (defined($params->{$self->fieldName()}));

}

sub setMemValue
{
	my ($self, $params) = @_;

	if ($self->optional() == 0) {
		unless ($self->paramExist($params)) {
			throw EBox::Exceptions::MissingArgument(
						$self->printableName());
		}
	}

	$self->{'value'} = $params->{$self->fieldName()};
}

sub memValue
{
	my ($self) = @_;

	return $self->{'value'};
}

sub compareToHash
{
	my ($self, $hash) = @_;

	return ($self->memValue() eq $hash->{$self->fieldName()});
}

sub restoreFromHash
{
	my ($self, $hash) = @_;

	$self->{'value'} = $hash->{$self->fieldName()};
}

sub isEqualTo
{
	my ($self, $newObject) = @_;

	my $oldValue = $self->{'value'};
	my $newValue = $newObject->memValue();

	return ($oldValue eq $newValue);
}

1;
