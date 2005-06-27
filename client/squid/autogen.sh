#!/bin/sh

if [ -f Makefile ]
then
	make maintainer-clean
fi
po-am.generator > po/Makefile.am
mkdir -p config
aclocal -I m4
autoconf
automake --add-missing

./configure $*
