## Process this file with automake to produce Makefile.in
SUBDIRS=t

perldir = @PERLPATH@/EBox/MailFilter/Types

nobase_perl_DATA = Policy.pm\
                   MIMEType.pm FileExtension.pm \
	           AntispamThreshold.pm AmavisSender.pm

DISTCLEANFILES = 

EXTRA_DIST = $(nobase_perl_DATA)

MAINTAINERCLEANFILES = Makefile.in
