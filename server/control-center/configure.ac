AC_INIT([ebox-control-center], [0.11])
		   
AC_CONFIG_AUX_DIR([config])
AC_CONFIG_SRCDIR([src/EBox/ControlCenter/Common.pm.in])

AM_INIT_AUTOMAKE([foreign])

AM_MAINTAINER_MODE

AC_DEFINE_DIR(DATADIR, datadir)
AC_DEFINE_DIR(SYSCONFDIR, sysconfdir)
AC_DEFINE_DIR(LOCALSTATEDIR, localstatedir)
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

	AC_PROG_PERL_MODULES(Encode, ,
	  AC_MSG_ERROR(Missing Encode))

        AC_CONF_EBOX_CC

fi  

if test -z "$perlpath" ; then
	perlpath="$DATADIR/perl5/"
	AC_MSG_NOTICE([Perl libraries will be installed in $perlpath, make sure to
	include it in your path])
else
	AC_MSG_NOTICE([Perl libraries will be installed in $perlpath])
fi
AC_SUBST(perlpath)

AC_DEFINE_DIR(PERLPATH, perlpath)

AM_PO_SUBDIRS

AC_CONFIG_FILES([
src/Makefile
src/EBox/Makefile
src/EBox/ControlCenter/Makefile
src/EBox/ControlCenter/Common.pm
src/EBox/ControlCenter/t/Makefile
stubs/Makefile
stubs/apache.mas
stubs/apache-soap
conf/Makefile
scripts/Makefile
Makefile
])

AC_CONFIG_FILES([po/Makefile], [AM_POSTPROCESS_PO_MAKEFILE])
AC_OUTPUT
