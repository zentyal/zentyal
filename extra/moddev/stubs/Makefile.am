## Process this file with automake to produce Makefile.in
stubsdir = $(datadir)/emoddev/stubs

stubs_DATA = autogen.sh configure.ac.mas Makefile.am.mas

stubsdebiandir = $(datadir)/emoddev/stubs/debian

stubsdebian_DATA = debian/prerm debian/changelog.mas debian/cdbs/ebox.mk \
	debian/compat debian/postrm.mas debian/rules debian/postinst.mas \
	debian/control.mas 

stubsdebiancdbsdir = $(datadir)/emoddev/stubs/debian/cdbs

stubsdebiancdbs_DATA = debian/cdbs/ebox.mk 


stubsm4dir = $(datadir)/emoddev/stubs/m4

stubsm4_DATA = m4/definedir.m4  m4/ebox.m4  m4/gconf-2.m4 
	m4/nls.m4  m4/perlmodules.m4  m4/po.m4

stubsmigrationdir = $(datadir)/emoddev/stubs/migration

stubsmigration_DATA = migration/Makefile.am.mas 

stubsschemasdir = $(datadir)/emoddev/stubs/schemas

stubsschemas_DATA = schemas/Makefile.am.mas  schemas/gconf.schemas.mas

stubssrcdir = $(datadir)/emoddev/stubs/src

stubssrc_DATA = src/Makefile.am.mas  src/MainClass.pm.mas src/Makefile.am

stubsmodeldir = $(datadir)/emoddev/stubs/src/Model

stubsmodel_DATA = src/Model//Makefile.am.mas src/Model/TableModel.pm.mas  \
	src/Model/FormModel.pm.mas

stubstypesdir = $(datadir)/emoddev/stubs/src/Types

stubstypes_DATA = src/Types/Makefile.am.mas

stubstypedir = $(datadir)/emoddev/stubs/src/Types

stubstype_DATA = src/Types/Type.pm.mas



stubstoolsdir = $(datadir)/emoddev/stubs/tools

stubstools_DATA = tools/extract-perl-from-mason  tools/po-am.footer  \
	tools/po-am.generator  tools/po-am.header

stubsstubsdir = $(datadir)/emoddev/stubs/stubs/

stubsstubs_DATA = stubs/Makefile.am.mas stubs/service.conf.mas


DISTCLEANFILES = 

EXTRA_DIST = $(stubs_DATA) $(stubsdebian_DATA) $(stubsm4_DATA) \
	$(stubsmigration_DATA) $(stubsschemas_DATA) $(stubssrc_DATA) \
	$(stubsmodel_DATA) $(stubstools_DATA) $(stubsstubs_DATA) \
	$(stubstypes_DATA) $(stubstype_DATA)


MAINTAINERCLEANFILES = Makefile.in
