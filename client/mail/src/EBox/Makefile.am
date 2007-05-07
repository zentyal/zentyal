## Process this file with automake to produce Makefile.in
SUBDIRS = CGI Mail t

perldir = @PERLPATH@/EBox

nobase_perl_DATA = Mail.pm MailVDomainsLdap.pm MailUserLdap.pm\
	MailAliasLdap.pm MailFirewall.pm LdapVDomainBase.pm \
	VDomainModule.pm MailLogHelper.pm MailQueue.pm

DISTCLEANFILES = 

MAINTAINERCLEANFILES = Makefile.in

EXTRA_DIST = $(nobase_perl_DATA)
