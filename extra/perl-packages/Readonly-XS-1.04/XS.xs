=for gpg
-----BEGIN PGP SIGNED MESSAGE-----
Hash: SHA1

=cut

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"


MODULE = Readonly::XS		PACKAGE = Readonly::XS		

int
is_sv_readonly(sv)
    SV *sv
PROTOTYPE: $
CODE:
    RETVAL = SvREADONLY(sv);
OUTPUT:
    RETVAL

void
make_sv_readonly(sv)
    SV *sv
PROTOTYPE: $
CODE:
    SvREADONLY_on(sv);

=begin gpg

-----BEGIN PGP SIGNATURE-----
Version: GnuPG v1.2.1 (GNU/Linux)

iD8DBQE+wOWGY96i4h5M0egRAjBaAKDvEihLkvuJZv3zqbzaa09JHmbLGACaA0di
jJLNeedS+HAADlX0o8Nl8tA=
=zZ/c
-----END PGP SIGNATURE-----

=end gpg

=cut
