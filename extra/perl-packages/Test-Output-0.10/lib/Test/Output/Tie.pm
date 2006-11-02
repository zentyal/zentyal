package Test::Output::Tie;

our $VERSION='0.02';

use strict;
use warnings;

=head1 DESCRIPTION

You are probably more interested in reading Test::Output.

This module is used to tie STDOUT and STDERR in Test::Output.

=cut

=head2 TIEHANDLE

The constructor for the class.

=cut

sub TIEHANDLE {
  my $class = shift;
  my $scalar = '';
  my $obj = shift || \$scalar; 

  bless( $obj, $class);
}

=head2 PRINT

This method is called each time STDERR or STDOUT are printed to.

=cut

sub PRINT {
    my $self = shift;
    $$self .= join('', @_);
}

=head2 PRINTF

This method is called each time STDERR or STDOUT are printed to with C<printf>.

=cut

sub PRINTF {
    my $self = shift;
    my $fmt  = shift;
    $$self .= sprintf $fmt, @_;
}

=head2 FILENO

=cut
sub FILENO {}

=head2 read

This function is used to return all output printed to STDOUT or STDERR.

=cut

sub read {
    my $self = shift;
    my $data = $$self;
    $$self = '';
    return $data;
}

=head1 ACKNOWLEDGMENTS

This code was taken from Test::Simple's TieOut.pm maintained 
Michael G Schwern. TieOut.pm was originally written by chromatic.

Thanks for the idea and use of the code.

=cut

1;
