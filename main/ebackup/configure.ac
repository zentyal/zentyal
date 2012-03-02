AC_INIT([zentyal-ebackup], [2.2.3])

AC_CONFIG_AUX_DIR([config])
AC_CONFIG_SRCDIR([src/EBox/EBackup.pm])

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
conf/Makefile
src/Makefile
src/templates/Makefile
src/templates/ajax/Makefile
src/scripts/Makefile
src/EBox/Makefile
src/EBox/EBackup/Makefile
src/EBox/EBackup/Types/Makefile
src/EBox/Event/Makefile
src/EBox/Event/Watcher/Makefile
src/EBox/Model/Makefile
src/EBox/Composite/Makefile
src/EBox/Exceptions/Makefile
src/EBox/Exceptions/EBackup/Makefile
schemas/Makefile
schemas/sql/Makefile
schemas/urls/Makefile
Makefile
])

AC_OUTPUT
