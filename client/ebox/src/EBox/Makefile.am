## Process this file with automake to produce Makefile.in

perldir = @PERLPATH@/EBox

mods = Module.pm Html.pm Global.pm SysInfo.pm GConfModule.pm \
	Auth.pm Order.pm GConfHelper.pm GConfState.pm GConfConfig.pm \
	Apache.pm Backup.pm AbstractDaemon.pm KeepAlive.pm KeepAlived.pm

nobase_perl_DATA = $(mods)

SUBDIRS = CGI Summary

SOURCES = $(nobase_perl_DATA)

EXTRA_DIST = $(mods)

MAINTAINERCLEANFILES = Makefile.in
