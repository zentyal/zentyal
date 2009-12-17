## Process this file with automake to produce Makefile.in

perldir = @PERLPATH@/EBox

mods = AbstractDBEngine.pm Apache.pm Auth.pm Backup.pm DBEngineFactory.pm \
	Events.pm EventDaemon.pm GConfConfig.pm GConfHelper.pm \
	GConfModule.pm GConfState.pm Global.pm Html.pm \
	Logs.pm  LogAdmin.pm LogHelper.pm LogObserver.pm Loggerd.pm \
	Menu.pm Order.pm ProgressIndicator.pm ServiceManager.pm \
	PgDBEngine.pm Service.pm SysInfo.pm Test.pm \
	TestStubs.pm MigrationBase.pm MigrationHelpers.pm HtmlBlocks.pm


nobase_perl_DATA = $(mods)

authcookiedir =  @PERLPATH@/EBox
nobase_authcookie_DATA = ThirdParty/Apache2/AuthCookie.pm

authutildir =  @PERLPATH@/EBox
nobase_authutil_DATA = ThirdParty/Apache2/AuthCookie/Util.pm

SUBDIRS = Backup CGI Common Dashboard GConfModule interactiveTest Event Events Global Logs \
	Migration Model ProgressIndicator Report t Test Types Module Util View

SOURCES = $(nobase_perl_DATA)

EXTRA_DIST = $(mods) ThirdParty

MAINTAINERCLEANFILES = Makefile.in
