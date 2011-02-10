## Process this file with automake to produce Makefile.in
SUBDIRS = cron

pkgdatadir = @DATADIR@/zentyal

pkgdata_SCRIPTS = loggerd kill-pid apache2ctl apache-restart \
 sudoers-friendly clean-conf zentyal.init.d \
 create-certificate make-backup restore-backup \
 unblock-exec sql-table sql-table-with-time-period \
 set-locale global-action unconfigure-module \
 update-file-digest change-hostname redisvi regen-redis-db \
 consolidate-reportinfo gather-reportinfo initial-setup \
 purge-logs configuration-report create-db drop-tables

MAINTAINERCLEANFILES = Makefile.in

EXTRA_DIST = $(pkgdata_SCRIPTS)
