AC_INIT([zentyal-usercorner], [2.1.2])

AC_CONFIG_AUX_DIR([config])
AC_CONFIG_SRCDIR([src/EBox/UserCorner.pm])

AM_INIT_AUTOMAKE([foreign])

AM_MAINTAINER_MODE

AC_DEFINE_DIR(DATADIR, datadir)
AC_DEFINE_DIR(LIBDIR, libdir)
AC_DEFINE_DIR(LOCALSTATEDIR, localstatedir)

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
conf/usercorner-log.conf
src/Makefile
src/cgi/Makefile
src/EBox/Makefile
src/EBox/UserCorner/Makefile
src/EBox/UserCorner/CGI/Makefile
src/EBox/UserCorner/CGI/Dashboard/Makefile
src/EBox/UserCorner/CGI/Login/Makefile
src/EBox/UserCorner/CGI/Logout/Makefile
src/EBox/UserCorner/Model/Makefile
src/templates/Makefile
src/scripts/Makefile
schemas/Makefile
stubs/Makefile
Makefile
])

AC_OUTPUT
