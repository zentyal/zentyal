## Process this file with automake to produce Makefile.in

perldir = @PERLPATH@/EBox/RemoteServices/Server

mods = Base.pm JobReceiver.pm

nobase_perl_DATA = $(mods)

SOURCES = $(nobase_perl_DATA)

EXTRA_DIST = $(mods)

SUBDIRS = t

MAINTAINERCLEANFILES = Makefile.in
