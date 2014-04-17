AC_INIT([zentyal-samba], [2.2.1])

AC_CONFIG_AUX_DIR([config])
AC_CONFIG_SRCDIR([src/EBox/Samba.pm])

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

	perlpath=`$PERL -e 'foreach (@INC) { print "$_\n";}' | grep "^$DATADIR" | head -1`
	if test -z "$perlpath" ; then
	perlpath=`$PERL -e 'foreach (@INC) { print "$_\n";}' | grep "^$prefix" | head -1`
	fi

	if test "$PERL" = "none" ; then
		AC_MSG_ERROR(perl not found)
	fi
fi

AC_CONF_EBOX($enable_runtime_tests)

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
src/Makefile
src/EBox/Makefile
src/EBox/Samba/Makefile
src/EBox/Samba/Composite/Makefile
src/EBox/Samba/Model/Makefile
src/EBox/Samba/Types/Makefile
src/EBox/rootTests/Makefile
src/EBox/CGI/Makefile
src/templates/Makefile
src/templates/ajax/Makefile
src/templates/ajax/viewer/Makefile
src/scripts/Makefile
schemas/Makefile
schemas/sql/Makefile
stubs/Makefile
Makefile
])

AC_OUTPUT
