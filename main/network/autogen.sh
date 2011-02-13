#!/bin/sh

if [ -f Makefile ] ; then
	make maintainer-clean
fi

mkdir -p config
aclocal -I m4 || exit 1
autoconf || exit 1
automake --add-missing || exit 1
