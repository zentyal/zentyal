AC_INIT([EBox], [0.7.1])

AC_CONFIG_AUX_DIR([config])
AC_CONFIG_SRCDIR([src/EBox/Module.pm])

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

	AC_CHECK_PROG(GCONFTOOL, gconftool-2, gconftool-2, none)
	if test x"$GCONFTOOL" = "xnone" ; then
		AC_MSG_ERROR(gconftool-2 not found)
	fi

        perlpath=`$PERL -e 'foreach (@INC) { print "$_\n";}' | grep "^$DATADIR" | head -1`
        if test -z "$perlpath" ; then
        perlpath=`$PERL -e 'foreach (@INC) { print "$_\n";}' | grep "^$prefix" | head -1`
        fi


	AM_GCONF_SOURCE_2

        AC_CONF_EBOX
	
	AC_PROG_PERL_MODULES(Gnome2::GConf, ,
	  AC_MSG_ERROR(Missing Gnome2::GConf))

	AC_PROG_PERL_MODULES(Sys::Hostname, ,
	  AC_MSG_ERROR(Missing Sys::Hostname))

	AC_PROG_PERL_MODULES(Sys::CpuLoad, ,
	  AC_MSG_ERROR(Missing Sys::CpuLoad))

	AC_PROG_PERL_MODULES(Proc::ProcessTable, ,
	  AC_MSG_ERROR(Missing Proc::ProcessTable))

	AC_PROG_PERL_MODULES(Error, ,
	  AC_MSG_ERROR(Missing Error))
	  
	AC_PROG_PERL_MODULES(Apache::Singleton, ,
	  AC_MSG_ERROR(Missing Apache::Singleton))
	  
	AC_PROG_PERL_MODULES(Apache::AuthCookie, ,
	  AC_MSG_ERROR(Missing Apache::AuthCookie))
else
	GCONF_SCHEMAS_INSTALL_FALSE=
	GCONF_SCHEMAS_INSTALL_TRUE='#'
fi  

if test -z "$perlpath" ; then
perlpath="$DATADIR/perl5/"
AC_MSG_NOTICE([Perl libraries will be installed in $perlpath, make sure to
include it in your path])
else
AC_MSG_NOTICE([Perl libraries will be installed in $perlpath])
fi

AC_DEFINE_DIR(PERLPATH, perlpath)

AM_PO_SUBDIRS

AC_CONFIG_FILES([
stubs/apache.mas
stubs/Makefile
tools/Makefile
doc/Makefile
src/Makefile
src/templates/login/Makefile
src/templates/logout/Makefile
src/templates/Makefile
src/EBox/Makefile
src/EBox/t/Makefile
src/EBox/GConfModule/Makefile
src/EBox/GConfModule/t/Makefile
src/EBox/Global/Makefile
src/EBox/Global/t/Makefile
src/EBox/Test/Makefile
src/EBox/Test/t/Makefile
src/EBox/CGI/Makefile
src/EBox/CGI/EBox/Makefile
src/EBox/CGI/Login/Makefile
src/EBox/CGI/Logout/Makefile
src/EBox/CGI/Summary/Makefile
src/EBox/Summary/Makefile
schemas/Makefile
conf/Makefile
conf/.gconf.path
Makefile
])

AC_CONFIG_FILES([po/Makefile], [AM_POSTPROCESS_PO_MAKEFILE])
AC_OUTPUT
