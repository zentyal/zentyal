## Process this file with automake to produce Makefile.in

schemadir   = @GCONF_SCHEMA_FILE_DIR@
schema_DATA = network.schemas 

if GCONF_SCHEMAS_INSTALL
install-data-local:
	GCONF_CONFIG_SOURCE=$(GCONF_SCHEMA_CONFIG_SOURCE) $(GCONFTOOL) --makefile-install-rule $(srcdir)/$(schema_DATA)

uninstall-local:
	GCONF_CONFIG_SOURCE=$(GCONF_SCHEMA_CONFIG_SOURCE) $(GCONFTOOL) --makefile-uninstall-rule $(srcdir)/$(schema_DATA)
else
install-data-local:

endif

EXTRA_DIST = $(schema_DATA)

MAINTAINERCLEANFILES = Makefile.in
