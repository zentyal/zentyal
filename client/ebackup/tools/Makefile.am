## Process this file with automake to produce Makefile.in
SUBDIRS=sqllog

pkgdata_SCRIPTS =  ebox-remote-ebackup ebox-duplicity-wrapper restore-logs restore-tool backup-cleanup

pkgdata_DATA = server-fingerprints

MAINTAINERCLEANFILES = Makefile.in

EXTRA_DIST = $(pkgdata_SCRIPTS) $(pkgdata_DATA)
