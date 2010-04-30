## Process this file with automake to produce Makefile.in

perldir = @PERLPATH@/EBox/RemoteServices

mods = Alerts.pm Auth.pm Base.pm Backup.pm Configuration.pm Jobs.pm Monitor.pm \
	ProxyBackup.pm SOAPClient.pm Subscription.pm WSDispatcher.pm CSV.pm \
       SupportAccess.pm


nobase_perl_DATA = $(mods)

SOURCES = $(nobase_perl_DATA)

EXTRA_DIST = $(mods)

SUBDIRS = Composite Model Server t Types

MAINTAINERCLEANFILES = Makefile.in
