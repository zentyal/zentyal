## Process this file with automake to produce Makefile.in

SUBDIRS = conf doc po src tools www

MAINTAINERCLEANFILES = aclocal.m4 configure Makefile.in config.status \
  config.log config/mkinstalldirs depcomp config/install-sh config/missing \
  config/config.guess config/config.sub po/Makefile.am

EXTRA_DIST = INSTALL INSTALL.es doc/CodingStyle

natural=doc/naturaldocs/NaturalDocs
htmldir=doc/api
confdir=doc/naturaldocs/config

api:
	$(natural) -i src/EBox -o HTML $(htmldir) -p $(confdir)

api-clean:
	rm -rf $(htmldir)/*

.PHONY: api api-clean
