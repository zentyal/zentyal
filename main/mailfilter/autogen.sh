#!/bin/sh

if [ -f Makefile ]
then
	make maintainer-clean
fi

mkdir -p config
aclocal -I m4
autoconf
automake --add-missing
