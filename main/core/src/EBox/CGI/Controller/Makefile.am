## Process this file with automake to produce Makefile.in

SUBDIRS = Downloader

perldir = @PERLPATH@/EBox/CGI/Controller

nobase_perl_DATA = Composite.pm DataTable.pm DataTableAdd.pm \
		  DataTableUpdate.pm DataTableMove.pm \
		  DataTableDel.pm DataMultiTable.pm \
		  Uploader.pm

SOURCES = $(nobase_perl_DATA)

MAINTAINERCLEANFILES = Makefile.in

EXTRA_DIST = $(nobase_perl_DATA)

