package Authen::Krb5::Easy;

require 5.005_62;
use strict;
use warnings;

require Exporter;
require DynaLoader;

our @ISA = qw(Exporter DynaLoader);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Authen::Krb5::Easy ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	kinit kdestroy kexpires kerror kcheck kexpired
) ] );

#our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);
our $VERSION = '0.90';

bootstrap Authen::Krb5::Easy $VERSION;

# Preloaded methods go here.

sub kexpired()
{
	return kexpires() < time() ? 1 : 0;
}

sub kerror()
{
	return "" . get_error_while_doing() . ": " . get_error_string() . "\n";
}

sub kcheck($$)
{
	my($keytab, $princ) = @_;

	if(kexpired())
	{
		return(kinit($keytab, $princ));
	}
	return 1;
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Authen::Krb5::Easy - Simple Kerberos 5 interaction

=head1 SYNOPSIS

 use Authen::Krb5::Easy qw{kinit kexpires kexpired kcheck kdestroy};
  
 kinit("keytab", "someone") || die kerror();

 # how long until the ticket expires?
 $time_left = kexpires();

 # has the ticket expired?
 if(kexpired())
 {
 	print "expired!\n";
 }

 # check for expiration and get new ticket if expired
 kcheck("keytab", "someone") || die kerror();
 
 # destroy current ticket
 kdestroy();

=head1 DESCRIPTION

This allows simple access to getting kerberos 5 ticket granting tickets using a keytab file.

=head1 FUNCTIONS

All functions will need to be imported.

=over 4

=item kinit($keytab, $principle)

This uses the keytab file specified in $keytab and uses it to acquire a ticket granting ticket for $principle. This is functionally equivalent to system("kinit -k -t $keytab $principle"), but is done directly through the kerberos libraries.

=item kdestroy()

Erases all credentials in the ticket file.

=item kerror()

returns an error string ended with a "\n" that describes what error happened.

=item kcheck($keytab, $principle)

Checks to see if the ticket has expired, and if it has, get a new one using $keytab and $principle.

=item kexpires()

Returns the seconds since the epoch that the ticket will expire or 0.

=item kexpired()

Returns true if the ticket has expired.

=back

=head1 COPYRIGHT

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

Copyright 2002 Ed Schaller

=head1 AUTHOR

Ed Schaller schallee@darkmist.net

=head1 SEE ALSO

kerberos(1), kinit(1), kdestroy(1), klist(1), perl(1).

=cut
