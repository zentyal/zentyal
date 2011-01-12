## Process this file with automake to produce Makefile.in
SUBDIRS= Dispatcher Report

perldir = @PERLPATH@/EBox/Mail/Model


nobase_perl_DATA= SMTPAuth.pm SMTPOptions.pm RetrievalServices.pm \
	ObjectPolicy.pm \
	VDomains.pm VDomainAliases.pm ExternalAliases.pm VDomainSettings.pm \
        ExternalFilter.pm \
	GreylistConfiguration.pm ExternalAccounts.pm MailUser.pm

EXTRA_DIST = $(nobase_perl_DATA)

MAINTAINERCLEANFILES = Makefile.in
