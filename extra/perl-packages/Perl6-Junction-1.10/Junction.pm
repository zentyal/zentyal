package Perl6::Junction;
use strict;

use Perl6::Junction::All;
use Perl6::Junction::Any;
use Perl6::Junction::None;
use Perl6::Junction::One;

require Exporter;
our $VERSION = '1.10';

our @ISA       = qw/ Exporter /;
our @EXPORT_OK = qw/ all any none one /;


sub all {
  return Perl6::Junction::All->all(@_);
}


sub any {
  return Perl6::Junction::Any->any(@_);
}


sub none {
  return Perl6::Junction::None->none(@_);
}


sub one {
  return Perl6::Junction::One->one(@_);
}

1;


__END__

=head1 NAME

Perl6::Junction - Perl6 style Junction operators in Perl5.

=head1 SYNOPSIS

  use Perl6::Junction qw/ all any none one /;
  
  if (any(@grant) eq 'su') {
    ...
  }
  
  if (all($foo, $bar) >= 10) {
    ...
  }
  
  if (qr/^\d+$/ == all(@answers)) {
    ...
  }
  
  if (all(@input) <= @limits) {
    ...
  }
  
  if (none(@pass) eq 'password') {
    ...
  }
  
  if (one(@answer) == 42) {
    ...
  }

=head1 DESCRIPTION

This is a lightweight module which provides 'Junction' operators, the most 
commonly used being C<any> and C<all>.

Inspired by the Perl6 design docs, 
L<http://dev.perl.org/perl6/doc/design/exe/E06.html>.

Provides a limited subset of the functionality of L<Quantum::Superpositions>, 
see L</"SEE ALSO"> for comment.

Notice in the L</SYNOPSIS> above, that if you want to match against a 
regular expression, you must use C<==> or C<!=>. B<Not> C<=~> or C<!~>. You 
must also use a regex object, such as C<qr/\d/>, not a plain regex such as 
C</\d/>.


=head1 SUBROUTINES

=head2 all()

Returns an object which overloads the following operators:

  '<',  '<=', '>',  '>=', '==', '!=', 
  'lt', 'le', 'gt', 'ge', 'eq', 'ne', 

Returns true only if B<all> arguments test true according to the operator 
used.

=head2 any()

Returns an object which overloads the following operators:

  '<',  '<=', '>',  '>=', '==', '!=', 
  'lt', 'le', 'gt', 'ge', 'eq', 'ne', 

Returns true if B<any> argument tests true according to the operator used.

=head2 none()

Returns an object which overloads the following operators:

  '<',  '<=', '>',  '>=', '==', '!=', 
  'lt', 'le', 'gt', 'ge', 'eq', 'ne', 

Returns true only if B<no> argument tests true according to the operator 
used.

=head2 one()

Returns an object which overloads the following operators:

  '<',  '<=', '>',  '>=', '==', '!=', 
  'lt', 'le', 'gt', 'ge', 'eq', 'ne', 

Returns true only if B<one and only one> argument tests true according to 
the operator used.

=head1 EXPORT

'all', 'any', 'none', 'one', as requested.

All subroutines can be called by it's fully qualified name, if you don't 
want to export them.

  use Perl6::Junction;
  
  if (Perl6::Junction::any( @questions )) {
    ...
  }

=head1 WARNING

When comparing against a regular expression, you must remember to use a 
regular expression object: C<qr/\d/> B<Not> C</d/>. You must also use either 
C<==> or C<!=>. This is because C<=~> and C<!~> cannot be overriden.

=head1 TO DO

Add overloading for arithmetic operators, such that this works:

  $result = any(2,3,4) * 2;
  
  if ($result == 8) {...}

=head1 SUPPORT / BUGS

Submit to the CPAN bugtracker L<http://rt.cpan.org>

=head1 SEE ALSO

L<Quantum::Superpositions> provides the same functionality as this, and 
more. However, this module provides this limited functionality at a much 
greater runtime speed, with my benchmarks showing between 500% and 6000% 
improvment.

L<http://dev.perl.org/perl6/doc/design/exe/E06.html> - "The Wonderful World 
of Junctions".

=head1 AUTHOR

Carl Franks

=head1 COPYRIGHT AND LICENSE

Copyright 2005, Carl Franks.  All rights reserved.  

This library is free software; you can redistribute it and/or modify it under 
the same terms as Perl itself (L<perlgpl>, L<perlartistic>).

=cut

