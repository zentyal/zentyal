## Process this file with automake to produce Makefile.in

moduledir   = @DATADIR@/zentyal/modules
module_DATA = users.yaml

pkgdata_DATA = passwords.ldif master.ldif slaves.ldif quota.ldif

EXTRA_DIST = $(module_DATA) $(pkgdata_DATA)

MAINTAINERCLEANFILES = Makefile.in
