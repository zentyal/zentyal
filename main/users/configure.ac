AC_INIT([zentyal-users], [2.2.10])

AC_CONFIG_AUX_DIR([config])
AC_CONFIG_SRCDIR([src/EBox/UsersAndGroups.pm])

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
src/Makefile
src/EBox/Makefile
src/EBox/UsersAndGroups/Makefile
src/EBox/UsersAndGroups/Model/Makefile
src/EBox/UsersAndGroups/Composite/Makefile
src/EBox/UsersAndGroups/Types/Makefile
src/EBox/UserCorner/Makefile
src/EBox/rootTests/Makefile
src/EBox/CGI/Makefile
src/EBox/CGI/Wizard/Makefile
src/templates/Makefile
src/templates/ajax/Makefile
src/templates/Wizard/Makefile
src/scripts/Makefile
schemas/Makefile
stubs/Makefile
src/scripts/t/Makefile
src/scripts/t/testdata/Makefile
www/Makefile
Makefile
])

AC_OUTPUT
