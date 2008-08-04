## Process this file with automake to produce Makefile.in
SUBDIRS= Servers ServerConfiguration t

perldir = @PERLPATH@/EBox/OpenVPN/Model

nobase_perl_DATA = InterfaceTable.pm \
                   Servers.pm ServerConfiguration.pm AdvertisedNetworks.pm \
	           DownloadClientBundle.pm  \
                   Clients.pm ClientConfiguration.pm \
                   DeletedDaemons.pm

DISTCLEANFILES = 

EXTRA_DIST = $(nobase_perl_DATA)

MAINTAINERCLEANFILES = Makefile.in
