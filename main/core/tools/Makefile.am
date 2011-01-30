## Process this file with automake to produce Makefile.in
SUBDIRS = sqllog cron

pkgdatadir = $(datadir)/zentyal

pkgdata_SCRIPTS = ebox-apache2ctl ebox-apache-restart \
 ebox-sudoers-friendly zentyal-clean-conf zentyal.init.d \
 ebox-create-certificate ebox-make-backup ebox-restore-backup \
 ebox-unblock-exec ebox-passwd ebox-sql-table ebox-sql-table-with-time-period \
 ebox-set-locale ebox-global-action ebox-unconfigure-module \
 ebox-update-file-digest ebox-change-hostname redisvi regen-redis-db \
 ebox-consolidate-reportinfo ebox-gather-reportinfo initial-setup \
 ebox-purge-logs ebox-configuration-report ebox-create-db fastperl-server

MAINTAINERCLEANFILES = Makefile.in

EXTRA_DIST = $(pkgdata_SCRIPTS)
