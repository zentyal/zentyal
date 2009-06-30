## Process this file with automake to produce Makefile.in
SUBDIRS=t

pkgdata_SCRIPTS = check-ldap-password create-ebox-user ebox-init-ldap slapd.backup import-from-ldif list-slaves delete-slave slave-sync ebox-usercorner-apache2-start
pkgdata_DATA =  slapd.default slapd.default.no

MAINTAINERCLEANFILES = Makefile.in

EXTRA_DIST = $(pkgdata_SCRIPTS) $(pkgdata_DATA)
