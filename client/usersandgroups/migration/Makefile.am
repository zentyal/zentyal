## Process this file with automake to produce Makefile.in

Migrationsdir = @DATADIR@/ebox-usersandgroups/migration

nobase_Migrations_SCRIPTS = 0001_add_ldap_service.pl \
    0003_convert_passwords_to_sha.pl \
    0004_convert_cn_to_fullname.pl \
    0005_migrate_new_ldap.pl \
    0001_usercorner_add_webserver_service.pl

EXTRA_DIST = $(nobase_Migrations_SCRIPTS)

MAINTAINERCLEANFILES = Makefile.in

