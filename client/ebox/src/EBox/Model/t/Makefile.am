test_scripts = autoload.t CompositeProvider.t  \
t ModelProvider.t \
	Row.t DataTable.t DataForm.t Composite.t

root_test_scripts = CompositeManager.t  ModelManager.

EXTRA_DIST = $(test_scripts) ${root_test_scripts}

MAINTAINERCLEANFILES = Makefile.in

check:
	prove ${test_scripts}
