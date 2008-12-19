## Process this file with automake to produce Makefile.in
SUBDIRS = Report

perldir = @PERLPATH@/EBox/MailFilter/Model

nobase_perl_DATA =   AmavisConfiguration.pm AmavisPolicy.pm ExternalMTA.pm ExternalDomain.pm \
                     FileExtensionACL.pm MIMETypeACL.pm \
                     FreshclamStatus.pm \
                    AntispamConfiguration.pm AntispamACL.pm AntispamTraining.pm \
                    VDomains.pm \
                    POPProxyConfiguration.pm

EXTRA_DIST = $(nobase_perl_DATA)

MAINTAINERCLEANFILES = Makefile.in
