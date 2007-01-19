## Process this file with automake to produce Makefile.in

perldir = @PERLPATH@/EBox/CGI

nobase_perl_DATA = ClientBase.pm ClientRawBase.pm Finish.pm DataTableView.pm \
		  DataTableController.pm DataTableControllerAdd.pm \
		  DataTableControllerUpdate.pm DataTableControllerMove.pm \
		  DataTableControllerDel.pm

SUBDIRS = EBox Login Logout Logs Summary FirstTime

SOURCES = $(nobase_perl_DATA)

MAINTAINERCLEANFILES = Makefile.in

EXTRA_DIST = $(nobase_perl_DATA)
