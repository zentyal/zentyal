## Process this file with automake to produce Makefile.in
SUBDIRS=t

pkgdata_SCRIPTS = check-ldap-password slapd.backup import-from-ldif list-slaves delete-slave slave-sync ebox-usercorner-apache2-start ebox-ad-sync ebox-pwdsync-server ebox-usersandgroups-reinstall ebox-ldapvi resync-replica
pkgdata_DATA =  slapd.default slapd.default.no ebox-ad-sync.cron

MAINTAINERCLEANFILES = Makefile.in

EXTRA_DIST = $(pkgdata_SCRIPTS) $(pkgdata_DATA)
