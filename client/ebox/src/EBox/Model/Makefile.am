## Process this file with automake to produce Makefile.in
SUBDIRS = t

perldir = @PERLPATH@/EBox/Model

mods = Composite.pm CompositeManager.pm CompositeProvider.pm \
	DataForm.pm DataTable.pm DataMultiTable.pm \
	ModelManager.pm ModelProvider.pm

nobase_perl_DATA = $(mods)

SOURCES = $(nobase_perl_DATA)

EXTRA_DIST = $(mods)

MAINTAINERCLEANFILES = Makefile.in
