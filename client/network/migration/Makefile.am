## Process this file with automake to produce Makefile.in

Migrationsdir = @DATADIR@/ebox-network/migration

nobase_Migrations_SCRIPTS = 0001_import_default_gateway.pl \
			    0002_add_weight_to_gateway.pl \
			    0003_import_routes_to_mvc.pl \
			    0004_import_dns_to_mvc.pl

EXTRA_DIST = $(nobase_Migrations_SCRIPTS)

MAINTAINERCLEANFILES = Makefile.in

