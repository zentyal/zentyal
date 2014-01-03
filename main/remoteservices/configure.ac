AC_INIT([zentyal-remoteservices], [2.2.17])

AC_CONFIG_AUX_DIR([config])
AC_CONFIG_SRCDIR([src/EBox/RemoteServices.pm])

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
src/EBox/Makefile
src/EBox/CGI/Makefile
src/EBox/CGI/Backup/Makefile
src/EBox/CGI/Wizard/Makefile
src/EBox/Event/Makefile
src/EBox/Event/Dispatcher/Makefile
src/EBox/RemoteServices/Makefile
src/EBox/RemoteServices/t/Makefile
src/EBox/RemoteServices/Audit/Makefile
src/EBox/RemoteServices/Exceptions/Makefile
src/EBox/RemoteServices/Composite/Makefile
src/EBox/RemoteServices/Job/Makefile
src/EBox/RemoteServices/Model/Makefile
src/EBox/RemoteServices/Server/Makefile
src/EBox/RemoteServices/Server/t/Makefile
src/EBox/RemoteServices/Subscription/Makefile
src/EBox/RemoteServices/Subscription/t/Makefile
src/EBox/RemoteServices/Types/Makefile
src/scripts/Makefile
src/templates/Makefile
src/templates/RemoteServices/Makefile
src/templates/RemoteServices/Backup/Makefile
src/templates/RemoteServices/Wizard/Makefile
schemas/Makefile
schemas/sql/Makefile
stubs/Makefile
www/Makefile
Makefile
])

AC_OUTPUT
