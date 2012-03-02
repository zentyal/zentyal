AC_INIT([zentyal-monitor], [2.2.3])

AC_CONFIG_AUX_DIR([config])
AC_CONFIG_SRCDIR([src/EBox/Monitor.pm])

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

	if test "$PERL" = "none" ; then
		AC_MSG_ERROR(perl not found)
	fi

	perlpath=`$PERL -e 'foreach (@INC) { print "$_\n";}' | grep "^$DATADIR" | head -1`
	if test -z "$perlpath" ; then
	perlpath=`$PERL -e 'foreach (@INC) { print "$_\n";}' | grep "^$prefix" | head -1`
	fi

	AC_CONF_EBOX
fi

if test -z "$perlpath" ; then
	perlpath="$DATADIR/perl5/"
	AC_MSG_NOTICE([Perl libraries will be installed in $perlpath, make sure to
	include it in your path])
else
	AC_MSG_NOTICE([Perl libraries will be installed in $perlpath])
fi

AC_DEFINE_DIR(PERLPATH, perlpath)

AC_CONFIG_FILES([
src/Makefile
src/templates/Makefile
src/scripts/Makefile
src/EBox/Makefile
src/EBox/CGI/Makefile
src/EBox/Collectd/Makefile
src/EBox/Event/Makefile
src/EBox/Event/Watcher/Makefile
src/EBox/Event/Watcher/t/Makefile
src/EBox/Monitor/Makefile
src/EBox/Monitor/Measure/Makefile
src/EBox/Monitor/Measure/t/Makefile
src/EBox/Monitor/Model/Makefile
src/EBox/Monitor/Types/Makefile
src/EBox/Monitor/Exceptions/Makefile
schemas/Makefile
schemas/urls/Makefile
stubs/Makefile
Makefile
])

AC_OUTPUT
