AC_INIT([libeBox], [0.7.1-rc1])

AC_CONFIG_AUX_DIR([config])
AC_CONFIG_SRCDIR([src/EBox.pm])

AM_INIT_AUTOMAKE([foreign 1.8])

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

	AC_PROG_PERL_MODULES(Log::Dispatch, ,
	  AC_MSG_ERROR(Missing Log::Dispatch))

	AC_PROG_PERL_MODULES(Log::Log4perl, ,
	  AC_MSG_ERROR(Missing Log::Log4perl))

	AC_PROG_PERL_MODULES(HTML::Mason, ,
	  AC_MSG_ERROR(Missing HTML::Mason))

	AC_PROG_PERL_MODULES(Locale::gettext, ,
	  AC_MSG_ERROR(Missing Locale::gettext))

	AC_PROG_PERL_MODULES(Net::IP, ,
	  AC_MSG_ERROR(Missing Net::IP))

	AC_PROG_PERL_MODULES(Error, ,
	  AC_MSG_ERROR(Missing Error))
	  
	AC_PROG_PERL_MODULES(Devel::StackTrace, ,
	  AC_MSG_ERROR(Missing Devel::StackTrace))
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
doc/Makefile
src/cgi/Makefile
src/Makefile
src/templates/Makefile
src/EBox/Makefile
src/EBox/t/Makefile
src/EBox/Exceptions/Makefile
src/EBox/CGI/Makefile
src/EBox/CGI/EBox/Makefile
src/EBox/Menu/Makefile
src/EBox/Test/Makefile
src/EBox/Config.pm
src/EBox/Config/Makefile
src/EBox/Config/t/Makefile
src/EBox/Sudo/Makefile
src/EBox/Sudo/t/Makefile
conf/Makefile
conf/eboxlog.conf
www/Makefile
Makefile
])

AC_CONFIG_FILES([po/Makefile], [AM_POSTPROCESS_PO_MAKEFILE])
AC_OUTPUT
