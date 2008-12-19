## Process this file with automake to produce Makefile.in
SUBDIRS= Dispatcher

perldir = @PERLPATH@/EBox/Mail/Model


nobase_perl_DATA= SMTPAuth.pm SMTPOptions.pm RetrievalServices.pm \
	ObjectPolicy.pm VDomains.pm ExternalFilter.pm \
	GreylistConfiguration.pm

EXTRA_DIST = $(nobase_perl_DATA)

MAINTAINERCLEANFILES = Makefile.in
