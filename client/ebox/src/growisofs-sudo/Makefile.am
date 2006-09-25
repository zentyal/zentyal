## Process this file with automake to produce Makefile.in

sudo_wrapper = growisofs-sudo


EXTRA_DIST = $(sudo_wrapper)

MAINTAINERCLEANFILES = Makefile.in


install:
	install -m 750 ${sudo_wrapper} /usr/bin

uninstall:
	rm -f /usr/bin/${sudo_wrapper}