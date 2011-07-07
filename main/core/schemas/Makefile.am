## Process this file with automake to produce Makefile.in

SUBDIRS = sql urls

moduledir   = @DATADIR@/zentyal/modules
module_DATA = apache.yaml audit.yaml events.yaml global.yaml logs.yaml sysinfo.yaml

EXTRA_DIST = $(module_DATA)

MAINTAINERCLEANFILES = Makefile.in
