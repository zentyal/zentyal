## Process this file with automake to produce Makefile.in

perldir = @PERLPATH@/EBox/RemoteServices/Model

mods = AccessSettings.pm AdvancedSecurityUpdates.pm AlertsInfo.pm \
       DisasterRecovery.pm QAUpdatesInfo.pm RemoteSupportAccess.pm \
       ReportsInfo.pm Subscription.pm SubscriptionInfo.pm TechnicalInfo.pm

nobase_perl_DATA = $(mods)

SOURCES = $(nobase_perl_DATA)

EXTRA_DIST = $(mods)

MAINTAINERCLEANFILES = Makefile.in
