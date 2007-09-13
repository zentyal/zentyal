## Process this file with automake to produce Makefile.in
SUBDIRS = t

perldir = @PERLPATH@/EBox/ControlCenter

nobase_perl_DATA = AbstractEBoxDB.pm ApacheSOAP.pm Common.pm EventReceiver.pm \
		FileEBoxDB.pm RemoteEBoxProxy.pm SOAPHandle.pm

SOURCES = $(nobase_perl_DATA)

MAINTAINERCLEANFILES = Makefile.in

DISTCLEANFILES = Common.pm

EXTRA_DIST = $(nobase_perl_DATA)
