## Process this file with automake to produce Makefile.in

perldir = @PERLPATH@/EBox

mods = AbstractDBEngine.pm Apache.pm Auth.pm Backup.pm DBEngineFactory.pm \
	RemoteServices.pm Events.pm EventDaemon.pm GConfConfig.pm \
	GConfHelper.pm GConfModule.pm GConfState.pm Global.pm Html.pm \
        Logs.pm  LogAdmin.pm LogHelper.pm LogObserver.pm Loggerd.pm \
        Menu.pm Module.pm  \
	Order.pm ProgressIndicator.pm \
	PgDBEngine.pm Service.pm SysInfo.pm Test.pm \
	TestStubs.pm MigrationBase.pm 


nobase_perl_DATA = $(mods)


SUBDIRS = Backup CGI Common Dashboard GConfModule interactiveTest Event Events Global Logs \
	Model   ProgressIndicator RemoteServices Report t Test Types ServiceModule

SOURCES = $(nobase_perl_DATA)

EXTRA_DIST = $(mods)

MAINTAINERCLEANFILES = Makefile.in
