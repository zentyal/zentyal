## Process this file with automake to produce Makefile.in

Stubdir = @STUBSPATH@/usersandgroups

nobase_Stub_DATA = slapd.conf.mas user-apache2.conf.mas soap-slave.mas \
    slapd-replica.ldif.mas \
	slapd-translucent.ldif.mas slapd-frontend.ldif.mas \
    slapd-master.ldif.mas slapd-master-db.ldif.mas \
    slapd-frontend-referrals.ldif.mas slapd-master-upgrade.ldif.mas \
    slapd-master-upgrade-ebox.ldif.mas ldap.conf.mas

EXTRA_DIST = $(nobase_Stub_DATA)

MAINTAINERCLEANFILES = Makefile.in slapd.conf.mas
