## Process this file with automake to produce Makefile.in

Migrationsdir = @DATADIR@/ebox-mail/migration


nobase_Migrations_SCRIPTS = 0001_add_firewall_services.pl 0002_to_new_framework.pl \
        0003_to_dovecot.pl 0004_key_in_pem.pl \
        0005_add_managesieve_firewall_services.pl \
        0006_update_db.pl \
        0007_add_fetchmail_ldap.pl \
        0008_update_sql_log_table.pl  0009_add_defaults.pl \
	0010_fix_smtp_options_sizes.pl \
	0011_fix_sieve_dir.pl 0012_fix_message_type.pl 0013_fix_event_report.pl


EXTRA_DIST = $(nobase_Migrations_SCRIPTS)

MAINTAINERCLEANFILES = Makefile.in

