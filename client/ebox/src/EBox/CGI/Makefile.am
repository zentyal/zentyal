## Process this file with automake to produce Makefile.in

perldir = @PERLPATH@/EBox/CGI

nobase_perl_DATA = ClientBase.pm ClientRawBase.pm Finish.pm Progress.pm ProgressClient.pm Temp.pm

SUBDIRS = Dashboard EBox Login Logout Logs Summary Controller View Report RemoteServices ServiceModule

SOURCES = $(nobase_perl_DATA)

MAINTAINERCLEANFILES = Makefile.in

EXTRA_DIST = $(nobase_perl_DATA)
