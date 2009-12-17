## Process this file with automake to produce Makefile.in

Migrationsdir = @DATADIR@/ebox-mail/migration

nobase_Migrations_SCRIPTS = 0001_add_firewall_services.pl 0002_to_new_framework.pl \
        0003_to_dovecot.pl 0004_key_in_pem.pl \
        0005_add_managesieve_firewall_services.pl \
        0006_update_db_fields.pl 0007_rename_tables.pl

EXTRA_DIST = $(nobase_Migrations_SCRIPTS)

MAINTAINERCLEANFILES = Makefile.in

