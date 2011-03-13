## Process this file with automake to produce Makefile.in

Migrationsdir = @DATADIR@/ebox-dns/migration

nobase_Migrations_SCRIPTS = 0001_add_dns_service.pl 0002_add_bind_group_etc.pl \
                            0003_fix_dns_service.pl 0004_remove_ro_dyn_dom.pl

EXTRA_DIST = $(nobase_Migrations_SCRIPTS)

MAINTAINERCLEANFILES = Makefile.in

