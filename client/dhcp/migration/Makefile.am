## Process this file with automake to produce Makefile.in

Migrationsdir = @DATADIR@/ebox-dhcp/migration

nobase_Migrations_SCRIPTS = 0001_import_to_mvc.pl 0002_add_services.pl \
			    0003_fixed_addr_obj.pl 0004_dyn_domains.pl \
			    0005_upgrade_apparmor_profile.pl \
			    0006_remove_zentyal_apparmor_profile.pl

EXTRA_DIST = $(nobase_Migrations_SCRIPTS)

MAINTAINERCLEANFILES = Makefile.in

