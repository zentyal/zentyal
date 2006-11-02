=for gpg
-----BEGIN PGP SIGNED MESSAGE-----
Hash: SHA1

=head1 NAME

Readonly::XS - Companion module for Readonly.pm, to speed up read-only
scalar variables.

=head1 VERSION

This document describes version 1.04 of Readonly::XS, December 6, 2005.

=cut

package Readonly::XS;

use strict;
use warnings;
use vars qw($VERSION $MAGIC_COOKIE %PL_COMPAT);

$VERSION = '1.04';

require XSLoader;
XSLoader::load('Readonly::XS', $VERSION);


# It is an error to use this from any module but Readonly.
# But sooner or later, someone will.
BEGIN
{
    no warnings 'uninitialized';
    if ($MAGIC_COOKIE ne "Do NOT use or require Readonly::XS unless you're me.")
    {
        require Carp;
        Carp::croak "Readonly::XS is not a standalone module. You should not use it directly.";
    }
}

sub import
{
    my $func;
    for $func (qw/is_sv_readonly make_sv_readonly/)
    {
        no strict 'refs';
        no warnings 'redefine';
        *{"Readonly::$func"} = \&$func;
    }
    $Readonly::XSokay = 1;
}


1;
__END__

=head1 SYNOPSIS

  Install this module, but do not use it.

=head1 DESCRIPTION

The Readonly module (q.v.) is an effective way to create
non-modifiable variables.  However, it's relatively slow.

The reason it's slow is that is implements the read-only-ness of
variables via tied objects.  This mechanism is inherently slow.  Perl
simply has to do a lot of work under the hood to make tied variables
work.

This module corrects the speed problem, at least with respect to
scalar variables.  When Readonly::XS is installed, Readonly uses it to
access the internals of scalar variables.  Instead of creating a
scalar variable object and tying it, Readonly simply flips the
SvREADONLY bit in the scalar's FLAGS structure.

Readonly arrays and hashes are not sped up by this, since the
SvREADONLY flag only works for scalars.  Arrays and hashes always use
the tie interface.

Why implement this as a separate module?  Because not everyone can use
XS.  Not everyone has a C compiler.  Also, installations with a
statically-linked perl may not want to recompile their perl binary
just for this module.  Rather than render Readonly.pm useless for
 these people, the XS portion was put into a separate module.

Programs that you write do not need to know whether Readonly::XS is
installed or not.  They should just "use Readonly" and let Readonly
worry about whether or not it can use XS.  If the Readonly::XS is
present, Readonly will be faster.  If not, it won't.  Either way, it
will still work, and your code will not have to change.

Your program can check whether Readonly.pm is using XS or not by
examining the $Readonly::XSokay variable.  It will be true if the
XS module was found and is being used.  Please do not change this
variable.

=head2 EXPORTS

None.

=head1 SEE ALSO

Readonly.pm

=head1 AUTHOR / COPYRIGHT

Eric Roode, roode@cpan.org

Copyright (c) 2003-2005 by Eric J. Roode. All Rights Reserved.
This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

To avoid my spam filter, please include "Perl", "module", or this
module's name in the message's subject line, and/or GPG-sign your
message.

=cut

=begin gpg

-----BEGIN PGP SIGNATURE-----
Version: GnuPG v1.4.1 (Cygwin)

iD8DBQFDlfagY96i4h5M0egRAmXoAJkBZAkcF+66S6d6Ay0Tnb0DYi1KLwCgkfTP
5D83z+YoANwU9IcN+zS5OvM=
=6TLK
-----END PGP SIGNATURE-----

=end gpg
