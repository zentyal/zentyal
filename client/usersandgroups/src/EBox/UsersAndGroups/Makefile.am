## Process this file with automake to produce Makefile.in
SUBDIRS = Composite Model Types

perldir = @PERLPATH@/EBox/UsersAndGroups

nobase_perl_DATA =  Passwords.pm UserUpdater.pm \
    WSDispatcher.pm Setup.pm

DISTCLEANFILES =

EXTRA_DIST = ${nobase_perl_DATA}

MAINTAINERCLEANFILES = Makefile.in
