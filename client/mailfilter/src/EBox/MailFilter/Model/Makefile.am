## Process this file with automake to produce Makefile.in
perldir = @PERLPATH@/EBox/MailFilter/Model

nobase_perl_DATA =  General.pm ExternalMTA.pm ExternalDomain.pm \
                    BannedFilesPolicy.pm FileExtensionACL.pm MIMETypeACL.pm \
                    BadHeadersPolicy.pm \
	            AntivirusConfiguration.pm FreshclamStatus.pm \
                    AntispamConfiguration.pm AntispamACL.pm AntispamTraining.pm \
                    VDomains.pm

EXTRA_DIST = $(nobase_perl_DATA)

MAINTAINERCLEANFILES = Makefile.in
