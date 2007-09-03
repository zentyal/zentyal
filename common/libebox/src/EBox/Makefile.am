## Process this file with automake to produce Makefile.in

perldir = @PERLPATH@/EBox

mods = AbstractDaemon.pm Validate.pm Gettext.pm Sudo.pm NetWrappers.pm  TestStub.pm FileSystem.pm \
	Event.pm

nobase_perl_DATA = $(mods) Config.pm

SUBDIRS = CGI Exceptions Menu Test t Sudo Config NetWrappers interactiveTests

SOURCES = $(nobase_perl_DATA)

EXTRA_DIST = $(mods)

DISTCLEANFILES = Config.pm

MAINTAINERCLEANFILES = Makefile.in
