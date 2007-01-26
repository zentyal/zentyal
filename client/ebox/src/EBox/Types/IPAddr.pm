package EBox::Types::IPAddr;

use strict;
use warnings;

use base 'EBox::Types::Abstract';


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
        my ($self, $params) = @_;

	my $ip =  $self->fieldName() . '_ip';
 	my $mask =  $self->fieldName() . '_mask';
	
        return (defined($params->{$ip}) and defined($params->{$mask}));

}

sub setMemValue
{
	my ($self, $params) = @_;
	
	my $ip =  $self->fieldName() . '_ip';
 	my $mask =  $self->fieldName() . '_mask';
	
	unless ($self->paramExist($params)) {
		throw EBox::Exceptions::MissingArgument($self->printableName());
	}
	
	unless ($self->paramExist($params)) {
		throw EBox::Exceptions::MissingArgument($self->printableName());
	}

	$self->{'ip'} = $params->{$ip};
	$self->{'mask'} = $params->{$mask};
}

sub printableValue
{
	my ($self) = @_;

	if (exists($self->{'ip'}) and exists($self->{'mask'})) {
		return "$self->{'ip'}/$self->{'mask'}";
	} else   {
		return "";
	}
	
}

sub paramIsValid
{
	my ($self, $params) = @_;

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
 
 	my $ipKey = "$key/" . $self->fieldName() . '_ip';
 	my $maskKey = "$key/" . $self->fieldName() . '_mask';
	
        $gconfmod->set_string($ipKey, $self->{'ip'});
        $gconfmod->set_string($maskKey, $self->{'mask'});
}

sub compareToHash
{
	my ($self, $hash) = @_;

	my ($oldIp, $oldMask) = $self->_ipNetmask();
	my $ip = $self->fieldName() . '_ip';
 	my $mask = $self->fieldName() . '_mask';
	
	if ($oldIp ne $hash->{$ip}) {
		return 0;
	}

	if ($oldMask ne $hash->{$mask}) {
		return 0;
	}

	return 1;
}

sub restoreFromHash
{
	my ($self, $hash) = @_;

 	my $ip = $self->fieldName() . '_ip';
 	my $mask = $self->fieldName() . '_mask';
	
	$self->{'ip'} = $hash->{$ip};
	$self->{'mask'} = $hash->{$mask};
}

sub isEqualTo
{
	my ($self, $newObject) = @_;

	return ($self->printableValue() eq $newObject->printableValue());
}

sub HTMLSetter
{

        return 'ipaddrSetter';

}

sub HTMLViewer
{
	return 'textViewer';
}

sub fields
{
	my ($self) = @_;
	
	my $ip = $self->fieldName() . '_ip';
 	my $mask = $self->fieldName() . '_mask';
	
	return ($ip, $mask);
}

sub ip
{
	my ($self) = @_;

	return $self->{'ip'};
}

sub mask 
{
	my ($self) = @_;

	return $self->{'mask'};
}

# Helper funcionts
sub _ipNetmask
{
	my ($self) = @_;

	return ($self->{'ip'}, $self->{'mask'});
	
}


1;
