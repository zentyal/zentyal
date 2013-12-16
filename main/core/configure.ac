AC_INIT([zentyal-core], [2.2.11])

AC_CONFIG_AUX_DIR([config])
AC_CONFIG_SRCDIR([src/EBox/SysInfo.pm.in])

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

        AC_CONF_EBOX

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
stubs/apache.mas
stubs/Makefile
stubs/css/Makefile
doc/Makefile
src/Makefile
src/scripts/Makefile
src/scripts/cron/Makefile
src/templates/ajax/Makefile
src/templates/ajax/setter/Makefile
src/templates/ajax/viewer/Makefile
src/templates/common/Makefile
src/templates/dashboard/Makefile
src/templates/login/Makefile
src/templates/input/Makefile
src/templates/input/t/Makefile
src/templates/logout/Makefile
src/templates/logs/Makefile
src/templates/js/Makefile
src/templates/report/Makefile
src/templates/t/Makefile
src/templates/Makefile
src/cgi/Makefile
src/EBox/SysInfo.pm
src/EBox/Makefile
src/EBox/t/Makefile
src/EBox/interactiveTest/Makefile
src/EBox/Backup/Makefile
src/EBox/Backup/testdata/Makefile
src/EBox/Common/Makefile
src/EBox/Common/Model/Makefile
src/EBox/Menu/Makefile
src/EBox/Config/Makefile
src/EBox/Dashboard/Makefile
src/EBox/Event/Makefile
src/EBox/Event/Dispatcher/Makefile
src/EBox/Event/Dispatcher/t/Makefile
src/EBox/Event/Watcher/Makefile
src/EBox/Event/Watcher/t/Makefile
src/EBox/Events/Makefile
src/EBox/Events/Model/Makefile
src/EBox/Events/Model/Report/Makefile
src/EBox/Events/Model/Dispatcher/Makefile
src/EBox/Events/Model/t/Makefile
src/EBox/Events/Model/Watcher/Makefile
src/EBox/Events/Composite/Makefile
src/EBox/Events/Composite/Report/Makefile
src/EBox/Module/Makefile
src/EBox/Report/Makefile
src/EBox/Report/t/Makefile
src/EBox/Report/t/testdata/Makefile
src/EBox/GConfModule/Makefile
src/EBox/GConfModule/t/Makefile
src/EBox/Global/Makefile
src/EBox/Logs/Makefile
src/EBox/Logs/Model/Makefile
src/EBox/Logs/Model/Report/Makefile
src/EBox/Logs/Composite/Makefile
src/EBox/Logs/Consolidate/Makefile
src/EBox/Migration/Makefile
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
src/EBox/Types/Text/Makefile
src/EBox/Types/t/Makefile
src/EBox/Types/Union/Makefile
src/EBox/ProgressIndicator/Makefile
src/EBox/Global/t/Makefile
src/EBox/Test/Makefile
src/EBox/Test/t/Makefile
src/EBox/CGI/Makefile
src/EBox/CGI/Dashboard/Makefile
src/EBox/CGI/SysInfo/Makefile
src/EBox/CGI/Controller/Makefile
src/EBox/CGI/Controller/Downloader/Makefile
src/EBox/CGI/ServiceModule/Makefile
src/EBox/CGI/View/Makefile
src/EBox/CGI/Login/Makefile
src/EBox/CGI/Logout/Makefile
src/EBox/CGI/Logs/Makefile
src/EBox/CGI/Report/Makefile
src/EBox/CGI/t/Makefile
src/EBox/Util/Makefile
src/EBox/View/Makefile
src/EBox/SysInfo/Makefile
src/EBox/SysInfo/Model/Makefile
schemas/Makefile
schemas/sql/Makefile
schemas/sql/period/Makefile
schemas/urls/Makefile
conf/Makefile
conf/hooks/Makefile
conf/pre-save/Makefile
conf/post-save/Makefile
migration/Makefile
migration/logs/Makefile
migration/events/Makefile
www/Makefile
Makefile
])

AC_OUTPUT
