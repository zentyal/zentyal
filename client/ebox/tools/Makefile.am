## Process this file with automake to produce Makefile.in
SUBDIRS = sqllog cron

bin_SCRIPTS =  ebox-sudoers ebox ebox-runit ebox-sudoers-friendly \
	       ebox-clean-gconf ebox-create-certificate ebox-runit-finisher


pkglib_SCRIPTS =  ebox-apache-restart ebox-sql-table ebox-migrate \
	ebox-restore-backup ebox-make-backup


MAINTAINERCLEANFILES = Makefile.in

EXTRA_DIST = $(bin_SCRIPTS) $(pkglib_SCRIPTS) runit/apache-perl \
	     runit/apache-perl.finish runit/event-daemon
