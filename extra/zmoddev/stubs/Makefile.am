## Process this file with automake to produce Makefile.in
stubsdir = $(datadir)/zmoddev/stubs

stubs_DATA = autogen.sh configure.ac.mas Makefile.am.mas

stubsdebiandir = $(datadir)/zmoddev/stubs/debian

stubsdebian_DATA = debian/prerm debian/changelog.mas debian/cdbs/ebox.mk \
	debian/compat debian/postrm.mas debian/rules debian/postinst.mas \
	debian/control.mas

stubsdebiancdbsdir = $(datadir)/zmoddev/stubs/debian/cdbs

stubsdebiancdbs_DATA = debian/cdbs/ebox.mk

stubsm4dir = $(datadir)/zmoddev/stubs/m4

stubsm4_DATA = m4/definedir.m4  m4/ebox.m4  m4/gconf-2.m4
	m4/nls.m4  m4/perlmodules.m4

stubsschemasdir = $(datadir)/zmoddev/stubs/schemas

stubsschemas_DATA = schemas/Makefile.am.mas  schemas/yaml.mas

stubssrcdir = $(datadir)/zmoddev/stubs/src

stubssrc_DATA = src/Makefile.am.mas src/MainClass.pm.mas src/FirewallHelper.pm.mas

stubsmodeldir = $(datadir)/zmoddev/stubs/src/Model

stubsmodel_DATA =  src/Model/TableModel.pm.mas src/Model/FormModel.pm.mas

stubscompositedir = $(datadir)/zmoddev/stubs/src/Composite

stubscomposite_DATA =  src/Composite/Composite.pm.mas

stubstypedir = $(datadir)/zmoddev/stubs/src/Types

stubstype_DATA = src/Types/Type.pm.mas

stubsstubsdir = $(datadir)/zmoddev/stubs/stubs/

stubsstubs_DATA = stubs/Makefile.am.mas stubs/service.conf.mas

DISTCLEANFILES =

EXTRA_DIST = $(stubs_DATA) $(stubsdebian_DATA) $(stubsm4_DATA) \
	$(stubsschemas_DATA) $(stubssrc_DATA) \
	$(stubsmodel_DATA) $(stubsstubs_DATA) \
	$(stubstypes_DATA) $(stubstype_DATA) \
	$(stubscomposite_DATA)

MAINTAINERCLEANFILES = Makefile.in
