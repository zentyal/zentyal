## Process this file with automake to produce Makefile.in

perldir = @PERLPATH@/EBox/RemoteServices


mods = Alerts.pm Auth.pm Base.pm Backup.pm Bundle.pm Configuration.pm CSV.pm Jobs.pm \
       ProxyBackup.pm SOAPClient.pm Subscription.pm SupportAccess.pm \
       WSDispatcher.pm


nobase_perl_DATA = $(mods)

SOURCES = $(nobase_perl_DATA)

EXTRA_DIST = $(mods)

SUBDIRS = Audit Composite Model Server t Types

MAINTAINERCLEANFILES = Makefile.in
