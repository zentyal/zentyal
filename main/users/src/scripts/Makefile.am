## Process this file with automake to produce Makefile.in
SUBDIRS=t

pkgdata_SCRIPTS = check-ldap-password slapd.backup list-slaves delete-slave slave-sync ad-sync pwdsync-server reinstall ldapvi resync-replica enable-module rejoin-slave initial-setup enable-quotas user-quota
pkgdata_DATA = slapd.default slapd.default.no ad-sync.cron

MAINTAINERCLEANFILES = Makefile.in

EXTRA_DIST = $(pkgdata_SCRIPTS) $(pkgdata_DATA)
