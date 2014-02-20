package ClamAV::XS;

use 5.014002;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use ClamAV::XS ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(

) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(

);

our $VERSION = '0.01';

require XSLoader;
XSLoader::load('ClamAV::XS', $VERSION);

# Preloaded methods go here.

1;
__END__

=head1 NAME

ClamAV::XS - Perl bindings for ClamAV library

=head1 SYNOPSIS

  use ClamAV::XS;
  my $sigs = ClamAV::XS::signatures()

=head1 DESCRIPTION

ClamAV::XS allows to get the number of signatures of your ClamAV
installation. It croaks if we cannot get the database directory or
there is an error counting this number.

=head2 EXPORT

None by default.

=head1 SEE ALSO

libclamav - http://www.clamav.net/doc/latest/html/node34.html

=head1 AUTHOR

Samuel Cabrero <scabrero@zentyal.com>
Enrique J. Hernández <ejhernandez@zentyal.com>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 Zentyal S.L.

This library is free software; you can redistribute it and/or modify
it under the same terms as GPL-2.


=cut
