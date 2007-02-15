test_scripts =  select.t file.t text.t checkbox.t hidden.t password.t  submit.t
test_packages =  TestHelper.pm 

EXTRA_DIST = $(test_scripts) $(test_packages)

MAINTAINERCLEANFILES = Makefile.in

check:
	prove $(test_scripts)