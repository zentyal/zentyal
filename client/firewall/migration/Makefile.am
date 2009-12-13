## Process this file with automake to produce Makefile.in

Migrationsdir = @DATADIR@/ebox-firewall/migration

nobase_Migrations_SCRIPTS = 0001_import_rules_to_new_model.pl \
        0002_set_default_internal_services.pl \
		0003_import_redirects_to_new_model.pl 0004_allow_output_by_default.pl

EXTRA_DIST = $(nobase_Migrations_SCRIPTS)

MAINTAINERCLEANFILES = Makefile.in

