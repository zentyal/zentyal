## Process this file with automake to produce Makefile.in
SUBDIRS = Composite Model ImportFromLdif Types

perldir = @PERLPATH@/EBox/UsersAndGroups

nobase_perl_DATA = ImportFromLdif.pm Passwords.pm UserUpdater.pm \
    WSDispatcher.pm Setup.pm

DISTCLEANFILES = 

EXTRA_DIST = ${nobase_perl_DATA}

MAINTAINERCLEANFILES = Makefile.in
