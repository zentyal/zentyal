AC_INIT([EBox], [0.12.1])

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
	  
#	AC_PROG_PERL_MODULES(Apache::AuthCookie, ,
#	  AC_MSG_ERROR(Missing Apache::AuthCookie))
#
#	AC_PROG_PERL_MODULES(Apache::Reload, ,
#	  AC_MSG_ERROR(Missing Apache::Reload))

	AC_PROG_PERL_MODULES(Test::Class, ,
	  AC_MSG_WARN(Missing test dependency Test::Class))

	AC_PROG_PERL_MODULES(Test::Deep, ,
	  AC_MSG_WARN(Missing test dependency Test::Deep))

	AC_PROG_PERL_MODULES(Test::MockTime, ,
	  AC_MSG_WARN(Missing test dependency Test::MockTime))

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
tools/sqllog/Makefile
tools/cron/Makefile
doc/Makefile
src/Makefile
src/libexec/Makefile
src/templates/ajax/Makefile
src/templates/ajax/viewer/Makefile
src/templates/common/Makefile
src/templates/login/Makefile
src/templates/logout/Makefile
src/templates/logs/Makefile
src/templates/report/Makefile
src/templates/Makefile
src/EBox/Makefile
src/EBox/t/Makefile
src/EBox/interactiveTest/Makefile
src/EBox/Backup/Makefile
src/EBox/Backup/testdata/Makefile
src/EBox/Common/Makefile
src/EBox/Common/Model/Makefile
src/EBox/Event/Makefile
src/EBox/Event/Dispatcher/Makefile
src/EBox/Event/Dispatcher/t/Makefile
src/EBox/Event/Watcher/Makefile
src/EBox/Event/Watcher/t/Makefile
src/EBox/Events/Makefile
src/EBox/Events/Model/Makefile
src/EBox/Events/Model/Dispatcher/Makefile
src/EBox/Events/Model/t/Makefile
src/EBox/Events/Model/Watcher/Makefile
src/EBox/ServiceModule/Makefile
src/EBox/Report/Makefile
src/EBox/Report/t/Makefile
src/EBox/Report/t/testdata/Makefile
src/EBox/GConfModule/Makefile
src/EBox/GConfModule/t/Makefile
src/EBox/Global/Makefile
src/EBox/Logs/Makefile
src/EBox/Logs/Model/Makefile
src/EBox/Logs/Composite/Makefile
src/EBox/Model/Makefile
src/EBox/Model/Row/Makefile
src/EBox/Model/t/Makefile
src/EBox/Model/CompositeProvider/Makefile
src/EBox/Model/ModelProvider/Makefile
src/EBox/Model/ProviderBase/Makefile
src/EBox/Model/DataForm/Makefile
src/EBox/Model/DataTable/Makefile
src/EBox/Model/Composite/Makefile
src/EBox/Model/DataForm/t/Makefile
src/EBox/Types/Makefile
src/EBox/Types/File/Makefile
src/EBox/Types/t/Makefile
src/EBox/Types/Union/Makefile
src/EBox/ProgressIndicator/Makefile
src/EBox/Global/t/Makefile
src/EBox/Test/Makefile
src/EBox/Test/t/Makefile
src/EBox/CGI/Makefile
src/EBox/CGI/EBox/Makefile
src/EBox/CGI/Controller/Makefile
src/EBox/CGI/Controller/Downloader/Makefile
src/EBox/CGI/ServiceModule/Makefile
src/EBox/CGI/View/Makefile
src/EBox/CGI/Login/Makefile
src/EBox/CGI/Logout/Makefile
src/EBox/CGI/Logs/Makefile
src/EBox/CGI/Summary/Makefile
src/EBox/CGI/Report/Makefile
src/EBox/Summary/Makefile
schemas/Makefile
conf/Makefile
conf/logrotate/ebox
conf/logrotate/Makefile
conf/.gconf.path
migration/Makefile
migration/events/Makefile
migration/logs/Makefile
www/Makefile
Makefile
])

AC_CONFIG_FILES([po/Makefile], [AM_POSTPROCESS_PO_MAKEFILE])
AC_OUTPUT
