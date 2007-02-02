package EBox::Types::Boolean;

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

	return 1;

}
sub storeInGconf
{
        my ($self, $gconfmod, $key) = @_;
 
	if (defined($self->memValue())) {
        	$gconfmod->set_bool("$key/" . $self->fieldName(), 
			$self->memValue());
	} else {
		$gconfmod->unset("$key/" . $self->fieldName());
	}
}

sub HTMLSetter
{

        return 'booleanSetter';

}

sub HTMLViewer
{
	return 'booleanViewer';
}
1;
