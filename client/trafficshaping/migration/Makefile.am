## Process this file with automake to produce Makefile.in

Migrationsdir = @DATADIR@/ebox-trafficshaping/migration

nobase_Migrations_SCRIPTS = 0001_add_source_destination.pl \
	0002_upgrade_service.pl 0003_add_enabled.pl 0004_add_order.pl \
	0005_l7_services.pl

EXTRA_DIST = $(nobase_Migrations_SCRIPTS)

MAINTAINERCLEANFILES = Makefile.in

