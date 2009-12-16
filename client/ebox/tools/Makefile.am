## Process this file with automake to produce Makefile.in
SUBDIRS = sqllog cron

pkgdata_SCRIPTS = ebox-apache2ctl ebox-apache-restart ebox-migrate \
 ebox-sudoers ebox ebox-runit ebox-sudoers-friendly ebox-clean-gconf \
 ebox-create-certificate ebox-make-backup ebox-restore-backup \
 ebox-unblock-exec ebox-passwd ebox-sql-table ebox-sql-table-with-time-period \
 ebox-set-locale ebox-global-action ebox-unconfigure-module \
 ebox-dbus-launch ebox-update-file-digest ebox-dbus-check \
 ebox-consolidate-reportinfo ebox-gather-reportinfo

MAINTAINERCLEANFILES = Makefile.in

EXTRA_DIST = $(pkgdata_SCRIPTS)
