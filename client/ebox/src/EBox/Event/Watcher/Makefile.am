## Process this file with automake to produce Makefile.in

SUBDIRS= t

perldir = @PERLPATH@/EBox/Event/Watcher

nobase_perl_DATA = Base.pm DiskFreeSpace.pm Log.pm RAID.pm \
	Runit.pm State.pm

SOURCES = $(nobase_perl_DATA)

MAINTAINERCLEANFILES = Makefile.in

EXTRA_DIST = $(nobase_perl_DATA)
