AC_INIT([EBox-CA], [0.12.100])

AC_CONFIG_AUX_DIR([config])
AC_CONFIG_SRCDIR([src/EBox/CA.pm])

AM_INIT_AUTOMAKE([foreign])

AM_MAINTAINER_MODE


AC_DEFINE_DIR(DATADIR, datadir)
AC_DEFINE_DIR(LIBDIR, libdir)

AC_ARG_ENABLE([runtime-tests],
	[ --disable-runtime-tests	Do not try to test runtime dependencies],
	,
	enable_runtime_tests=yes)

if test "x$enable_runtime_tests" = "xyes" ; then
	AC_CHECK_PROG(PERL, perl, perl, none)
	AC_CHECK_PROG(GCONFTOOL, gconftool-2, gconftool-2, none)

	if test "$PERL" = "none" ; then
		AC_MSG_ERROR(perl not found)
	fi
	if test "$GCONFTOOL" = "none" ; then
		AC_MSG_ERROR(gconftool not found)
	fi

	perlpath=`$PERL -e 'foreach (@INC) { print "$_\n";}' | grep "^$DATADIR" | head -1`
	if test -z "$perlpath" ; then
	perlpath=`$PERL -e 'foreach (@INC) { print "$_\n";}' | grep "^$prefix" | head -1`
	fi

	AM_GCONF_SOURCE_2

	AC_CONF_EBOX
else
	GCONF_SCHEMAS_INSTALL_FALSE=
	GCONF_SCHEMAS_INSTALL_TRUE='#'
fi
AM_PO_SUBDIRS

if test -z "$perlpath" ; then
	perlpath="$DATADIR/perl5/"
	AC_MSG_NOTICE([Perl libraries will be installed in $perlpath, make sure to
	include it in your path])
else
	AC_MSG_NOTICE([Perl libraries will be installed in $perlpath])
fi

AC_DEFINE_DIR(PERLPATH, perlpath)

AC_CONFIG_FILES([
conf/Makefile
migration/Makefile
src/Makefile
src/EBox/Makefile
src/EBox/CGI/Makefile
src/EBox/CA/Makefile
src/EBox/t/Makefile
src/templates/Makefile
schemas/Makefile
Makefile
])

AC_CONFIG_FILES([po/Makefile], [AM_POSTPROCESS_PO_MAKEFILE])
AC_OUTPUT
