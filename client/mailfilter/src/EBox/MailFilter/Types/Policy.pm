package EBox::MailFilter::Types::Policy;
use base 'EBox::Types::Select';

use strict;
use warnings;

use EBox::Gettext;

use Perl6::Junction qw(all);

my $allPolicies = all qw(D_PASS D_REJECT D_BOUNCE D_DISCARD);

sub new
{
    my ($class, %params) = @_;
    
    $params{editable} = 1;
    $params{populate} = \&_populate;
    
    my $self = $class->SUPER::new(%params);
    
    bless $self, $class;
    return $self;
}


sub _populate
{
    my @elements = (
                    { value => 'D_PASS',    printableValue => __('Pass') },
                    { value => 'D_REJECT',  printableValue => __('Reject') },
                    { value => 'D_BOUNCE',  printableValue => __('Bounce') },
                    { value => 'D_DISCARD', printableValue => __('Discard') },
                   );
    
    return \@elements;
}


sub _paramIsValid
{
    my ($self, $params) = @_;
    
    my $value = $params->{$self->fieldName()};
    $self->checkPolicy($value);
}

sub checkPolicy
{
    my ($class, $policy) = @_;
    if ($policy ne $allPolicies) {
        throw EBox::Exceptions::InvalidData(
                                            data  => __(q{Mailfilter's policy}),
                                            value => $policy,
                                       );
    }
}


1;
