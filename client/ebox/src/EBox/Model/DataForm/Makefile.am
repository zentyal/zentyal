## Process this file with automake to produce Makefile.in
SUBDIRS = t

perldir = @PERLPATH@/EBox/Model/DataForm

mods = Action.pm ReadOnly.pm Download.pm

nobase_perl_DATA = $(mods)

test_classes = Test.pm

SOURCES = $(nobase_perl_DATA) $(test_classes)

EXTRA_DIST = $(mods)

MAINTAINERCLEANFILES = Makefile.in
