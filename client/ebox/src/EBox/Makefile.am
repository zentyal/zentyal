## Process this file with automake to produce Makefile.in

perldir = @PERLPATH@/EBox

mods = AbstractDBEngine.pm Apache.pm Auth.pm Backup.pm DBEngineFactory.pm \
       FirstTime.pm GConfConfig.pm GConfHelper.pm GConfModule.pm GConfState.pm \
       Global.pm Html.pm LogAdmin.pm LogHelper.pm LogObserver.pm Loggerd.pm \
       Logs.pm Module.pm Order.pm PgDBEngine.pm Service.pm SysInfo.pm Test.pm \
       TestStubs.pm MigrationBase.pm

nobase_perl_DATA = $(mods)

SUBDIRS = CGI Summary GConfModule Global Test t Backup interactiveTest Model \
	  Types

SOURCES = $(nobase_perl_DATA)

EXTRA_DIST = $(mods)

MAINTAINERCLEANFILES = Makefile.in
