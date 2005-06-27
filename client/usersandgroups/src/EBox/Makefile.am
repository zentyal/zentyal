## Process this file with automake to produce Makefile.in
SUBDIRS = CGI

perldir = @PERLPATH@/EBox


nobase_perl_DATA = Ldap.pm UsersAndGroups.pm LdapUserBase.pm LdapModule.pm \
		   LdapUserImplementation.pm

MAINTAINERCLEANFILES = Makefile.in

EXTRA_DIST = $(nobase_perl_DATA)
